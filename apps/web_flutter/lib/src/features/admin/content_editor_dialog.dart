// 内容编辑器对话框
// 支持新增和编辑内容，包含标题、Slug、类型、状态、置顶、摘要、正文、标签、媒体上传和Markdown预览
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_providers.dart';
import '../../core/models.dart';

/// 内容编辑器对话框
/// 支持新增和编辑内容，包含完整的编辑功能
/// 兼容 Web、iOS、Android 平台
class ContentEditorDialog extends ConsumerStatefulWidget {
  const ContentEditorDialog({
    super.key,
    required this.content,
    required this.tags,
  });

  final AdminContentItem? content; // 待编辑内容（null 表示新增）
  final List<TagItem> tags; // 可选标签列表

  @override
  ConsumerState<ContentEditorDialog> createState() =>
      ContentEditorDialogState();
}

/// 内容编辑器对话框状态管理
class ContentEditorDialogState extends ConsumerState<ContentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyFocusNode = FocusNode();

  late ContentType _type;
  late ContentStatus _status;
  late bool _pinned;
  late Set<String> _tagSlugs;
  late List<String> _mediaUrls;
  String? _coverUrl;
  bool _uploading = false;
  bool _showPreview = false;
  bool _hasUnsavedChanges = false;
  bool _initialized = false; // 防止重复初始化

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    final draft = content == null
        ? const AdminContentDraft(
            title: '',
            slug: '',
            type: ContentType.article,
            status: ContentStatus.draft,
            summary: '',
            bodyMarkdown: '',
            pinned: false,
            tagSlugs: [],
          )
        : AdminContentDraft.fromItem(content);

    _titleController.text = draft.title;
    _slugController.text = draft.slug;
    _summaryController.text = draft.summary;
    _bodyController.text = draft.bodyMarkdown;
    _type = draft.type;
    _status = draft.status;
    _pinned = draft.pinned;
    _tagSlugs = draft.tagSlugs.toSet();
    _mediaUrls = content?.mediaUrls.toList() ?? [];
    _coverUrl = content?.coverUrl;

    // 监听表单变化
    _titleController.addListener(_onTextChanged);
    _slugController.addListener(_onTextChanged);
    _summaryController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在didChangeDependencies中加载草稿，确保context可用
    if (!_initialized && widget.content == null) {
      _initialized = true;
      _loadDraft();
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _slugController.removeListener(_onTextChanged);
    _summaryController.removeListener(_onTextChanged);
    _bodyController.removeListener(_onTextChanged);
    _titleController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  /// 监听文本变化
  void _onTextChanged() {
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  /// 加载保存的草稿
  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString('content_draft');
      if (draftJson != null && mounted) {
        final draft = jsonDecode(draftJson) as Map<String, dynamic>;
        setState(() {
          _titleController.text = draft['title'] ?? '';
          _slugController.text = draft['slug'] ?? '';
          _summaryController.text = draft['summary'] ?? '';
          _bodyController.text = draft['bodyMarkdown'] ?? '';
          _type = ContentType.fromApi(draft['type']);
          _status = ContentStatus.fromApi(draft['status']);
          _pinned = draft['pinned'] ?? false;
          _tagSlugs = Set<String>.from(draft['tagSlugs'] ?? []);
          _mediaUrls = List<String>.from(draft['mediaUrls'] ?? []);
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      // 忽略加载失败
    }
  }

  /// 保存草稿
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'title': _titleController.text,
        'slug': _slugController.text,
        'summary': _summaryController.text,
        'bodyMarkdown': _bodyController.text,
        'type': _type.apiValue,
        'status': _status.apiValue,
        'pinned': _pinned,
        'tagSlugs': _tagSlugs.toList(),
        'mediaUrls': _mediaUrls,
      };
      await prefs.setString('content_draft', jsonEncode(draft));
      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
      }
    } catch (e) {
      // 忽略保存失败
    }
  }

  /// 清除草稿
  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('content_draft');
    } catch (e) {
      // 忽略清除失败
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用LayoutBuilder获取可用空间
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              _buildTitleBar(context),
              const SizedBox(height: 16),
              // 工具栏
              _buildToolbar(context),
              const SizedBox(height: 12),
              // 主内容区域
              Expanded(
                child: Form(
                  key: _formKey,
                  child: _buildContent(context),
                ),
              ),
              const SizedBox(height: 16),
              // 操作按钮
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildTitleBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.content == null ? '新增内容' : '编辑内容',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        if (_hasUnsavedChanges)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '未保存',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _onCancel(context),
        ),
      ],
    );
  }

  /// 构建工具栏
  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        // Markdown工具栏
        if (_type == ContentType.article || _type == ContentType.text) ...[
          _buildToolbarButton(Icons.format_bold, '粗体', () => _insertMarkdown('**', '**')),
          _buildToolbarButton(Icons.format_italic, '斜体', () => _insertMarkdown('*', '*')),
          _buildToolbarButton(Icons.title, '标题', () => _insertMarkdown('\n## ', '\n')),
          _buildToolbarButton(Icons.link, '链接', () => _insertMarkdown('[', '](url)')),
          _buildToolbarButton(Icons.code, '代码', () => _insertMarkdown('`', '`')),
          _buildToolbarButton(Icons.format_quote, '引用', () => _insertMarkdown('\n> ', '\n')),
          _buildToolbarButton(Icons.format_list_bulleted, '列表', () => _insertMarkdown('\n- ', '\n')),
          const SizedBox(width: 8),
          const VerticalDivider(),
          const SizedBox(width: 8),
        ],
        // 预览切换
        if (_type == ContentType.article || _type == ContentType.text)
          IconButton(
            icon: Icon(_showPreview ? Icons.edit : Icons.preview),
            tooltip: _showPreview ? '编辑' : '预览',
            onPressed: () => setState(() => _showPreview = !_showPreview),
          ),
        const Spacer(),
        // 封面图设置
        if (_mediaUrls.isNotEmpty)
          TextButton.icon(
            onPressed: () => _showCoverPicker(context),
            icon: const Icon(Icons.image),
            label: Text(_coverUrl != null ? '已设封面' : '设为封面'),
          ),
      ],
    );
  }

  /// 构建工具栏按钮
  Widget _buildToolbarButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  /// 构建主内容区域
  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBasicFields(context),
          const SizedBox(height: 16),
          _buildContentSection(context),
          if (widget.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTagSelector(context),
          ],
          if (_type == ContentType.image || _type == ContentType.video) ...[
            const SizedBox(height: 16),
            _buildMediaSection(context),
          ],
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => _onCancel(context),
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存草稿'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('提交'),
        ),
      ],
    );
  }

  /// 插入Markdown语法
  void _insertMarkdown(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || start == end) {
      // 没有选中文本，在光标位置插入
      final cursorPos = start < 0 ? text.length : start;
      final newText = '${text.substring(0, cursorPos)}$prefix$suffix${text.substring(cursorPos)}';
      _bodyController.text = newText;
      _bodyController.selection = TextSelection.collapsed(
        offset: cursorPos + prefix.length,
      );
    } else {
      // 有选中文本，包裹选中内容
      final selectedText = text.substring(start, end);
      final newText = '${text.substring(0, start)}$prefix$selectedText$suffix${text.substring(end)}';
      _bodyController.text = newText;
      _bodyController.selection = TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      );
    }
  }

  /// 构建基础字段
  Widget _buildBasicFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '标题',
            hintText: '请输入内容标题',
          ),
          maxLength: 180,
          validator: (value) =>
              value == null || value.trim().isEmpty ? '请输入标题' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _slugController,
          decoration: const InputDecoration(
            labelText: 'Slug',
            hintText: 'URL友好的标识符（可选，留空自动生成）',
          ),
          maxLength: 220,
        ),
        const SizedBox(height: 12),
        // 使用StatefulBuilder包装Dropdown，确保状态更新
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<ContentType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '类型'),
                items: ContentType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<ContentStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '状态'),
                items: ContentStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('置顶'),
          subtitle: const Text('置顶内容会显示在推荐列表最前面'),
          value: _pinned,
          onChanged: (value) => setState(() => _pinned = value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _summaryController,
          decoration: const InputDecoration(
            labelText: '摘要',
            hintText: '简短描述内容，用于列表展示',
          ),
          maxLines: 3,
          maxLength: 2000,
        ),
      ],
    );
  }

  /// 构建内容编辑区域
  Widget _buildContentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '正文内容',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            if (_type == ContentType.article || _type == ContentType.text)
              Text(
                _showPreview ? '预览模式' : '编辑模式',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showPreview &&
            (_type == ContentType.article || _type == ContentType.text))
          Card(
            child: Container(
              constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: _bodyController.text.isEmpty
                    ? '*暂无内容*'
                    : _bodyController.text,
                selectable: true,
              ),
            ),
          )
        else
          TextFormField(
            controller: _bodyController,
            focusNode: _bodyFocusNode,
            decoration: const InputDecoration(
              labelText: 'Markdown 内容',
              hintText: '支持Markdown语法，使用工具栏快速插入',
              alignLabelWithHint: true,
            ),
            minLines: 8,
            maxLines: 20,
            keyboardType: TextInputType.multiline,
          ),
      ],
    );
  }

  /// 构建标签选择器
  Widget _buildTagSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '标签',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in widget.tags)
              FilterChip(
                label: Text(tag.name),
                selected: _tagSlugs.contains(tag.slug),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _tagSlugs.add(tag.slug);
                  } else {
                    _tagSlugs.remove(tag.slug);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  /// 构建媒体上传区域
  Widget _buildMediaSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _type == ContentType.image ? '图片资源' : '视频资源',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: _uploading ? null : () => _pickAndUploadMedia(context),
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_uploading ? '上传中...' : '上传文件'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_mediaUrls.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    _type == ContentType.image
                        ? Icons.image_outlined
                        : Icons.videocam_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _type == ContentType.image
                        ? '暂无图片，请上传'
                        : '暂无视频，请上传',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // 使用Wrap代替GridView，避免嵌套滚动问题
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_mediaUrls.length, (index) {
              final url = _mediaUrls[index];
              final isCover = url == _coverUrl;
              return SizedBox(
                width: _type == ContentType.image ? 150 : 200,
                height: _type == ContentType.image ? 150 : 112,
                child: _buildMediaCard(context, url, index, isCover),
              );
            }),
          ),
      ],
    );
  }

  /// 构建媒体卡片
  Widget _buildMediaCard(BuildContext context, String url, int index, bool isCover) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 媒体内容
          if (_type == ContentType.image)
            Image.network(
              url,
              fit: BoxFit.cover,
              // Web兼容性：添加错误处理
              errorBuilder: (context, error, stackTrace) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      '加载失败',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Web兼容性：添加加载指示器
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: frame != null
                      ? child
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                );
              },
            )
          else
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.videocam, size: 48),
              ),
            ),
          // 封面标记
          if (isCover)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '封面',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // 操作按钮 - 添加半透明背景
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(128),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isCover)
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.white, size: 20),
                      tooltip: '设为封面',
                      onPressed: () => setState(() => _coverUrl = url),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    tooltip: '删除',
                    onPressed: () => setState(() {
                      _mediaUrls.removeAt(index);
                      if (_coverUrl == url) {
                        _coverUrl = _mediaUrls.isNotEmpty ? _mediaUrls.first : null;
                      }
                    }),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示封面图选择器
  void _showCoverPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择封面图'),
        content: SizedBox(
          width: 400,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_mediaUrls.length, (index) {
              final url = _mediaUrls[index];
              final isCover = url == _coverUrl;
              return GestureDetector(
                onTap: () {
                  setState(() => _coverUrl = url);
                  Navigator.of(dialogContext).pop();
                },
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                        if (isCover)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Icon(Icons.check, color: Colors.white, size: 32),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _coverUrl = null);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('清除封面'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 选择并上传媒体文件
  Future<void> _pickAndUploadMedia(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: _type == ContentType.image ? FileType.image : FileType.video,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      if (!mounted) return;
      setState(() => _uploading = true);

      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) {
        if (mounted) {
          setState(() => _uploading = false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先登录')),
            );
          }
        }
        return;
      }

      final mediaType =
          _type == ContentType.image ? MediaAssetType.image : MediaAssetType.video;

      final media = await ref.read(apiClientProvider).uploadAdminMedia(
            accessToken: token,
            bytes: file.bytes!,
            filename: file.name,
            type: mediaType,
          );

      if (mounted) {
        setState(() {
          _mediaUrls.add(media.publicUrl);
          // 如果是第一个媒体，自动设为封面
          if (_mediaUrls.length == 1) {
            _coverUrl = media.publicUrl;
          }
          _uploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: $e')),
          );
        }
      }
    }
  }

  /// 取消操作
  void _onCancel(BuildContext context) {
    if (_hasUnsavedChanges) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('提示'),
          content: const Text('有未保存的更改，是否保存为草稿？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('不保存'),
            ),
            TextButton(
              onPressed: () async {
                await _saveDraft();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('保存草稿'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 提交表单
  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // 清除草稿
    _clearDraft();

    Navigator.of(context).pop(
      AdminContentDraft(
        title: _titleController.text,
        slug: _slugController.text,
        type: _type,
        status: _status,
        summary: _summaryController.text,
        bodyMarkdown: _bodyController.text,
        pinned: _pinned,
        tagSlugs: _tagSlugs.toList()..sort(),
        mediaUrls: _mediaUrls,
        coverUrl: _coverUrl,
      ),
    );
  }
}
