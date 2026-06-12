import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../core/media_url.dart';
import '../../../core/models.dart';
import '../../../state/state.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';
import 'content_editor.dart';

/// 内容编辑器独立页面
/// 支持新增和编辑内容，包含完整的编辑功能
/// 支持三种编辑模式：源码、分屏、预览
class ContentEditorPage extends ConsumerStatefulWidget {
  const ContentEditorPage({super.key, this.contentId});

  final String? contentId;

  @override
  ConsumerState<ContentEditorPage> createState() => _ContentEditorPageState();
}

class _ContentEditorPageState extends ConsumerState<ContentEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyFocusNode = FocusNode();

  AdminContentItem? _content;
  List<TagItem> _tags = [];
  bool _loading = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadPageData();
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

  /// 加载页面数据：内容 + 标签
  Future<void> _loadPageData() async {
    try {
      final api = ref.read(apiClientProvider);
      final auth = ref.read(authControllerProvider);
      final token = auth.accessToken;
      if (token == null) {
        setState(() => _loading = false);
        return;
      }

      // 并行加载标签和（编辑模式下的）内容
      final tagsFuture = api.fetchAdminTags(token);
      final contentFuture = widget.contentId != null
          ? api.fetchAdminContent(accessToken: token, id: widget.contentId!)
          : Future<AdminContentItem?>.value(null);

      final results = await Future.wait([tagsFuture, contentFuture]);

      if (!mounted) return;

      _tags = results[0] as List<TagItem>;
      _content = results[1] as AdminContentItem?;

      // 初始化控制器文本
      if (_content != null) {
        _titleController.text = _content!.title;
        _slugController.text = _content!.slug;
        _summaryController.text = _content!.summary;
        _bodyController.text = _content!.bodyMarkdown;
      }

      setState(() => _loading = false);

      // 初始化 Riverpod 控制器状态
      _initEditorState();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载失败: $e')));
    }
  }

  void _initEditorState() {
    if (!_initialized) {
      _initialized = true;
      final controller = _getController();
      if (_content != null) {
        controller.initFromContent(_content);
      } else {
        controller.loadDraft().then((_) {
          if (!mounted) return;
          final state = _getState();
          _titleController.text = state.title;
          _slugController.text = state.slug;
          _summaryController.text = state.summary;
          _bodyController.text = state.bodyMarkdown;
        });
      }
    }
  }

  ContentEditorController _getController() {
    return ref.read(
      contentEditorControllerProvider(widget.contentId).notifier,
    );
  }

  ContentEditorState _getState() {
    return ref.watch(contentEditorControllerProvider(widget.contentId));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final state = _getState();

    return PopScope(
      canPop: !state.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onCancel(state);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_content == null ? '新增内容' : '编辑内容'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onCancel(state),
          ),
        ),
        body: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) => _buildBody(
              context,
              state,
              wide: constraints.maxWidth >= kTabletBreakpoint,
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(context, state),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ContentEditorState state, {
    required bool wide,
  }) {
    if (!wide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminFormSection(
              title: '发布信息',
              subtitle: state.hasUnsavedChanges
                  ? '有尚未保存的更改'
                  : '设置标题、类型、状态和摘要',
              child: _buildBasicFields(context, state),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildEditorPane(context, state, fillAvailable: false),
            if (_tags.isNotEmpty) ...[
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
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.lg,
              right: AppSpacing.md,
              bottom: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminFormSection(
                  title: '发布信息',
                  subtitle: state.hasUnsavedChanges
                      ? '有尚未保存的更改'
                      : '设置标题、类型、状态和摘要',
                  child: _buildBasicFields(context, state),
                ),
                if (_tags.isNotEmpty) ...[
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
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: AppSpacing.lg,
            ),
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
            state.isPreviewable
                ? '支持 Markdown，可随时切换源码、分屏和预览'
                : '补充内容说明',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
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

  Widget _buildToolbar(BuildContext context, ContentEditorState state) {
    return MarkdownToolbar(
      onInsert: _insertMarkdown,
      editMode: state.editMode,
      onSetEditMode: (mode) => _getController().setEditMode(mode),
      onInsertImage: _showImagePicker,
      mediaUrls: state.mediaUrls,
    );
  }

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
          validator: (value) =>
              value == null || value.trim().isEmpty ? '请输入标题' : null,
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
        Text('类型', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SegmentedButton<ContentType>(
          segments: ContentType.values
              .map((type) => ButtonSegment<ContentType>(
                    value: type,
                    label: Text(type.label),
                  ))
              .toList(),
          selected: {state.type},
          onSelectionChanged: (selected) async {
            final value = selected.first;
            final controller = _getController();
            final success = await controller.updateType(value);
            if (!success && mounted) {
              // ignore: use_build_context_synchronously
              _showTypeChangeConfirm(context, value);
            }
          },
        ),
        const SizedBox(height: 12),
        Text('状态', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SegmentedButton<ContentStatus>(
          segments: ContentStatus.values
              .map((status) => ButtonSegment<ContentStatus>(
                    value: status,
                    label: Text(status.label),
                  ))
              .toList(),
          selected: {state.status},
          onSelectionChanged: (selected) {
            _getController().updateStatus(selected.first);
          },
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

  Widget _buildSplitEditor({required bool expanded}) {
    return Container(
      constraints: expanded
          ? const BoxConstraints.expand()
          : const BoxConstraints(minHeight: 340, maxHeight: 520),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
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
          const VerticalDivider(width: 1),
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
                      data: _bodyController.text.isEmpty
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

  Widget _buildPreviewOnly({required bool expanded}) {
    return Container(
      constraints: expanded
          ? const BoxConstraints.expand()
          : const BoxConstraints(minHeight: 300, maxHeight: 520),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: _bodyController.text.isEmpty
              ? '*暂无内容*'
              : _bodyController.text,
          selectable: true,
          imageBuilder: _buildMarkdownImage,
        ),
      ),
    );
  }

  Widget _buildMarkdownImage(Uri uri, String? title, String? alt) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: resolveMediaUrl(uri.toString()),
        fit: BoxFit.contain,
        placeholder: (context, url) => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedImageNotFound01,
                size: 48,
              ),
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

  Widget _buildTagSelector(
    BuildContext context,
    ContentEditorState state, {
    bool showTitle = true,
  }) {
    return TagSelector(
      tags: _tags,
      selectedSlugs: state.tagSlugs.toSet(),
      onToggle: (slug) => _getController().toggleTag(slug),
      showTitle: showTitle,
    );
  }

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

  Widget _buildBottomBar(BuildContext context, ContentEditorState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed:
                  state.isSubmitting ? null : () => _onCancel(state),
              child: const Text('取消'),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: state.isSubmitting ? null : _saveDraft,
              child: const Text('保存草稿'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: state.isSubmitting ? null : _submit,
              child: state.isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('提交发布'),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _showImagePicker() async {
    final state = _getState();

    if (state.mediaUrls.isNotEmpty) {
      if (!mounted) return;
      final url = await showDialog<String>(
        context: context,
        builder: (context) => _ImagePickerDialog(
          mediaUrls: state.mediaUrls,
          onUploadNew: () async {
            Navigator.of(context).pop();
            await _uploadMedia(forceImage: true);
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
      await _uploadMedia(forceImage: true);
      if (mounted) {
        final updatedState = _getState();
        if (updatedState.mediaUrls.isNotEmpty) {
          _insertMarkdown('![图片](${updatedState.mediaUrls.last})', '');
        }
      }
    }
  }

  Future<void> _uploadMedia({bool forceImage = false}) async {
    final controller = _getController();
    final error = await controller.uploadMedia(forceImage: forceImage);

    if (error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _showTypeChangeConfirm(
    BuildContext context,
    ContentType type,
  ) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

  Future<void> _saveDraft() async {
    final success = await _getController().saveDraft();
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('草稿已保存')));
    }
  }

  void _onCancel(ContentEditorState state) {
    if (state.hasUnsavedChanges) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('提示'),
          content: const Text('有未保存的更改，是否保存为草稿？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.pop();
              },
              child: const Text('不保存'),
            ),
            TextButton(
              onPressed: () async {
                await _saveDraft();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  context.pop();
                }
              },
              child: const Text('保存草稿'),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

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
    if (draft == null) {
      if (mounted) controller.onSubmitFailure();
      return;
    }

    // 直接调用 API
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      if (mounted) controller.onSubmitFailure();
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      if (widget.contentId == null) {
        await api.createAdminContent(accessToken: token, draft: draft);
      } else {
        await api.updateAdminContent(
          accessToken: token,
          id: widget.contentId!,
          draft: draft,
        );
      }

      await controller.onSubmitSuccess();
      ref.invalidate(adminContentsProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);

      if (!mounted) return;
      showAdminSnack(
        context,
        widget.contentId == null ? '内容已创建' : '内容已保存',
      );
      context.pop();
    } on ApiException catch (error) {
      controller.onSubmitFailure();
      if (!mounted) return;
      showAdminSnack(context, error.message);
    } catch (error) {
      controller.onSubmitFailure();
      if (!mounted) return;
      showAdminSnack(context, error.toString());
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
                        errorWidget: (context, url, error) =>
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
