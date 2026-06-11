import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/media_url.dart';
import '../../../core/models.dart';
import '../../../core/theme.dart';
import '../admin_widgets.dart';
import 'content_editor.dart';

/// 内容编辑器对话框
/// 支持新增和编辑内容，包含完整的编辑功能
/// 支持三种编辑模式：源码、分屏、预览
/// 兼容 Web、iOS、Android 平台
class ContentEditorDialog extends ConsumerStatefulWidget {
  const ContentEditorDialog({
    super.key,
    required this.content,
    required this.tags,
  });

  final AdminContentItem? content;
  final List<TagItem> tags;

  @override
  ConsumerState<ContentEditorDialog> createState() =>
      _ContentEditorDialogState();
}

class _ContentEditorDialogState extends ConsumerState<ContentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyFocusNode = FocusNode();

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  /// 初始化控制器
  void _initControllers() {
    final content = widget.content;
    if (content != null) {
      _titleController.text = content.title;
      _slugController.text = content.slug;
      _summaryController.text = content.summary;
      _bodyController.text = content.bodyMarkdown;
    }
  }

  /// 加载初始数据（草稿或现有内容）
  Future<void> _loadInitialData() async {
    final controller = _getController();

    if (widget.content != null) {
      controller.initFromContent(widget.content);
    } else {
      await controller.loadDraft();
      // 同步草稿数据到 UI 控制器
      if (mounted) {
        final state = ref.read(
          contentEditorControllerProvider(widget.content?.id),
        );
        _titleController.text = state.title;
        _slugController.text = state.slug;
        _summaryController.text = state.summary;
        _bodyController.text = state.bodyMarkdown;
      }
    }
  }

  /// 获取控制器
  ContentEditorController _getController() {
    return ref.read(
      contentEditorControllerProvider(widget.content?.id).notifier,
    );
  }

  /// 获取当前状态
  ContentEditorState _getState() {
    return ref.watch(contentEditorControllerProvider(widget.content?.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = _getState();

    return AdminEditorDialog(
      title: widget.content == null ? '新增内容' : '编辑内容',
      subtitle: state.hasUnsavedChanges ? '有尚未保存的更改' : '左侧设置发布信息，右侧专注编辑正文',
      maxWidth: kEditorDialogSplitMaxWidth,
      scrollable: false,
      onClose: () => _onCancel(context, state),
      actions: _buildActions(context, state),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder:
              (context, constraints) => _buildResponsiveEditor(
                context,
                state,
                wide: constraints.maxWidth >= kTabletBreakpoint,
              ),
        ),
      ),
    );
  }

  /// 构建工具栏
  Widget _buildToolbar(BuildContext context, ContentEditorState state) {
    return MarkdownToolbar(
      onInsert: _insertMarkdown,
      editMode: state.editMode,
      onSetEditMode: (mode) => _getController().setEditMode(mode),
      onInsertImage: _showImagePicker,
      mediaUrls: state.mediaUrls,
    );
  }

  /// 构建操作按钮
  List<Widget> _buildActions(BuildContext context, ContentEditorState state) {
    return [
      TextButton(
        onPressed: state.isSubmitting ? null : () => _onCancel(context, state),
        child: const Text('取消'),
      ),
      OutlinedButton(
        onPressed: state.isSubmitting ? null : _saveDraft,
        child: const Text('保存草稿'),
      ),
      FilledButton(
        onPressed: state.isSubmitting ? null : _submit,
        child:
            state.isSubmitting
                ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text('提交发布'),
      ),
    ];
  }

  Widget _buildResponsiveEditor(
    BuildContext context,
    ContentEditorState state, {
    required bool wide,
  }) {
    if (!wide) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminFormSection(
              title: '发布信息',
              subtitle: '设置标题、类型、状态和摘要',
              child: _buildBasicFields(context, state),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildEditorPane(context, state, fillAvailable: false),
            if (widget.tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AdminFormSection(
                title: '内容标签',
                child: _buildTagSelector(context, state, showTitle: false),
              ),
            ],
            if (state.isMediaType) ...[
              const SizedBox(height: AppSpacing.md),
              AdminFormSection(
                title: '媒体资源',
                child: _buildMediaSection(context, state),
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminFormSection(
                  title: '发布信息',
                  subtitle: '设置标题、类型、状态和摘要',
                  child: _buildBasicFields(context, state),
                ),
                if (widget.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  AdminFormSection(
                    title: '内容标签',
                    child: _buildTagSelector(context, state, showTitle: false),
                  ),
                ],
                if (state.isMediaType) ...[
                  const SizedBox(height: AppSpacing.md),
                  AdminFormSection(
                    title: '媒体资源',
                    child: _buildMediaSection(context, state),
                  ),
                ],
              ],
            ),
          ),
        ),
        VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: _buildEditorPane(context, state, fillAvailable: true),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorPane(
    BuildContext context,
    ContentEditorState state, {
    required bool fillAvailable,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final editor = _buildContentSection(
      context,
      state,
      fillAvailable: fillAvailable,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fillAvailable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Text('正文内容', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.isPreviewable ? '支持 Markdown，可随时切换源码、分屏和预览' : '补充内容说明',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (state.isPreviewable) ...[
            const SizedBox(height: AppSpacing.md),
            _buildToolbar(context, state),
          ],
          const SizedBox(height: AppSpacing.md),
          if (fillAvailable) Expanded(child: editor) else editor,
        ],
      ),
    );
  }

  /// 构建基础字段
  Widget _buildBasicFields(BuildContext context, ContentEditorState state) {
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
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator:
              (value) => value == null || value.trim().isEmpty ? '请输入标题' : null,
          onChanged: (value) => _getController().updateTitle(value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _slugController,
          decoration: const InputDecoration(
            labelText: 'Slug',
            hintText: 'URL友好的标识符（可选，留空自动生成）',
          ),
          maxLength: 220,
          onChanged: (value) => _getController().updateSlug(value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<ContentType>(
                key: ValueKey('type_${state.type}'),
                initialValue: state.type,
                decoration: const InputDecoration(labelText: '类型'),
                items:
                    ContentType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      );
                    }).toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  final controller = _getController();
                  final success = await controller.updateType(value);
                  if (!success && mounted) {
                    // ignore: use_build_context_synchronously
                    _showTypeChangeConfirm(context, value);
                  }
                },
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<ContentStatus>(
                key: ValueKey('status_${state.status}'),
                initialValue: state.status,
                decoration: const InputDecoration(labelText: '状态'),
                items:
                    ContentStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _getController().updateStatus(value);
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
          value: state.pinned,
          onChanged: (value) => _getController().updatePinned(value),
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
          onChanged: (value) => _getController().updateSummary(value),
        ),
      ],
    );
  }

  /// 构建内容编辑区域
  Widget _buildContentSection(
    BuildContext context,
    ContentEditorState state, {
    required bool fillAvailable,
  }) {
    if (!state.isPreviewable) {
      return _buildMarkdownEditor(expanded: fillAvailable);
    }

    return _buildEditorByMode(context, state, fillAvailable: fillAvailable);
  }

  /// 根据编辑模式构建编辑器
  Widget _buildEditorByMode(
    BuildContext context,
    ContentEditorState state, {
    required bool fillAvailable,
  }) {
    switch (state.editMode) {
      case EditorEditMode.source:
        return _buildMarkdownEditor(expanded: fillAvailable);
      case EditorEditMode.split:
        return _buildSplitEditor(expanded: fillAvailable);
      case EditorEditMode.preview:
        return _buildPreviewOnly(expanded: fillAvailable);
    }
  }

  /// 源码模式：纯文本编辑
  Widget _buildMarkdownEditor({required bool expanded}) {
    return TextFormField(
      controller: _bodyController,
      focusNode: _bodyFocusNode,
      decoration: const InputDecoration(
        labelText: 'Markdown 内容',
        hintText: '支持Markdown语法，使用工具栏快速插入',
        alignLabelWithHint: true,
      ),
      expands: expanded,
      minLines: expanded ? null : 10,
      maxLines: expanded ? null : 20,
      keyboardType: TextInputType.multiline,
      onChanged: (value) => _getController().updateBody(value),
    );
  }

  /// 分屏模式：左侧编辑，右侧预览
  Widget _buildSplitEditor({required bool expanded}) {
    return Container(
      constraints:
          expanded
              ? const BoxConstraints.expand()
              : const BoxConstraints(minHeight: 340, maxHeight: 520),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 左侧：Markdown 编辑
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    '编辑',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _bodyController,
                    focusNode: _bodyFocusNode,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                      hintText: '输入 Markdown 内容...',
                    ),
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    onChanged: (value) => _getController().updateBody(value),
                  ),
                ),
              ],
            ),
          ),
          // 分隔线
          const VerticalDivider(width: 1),
          // 右侧：实时预览
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    '预览',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: MarkdownBody(
                      data:
                          _bodyController.text.isEmpty
                              ? '*暂无内容*'
                              : _bodyController.text,
                      selectable: true,
                      imageBuilder: _buildMarkdownImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 预览模式：只显示预览
  Widget _buildPreviewOnly({required bool expanded}) {
    return Container(
      constraints:
          expanded
              ? const BoxConstraints.expand()
              : const BoxConstraints(minHeight: 300, maxHeight: 520),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: _bodyController.text.isEmpty ? '*暂无内容*' : _bodyController.text,
          selectable: true,
          imageBuilder: _buildMarkdownImage,
        ),
      ),
    );
  }

  /// 构建 Markdown 中的图片，使用 CachedNetworkImage 缓存
  Widget _buildMarkdownImage(Uri uri, String? title, String? alt) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: resolveMediaUrl(uri.toString()),
        fit: BoxFit.contain,
        placeholder:
            (context, url) => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        errorWidget:
            (context, url, error) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    alt ?? '图片加载失败',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      ),
    );
  }

  /// 构建标签选择器
  Widget _buildTagSelector(
    BuildContext context,
    ContentEditorState state, {
    bool showTitle = true,
  }) {
    return TagSelector(
      tags: widget.tags,
      selectedSlugs: state.tagSlugs.toSet(),
      onToggle: (slug) => _getController().toggleTag(slug),
      showTitle: showTitle,
    );
  }

  /// 构建媒体上传区域
  Widget _buildMediaSection(BuildContext context, ContentEditorState state) {
    return MediaSection(
      type: state.type,
      mediaUrls: state.mediaUrls,
      coverUrl: state.coverUrl,
      isUploading: state.isUploading,
      onUpload: _uploadMedia,
      onRemove: (index) => _getController().removeMedia(index),
      onSetCover: (url) => _getController().setCover(url),
    );
  }

  /// 插入 Markdown 语法
  void _insertMarkdown(String prefix, String suffix) {
    if (!_bodyFocusNode.hasFocus) {
      _bodyFocusNode.requestFocus();
    }

    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || start == end) {
      final cursorPos = start < 0 ? text.length : start;
      final newText =
          '${text.substring(0, cursorPos)}$prefix$suffix${text.substring(cursorPos)}';
      _bodyController.text = newText;
      _bodyController.selection = TextSelection.collapsed(
        offset: cursorPos + prefix.length,
      );
    } else {
      final selectedText = text.substring(start, end);
      final newText =
          '${text.substring(0, start)}$prefix$selectedText$suffix${text.substring(end)}';
      _bodyController.text = newText;
      _bodyController.selection = TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      );
    }

    _getController().updateBody(_bodyController.text);
  }

  /// 显示图片选择器
  Future<void> _showImagePicker() async {
    final state = _getState();

    // 如果有已上传的媒体，显示选择对话框
    if (state.mediaUrls.isNotEmpty) {
      if (!mounted) return;
      final url = await showDialog<String>(
        context: context,
        builder:
            (context) => _ImagePickerDialog(
              mediaUrls: state.mediaUrls,
              onUploadNew: () async {
                Navigator.of(context).pop();
                await _uploadMedia(forceImage: true);
                // 上传后重新显示选择器
                if (mounted) {
                  _showImagePicker();
                }
              },
            ),
      );

      if (url != null && mounted) {
        _insertMarkdown('![图片]($url)', '');
      }
    } else {
      // 没有已上传的媒体，直接上传
      await _uploadMedia(forceImage: true);
      // 上传后自动插入
      if (mounted) {
        final updatedState = _getState();
        if (updatedState.mediaUrls.isNotEmpty) {
          _insertMarkdown('![图片](${updatedState.mediaUrls.last})', '');
        }
      }
    }
  }

  /// 上传媒体文件
  /// [forceImage] 为 true 时强制选择图片（用于 Markdown 插入图片）
  Future<void> _uploadMedia({bool forceImage = false}) async {
    final controller = _getController();
    final error = await controller.uploadMedia(forceImage: forceImage);

    if (error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// 显示类型切换确认对话框
  Future<void> _showTypeChangeConfirm(
    BuildContext context,
    ContentType type,
  ) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('切换类型'),
            content: const Text('切换类型将清除已上传的媒体文件，是否继续？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      _getController().confirmTypeChange(type);
    }
  }

  /// 保存草稿
  Future<void> _saveDraft() async {
    final success = await _getController().saveDraft();
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('草稿已保存')));
    }
  }

  /// 取消操作
  void _onCancel(BuildContext context, ContentEditorState state) {
    if (state.hasUnsavedChanges) {
      showDialog(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
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
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
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
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final state = _getState();
    if (state.isMediaType && state.mediaUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.type == ContentType.image ? '请上传至少一张图片' : '请上传视频',
          ),
        ),
      );
      return;
    }

    final controller = _getController();
    final draft = await controller.submit();
    if (draft != null && mounted) {
      Navigator.of(context).pop(
        ContentEditorSubmitResult(
          draft: draft,
          onSuccess: () => controller.onSubmitSuccess(),
          onFailure: () => controller.onSubmitFailure(),
        ),
      );
    } else if (mounted) {
      controller.onSubmitFailure();
    }
  }
}

/// 图片选择对话框
class _ImagePickerDialog extends StatelessWidget {
  const _ImagePickerDialog({
    required this.mediaUrls,
    required this.onUploadNew,
  });

  final List<String> mediaUrls;
  final VoidCallback onUploadNew;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择图片'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('已上传的图片', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: mediaUrls.length,
                itemBuilder: (context, index) {
                  final url = mediaUrls[index];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: resolveMediaUrl(url),
                        fit: BoxFit.cover,
                        errorWidget:
                            (context, url, error) =>
                                const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: onUploadNew, child: const Text('上传新图片')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
