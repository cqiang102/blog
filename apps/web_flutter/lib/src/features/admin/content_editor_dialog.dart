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
  String? _coverUrl; // 封面图URL
  bool _uploading = false;
  bool _showPreview = false; // 是否显示Markdown预览
  bool _hasUnsavedChanges = false; // 是否有未保存的更改

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

    // 加载保存的草稿
    if (content == null) {
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
    if (!_hasUnsavedChanges) {
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
      setState(() => _hasUnsavedChanges = false);
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
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(widget.content == null ? '新增内容' : '编辑内容'),
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
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 工具栏
              _buildToolbar(),
              const SizedBox(height: 12),
              // 主内容区域
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBasicFields(),
                      const SizedBox(height: 16),
                      _buildContentSection(),
                      if (widget.tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildTagSelector(),
                      ],
                      if (_type == ContentType.image ||
                          _type == ContentType.video) ...[
                        const SizedBox(height: 16),
                        _buildMediaSection(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _onCancel(context),
          child: const Text('取消'),
        ),
        OutlinedButton.icon(
          onPressed: _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存草稿'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('提交'),
        ),
      ],
    );
  }

  /// 构建工具栏
  Widget _buildToolbar() {
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
            onPressed: _showCoverPicker,
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

  /// 插入Markdown语法
  void _insertMarkdown(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0) {
      // 没有选中文本，在末尾插入
      final newText = '$text$prefix$suffix';
      _bodyController.text = newText;
      _bodyController.selection = TextSelection.collapsed(
        offset: newText.length - suffix.length,
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
  Widget _buildBasicFields() {
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<ContentType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '类型'),
                items: [
                  for (final type in ContentType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? ContentType.article),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<ContentStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '状态'),
                items: [
                  for (final status in ContentStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? ContentStatus.draft),
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
  Widget _buildContentSection() {
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
              constraints: const BoxConstraints(minHeight: 200),
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
  Widget _buildTagSelector() {
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
  Widget _buildMediaSection() {
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
              onPressed: _uploading ? null : _pickAndUploadMedia,
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
                  const SizedBox(height: 8),
                  Text(
                    '支持拖拽上传或点击按钮选择文件',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _type == ContentType.image ? 3 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: _type == ContentType.image ? 1 : 16 / 9,
            ),
            itemCount: _mediaUrls.length,
            itemBuilder: (context, index) {
              final url = _mediaUrls[index];
              final isCover = url == _coverUrl;
              return _buildMediaCard(url, index, isCover);
            },
          ),
      ],
    );
  }

  /// 构建媒体卡片
  Widget _buildMediaCard(String url, int index, bool isCover) {
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
              errorBuilder: (context, error, stackTrace) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image)),
              ),
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
          // 操作按钮
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCover)
                  IconButton(
                    icon: const Icon(Icons.image, color: Colors.white),
                    tooltip: '设为封面',
                    onPressed: () => setState(() => _coverUrl = url),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '删除',
                  onPressed: () => setState(() {
                    _mediaUrls.removeAt(index);
                    if (_coverUrl == url) {
                      _coverUrl = _mediaUrls.isNotEmpty ? _mediaUrls.first : null;
                    }
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 显示封面图选择器
  void _showCoverPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择封面图'),
        content: SizedBox(
          width: 400,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _mediaUrls.length,
            itemBuilder: (context, index) {
              final url = _mediaUrls[index];
              final isCover = url == _coverUrl;
              return GestureDetector(
                onTap: () {
                  setState(() => _coverUrl = url);
                  Navigator.of(context).pop();
                },
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
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _coverUrl = null);
              Navigator.of(context).pop();
            },
            child: const Text('清除封面'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 选择并上传媒体文件
  Future<void> _pickAndUploadMedia() async {
    try {
      final result = await FilePicker.pickFiles(
        type: _type == ContentType.image ? FileType.image : FileType.video,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _uploading = true);

      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
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

      setState(() {
        _mediaUrls.add(media.publicUrl);
        // 如果是第一个媒体，自动设为封面
        if (_mediaUrls.length == 1) {
          _coverUrl = media.publicUrl;
        }
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
    }
  }

  /// 取消操作
  void _onCancel(BuildContext context) {
    if (_hasUnsavedChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('有未保存的更改，是否保存为草稿？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).pop();
              },
              child: const Text('不保存'),
            ),
            TextButton(
              onPressed: () async {
                await _saveDraft();
                if (!context.mounted) return;
                Navigator.of(context).pop();
                Navigator.of(this.context).pop();
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
