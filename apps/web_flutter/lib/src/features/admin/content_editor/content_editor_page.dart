import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../core/media_url.dart';
import '../../../core/models.dart';
import '../../../state/state.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';
import 'content_editor_controller.dart';
import 'content_editor_draft.dart';
import 'content_editor_state.dart';
import 'widgets/cover_picker_dialog.dart';
import 'widgets/editor_main_panel.dart';
import 'widgets/media_section.dart';
import 'widgets/publish_settings_panel.dart';

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
  List<TagItem> _tags = const [];
  Object? _loadError;
  bool _loading = true;

  ContentEditorController get _controller =>
      ref.read(contentEditorControllerProvider(widget.contentId).notifier);

  @override
  void initState() {
    super.initState();
    Future.microtask(_initialize);
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

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) throw const ApiException('登录状态已失效，请重新登录');

      final api = ref.read(apiClientProvider);
      final results = await Future.wait<Object?>([
        api.fetchAdminTags(token),
        widget.contentId == null
            ? Future<AdminContentItem?>.value(null)
            : api.fetchAdminContent(accessToken: token, id: widget.contentId!),
      ]);
      if (!mounted) return;

      _tags = results[0] as List<TagItem>;
      _content = results[1] as AdminContentItem?;
      _controller.initialize(_content);

      final snapshot = await _controller.loadDraftSnapshot();
      if (!mounted) return;
      if (snapshot != null) {
        if (snapshot.state.sameContentAs(
          ContentEditorState.fromContent(_content),
        )) {
          await _controller.discardLocalDraft();
        } else {
          await _resolveDraft(snapshot);
        }
      }
      if (!mounted) return;

      _syncTextControllers(
        ref.read(contentEditorControllerProvider(widget.contentId)),
      );
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _resolveDraft(ContentEditorDraftSnapshot snapshot) async {
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('发现本机草稿'),
        content: Text(
          '此设备在 ${_formatDateTime(snapshot.savedAt.toLocal())} '
          '保存过一份尚未提交的内容。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(widget.contentId == null ? '开始空白内容' : '使用线上版本'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复本机草稿'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (restore == true) {
      _controller.restoreDraft(snapshot);
    } else {
      await _controller.discardLocalDraft();
    }
  }

  void _syncTextControllers(ContentEditorState state) {
    _titleController.text = state.title;
    _slugController.text = state.slug;
    _summaryController.text = state.summary;
    _bodyController.text = state.bodyMarkdown;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentEditorControllerProvider(widget.contentId));

    if (_loading) return _buildLoading();
    if (_loadError != null) return _buildError();

    final compact = MediaQuery.sizeOf(context).width < 840;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveCurrentToServer,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _saveCurrentToServer,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            _insertMarkdown('**', '**'),
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () =>
            _insertMarkdown('**', '**'),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            _insertMarkdown('*', '*'),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () =>
            _insertMarkdown('*', '*'),
      },
      child: FocusTraversalGroup(
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _requestLeave(state);
          },
          child: Scaffold(
            appBar: _buildAppBar(state, compact: compact),
            body: AbsorbPointer(
              absorbing: state.isSubmitting,
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) => _buildEditorLayout(
                    state,
                    wide: constraints.maxWidth >= 1080,
                  ),
                ),
              ),
            ),
            bottomNavigationBar: compact ? _buildCompactActions(state) : null,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      appBar: AppBar(title: const Text('内容编辑器')),
      body: const Center(child: CircularProgressIndicator.adaptive()),
    );
  }

  Widget _buildError() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容编辑器'),
        leading: BackButton(onPressed: _leave),
      ),
      body: AdminErrorPane(
        message: _loadError.toString(),
        onRetry: _initialize,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ContentEditorState state, {
    required bool compact,
  }) {
    return AppBar(
      leading: IconButton(
        tooltip: '返回内容管理',
        onPressed: () => _requestLeave(state),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.contentId == null ? '新增内容' : '编辑内容',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _SaveStatusText(state: state, isNew: widget.contentId == null),
        ],
      ),
      actions: compact ? null : _buildActions(state),
    );
  }

  List<Widget> _buildActions(ContentEditorState state) {
    return [
      TextButton.icon(
        onPressed: state.isSubmitting || !state.isPreviewable
            ? null
            : () => _controller.setEditMode(EditorEditMode.preview),
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedView, size: 18),
        label: const Text('预览'),
      ),
      TextButton.icon(
        onPressed:
            state.isSubmitting ||
                state.isUploading ||
                state.isSavingDraft ||
                !state.hasUnsavedChanges
            ? null
            : _saveLocalDraft,
        icon: const Icon(Icons.cloud_download_outlined, size: 18),
        label: const Text('保存到本机'),
      ),
      ..._serverActionButtons(state),
      const SizedBox(width: AppSpacing.sm),
    ];
  }

  Widget _buildCompactActions(ContentEditorState state) {
    return SafeArea(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: '保存到本机',
                onPressed:
                    state.isSubmitting ||
                        state.isUploading ||
                        state.isSavingDraft ||
                        !state.hasUnsavedChanges
                    ? null
                    : _saveLocalDraft,
                icon: const Icon(Icons.cloud_download_outlined),
              ),
              const Spacer(),
              ..._serverActionButtons(state),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _serverActionButtons(ContentEditorState state) {
    final busy = state.isSubmitting || state.isUploading;
    if (widget.contentId == null || state.status == ContentStatus.draft) {
      return [
        OutlinedButton(
          onPressed: busy ? null : () => _submit(ContentStatus.draft),
          child: const Text('保存草稿'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: busy ? null : () => _submit(ContentStatus.published),
          child: _SubmitLabel(busy: state.isSubmitting, label: '发布'),
        ),
      ];
    }
    return [
      FilledButton(
        onPressed: busy ? null : _saveCurrentToServer,
        child: _SubmitLabel(busy: state.isSubmitting, label: '保存更新'),
      ),
    ];
  }

  Widget _buildEditorLayout(ContentEditorState state, {required bool wide}) {
    final mainPanel = EditorMainPanel(
      state: state,
      titleController: _titleController,
      summaryController: _summaryController,
      bodyController: _bodyController,
      bodyFocusNode: _bodyFocusNode,
      onTitleChanged: _controller.updateTitle,
      onSummaryChanged: _controller.updateSummary,
      onBodyChanged: _controller.updateBody,
      onInsertMarkdown: _insertMarkdown,
      onInsertImage: _showImagePicker,
      onEditModeChanged: _controller.setEditMode,
      mediaChild: _buildMediaSection(state),
    );
    final settings = PublishSettingsPanel(
      state: state,
      slugController: _slugController,
      tags: _tags,
      onSlugChanged: _controller.updateSlug,
      onTypeChanged: _changeType,
      onStatusChanged: _controller.updateStatus,
      onPinnedChanged: _controller.updatePinned,
      onPublishedAtPressed: () => _pickPublishedAt(state),
      onPublishedAtCleared: () => _controller.updatePublishedAt(null),
      onTagToggled: _controller.toggleTag,
      onCoverPressed: _pickCover,
    );

    if (!wide) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          mainPanel,
          if (!state.isMediaType) ...[
            const SizedBox(height: AppSpacing.md),
            _buildMediaSection(state),
          ],
          const SizedBox(height: AppSpacing.md),
          settings,
          const SizedBox(height: AppSpacing.xl),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              mainPanel,
              if (!state.isMediaType) ...[
                const SizedBox(height: AppSpacing.md),
                _buildMediaSection(state),
              ],
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        SizedBox(
          width: 360,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [settings],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSection(ContentEditorState state) {
    return MediaSection(
      type: state.type,
      mediaUrls: state.mediaUrls,
      coverUrl: state.coverUrl,
      isUploading: state.isUploading,
      uploadProgress: state.uploadProgress,
      onUpload: () => _uploadMedia(forceImage: state.type != ContentType.video),
      onRemove: _controller.removeMedia,
      onSetCover: _controller.setCover,
      onMove: _controller.moveMedia,
    );
  }

  Future<void> _changeType(ContentType type) async {
    if (_controller.canChangeType(type)) {
      _controller.updateType(type);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('切换内容类型'),
        content: const Text('切换类型会清空当前已上传的媒体，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续切换'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _controller.updateType(type);
  }

  Future<void> _pickPublishedAt(ContentEditorState state) async {
    final initial = state.publishedAt?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    _controller.updatePublishedAt(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _pickCover() async {
    final state = ref.read(contentEditorControllerProvider(widget.contentId));
    final selected = await CoverPickerDialog.show(
      context,
      mediaUrls: state.mediaUrls,
      currentCoverUrl: state.coverUrl,
    );
    if (!mounted || selected == null) return;
    _controller.setCover(selected.isEmpty ? null : selected);
  }

  void _insertMarkdown(String prefix, String suffix) {
    final state = ref.read(contentEditorControllerProvider(widget.contentId));
    if (state.isSubmitting) return;
    _bodyFocusNode.requestFocus();
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;
    final selected = text.substring(start, end);
    final next =
        '${text.substring(0, start)}$prefix$selected$suffix${text.substring(end)}';
    _bodyController.value = TextEditingValue(
      text: next,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + prefix.length)
          : TextSelection(
              baseOffset: start + prefix.length,
              extentOffset: start + prefix.length + selected.length,
            ),
    );
    _controller.updateBody(next);
  }

  Future<void> _showImagePicker() async {
    var state = ref.read(contentEditorControllerProvider(widget.contentId));
    if (state.mediaUrls.isEmpty) {
      await _uploadMedia(forceImage: true);
      if (!mounted) return;
      state = ref.read(contentEditorControllerProvider(widget.contentId));
      if (state.mediaUrls.isNotEmpty) {
        _insertMarkdown('![图片](${state.mediaUrls.last})', '');
      }
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ImagePickerDialog(
        mediaUrls: state.mediaUrls,
        onUpload: () => Navigator.of(dialogContext).pop('__upload__'),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == '__upload__') {
      final previousLength = state.mediaUrls.length;
      await _uploadMedia(forceImage: true);
      if (!mounted) return;
      final next = ref.read(contentEditorControllerProvider(widget.contentId));
      if (next.mediaUrls.length > previousLength) {
        _insertMarkdown('![图片](${next.mediaUrls.last})', '');
      }
      return;
    }
    _insertMarkdown('![图片]($selected)', '');
  }

  Future<void> _uploadMedia({required bool forceImage}) async {
    final state = ref.read(contentEditorControllerProvider(widget.contentId));
    if (state.isSubmitting) return;
    final error = await _controller.uploadMedia(
      forceImage: forceImage,
      allowMultiple: true,
    );
    if (error != null && mounted) showAdminSnack(context, error);
  }

  Future<void> _saveLocalDraft() async {
    final success = await _controller.saveLocalDraft();
    if (!mounted) return;
    showAdminSnack(context, success ? '草稿已保存到本机' : '当前没有需要保存的更改');
  }

  void _saveCurrentToServer() {
    final state = ref.read(contentEditorControllerProvider(widget.contentId));
    _submit(widget.contentId == null ? ContentStatus.draft : state.status);
  }

  Future<void> _submit(ContentStatus status) async {
    final current = ref.read(contentEditorControllerProvider(widget.contentId));
    if (current.isSubmitting) return;
    if (current.isUploading) {
      showAdminSnack(context, '媒体仍在上传，请稍候');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = ref.read(contentEditorControllerProvider(widget.contentId));
    if (state.isMediaType && state.mediaUrls.isEmpty) {
      showAdminSnack(
        context,
        state.type == ContentType.image ? '请上传至少一张图片' : '请上传视频',
      );
      return;
    }

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      showAdminSnack(context, '登录状态已失效');
      return;
    }

    FocusScope.of(context).unfocus();
    _controller.beginSubmit();
    try {
      final api = ref.read(apiClientProvider);
      final draft = _controller.buildDraft(status: status);
      final saved = widget.contentId == null
          ? await api.createAdminContent(accessToken: token, draft: draft)
          : await api.updateAdminContent(
              accessToken: token,
              id: widget.contentId!,
              draft: draft,
            );
      await _controller.submitSucceeded(saved);
      ref.invalidate(adminContentsProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);
      if (!mounted) return;
      showAdminSnack(
        context,
        status == ContentStatus.published ? '内容已发布' : '内容草稿已保存',
      );
      _leave();
    } on ApiException catch (error) {
      _controller.submitFailed();
      if (mounted) showAdminSnack(context, error.message);
    } catch (error) {
      _controller.submitFailed();
      if (mounted) showAdminSnack(context, error.toString());
    }
  }

  Future<void> _requestLeave(ContentEditorState state) async {
    if (state.isSubmitting) {
      showAdminSnack(context, '正在提交，请稍候');
      return;
    }
    if (state.isUploading) {
      showAdminSnack(context, '媒体仍在上传，请稍候');
      return;
    }
    if (!state.hasUnsavedChanges) {
      _leave();
      return;
    }

    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('尚未提交到服务器'),
        content: const Text('这些更改只存在于当前页面。你可以先保存到本机，稍后继续编辑。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('留在页面'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeaveAction.discard),
            child: const Text('不保存离开'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LeaveAction.saveLocal),
            child: const Text('保存到本机并离开'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == _LeaveAction.saveLocal) {
      final success = await _controller.saveLocalDraft();
      if (!mounted) return;
      if (!success) {
        showAdminSnack(context, '本机草稿保存失败，请重试');
        return;
      }
    }
    _leave();
  }

  void _leave() {
    if (!mounted) return;
    context.go('/admin?tab=content');
  }

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

enum _LeaveAction { discard, saveLocal }

class _SaveStatusText extends StatelessWidget {
  const _SaveStatusText({required this.state, required this.isNew});

  final ContentEditorState state;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final text = state.isSavingDraft
        ? '正在保存到本机…'
        : state.hasUnsavedChanges
        ? state.lastLocalSavedAt == null
              ? '尚未提交'
              : '本机草稿已更新，仍未提交'
        : isNew
        ? '尚未编辑'
        : '已与服务器同步';
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SubmitLabel extends StatelessWidget {
  const _SubmitLabel({required this.busy, required this.label});

  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!busy) return Text(label);
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _ImagePickerDialog extends StatelessWidget {
  const _ImagePickerDialog({required this.mediaUrls, required this.onUpload});

  final List<String> mediaUrls;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('插入图片'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: mediaUrls.length,
          itemBuilder: (context, index) {
            final url = mediaUrls[index];
            return Semantics(
              button: true,
              label: '插入图片 ${index + 1}',
              child: InkWell(
                onTap: () => Navigator.of(context).pop(url),
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: resolveMediaUrl(url),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.upload_outlined),
          label: const Text('上传新图片'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
