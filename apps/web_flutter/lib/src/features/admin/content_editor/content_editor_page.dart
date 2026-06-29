import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'content_editor_controller.dart';
import 'content_editor_draft.dart';
import 'content_editor_state.dart';
import 'widgets/cover_picker_dialog.dart';
import 'widgets/editor_main_panel.dart';
import 'widgets/media_section.dart';
import 'widgets/publish_settings_panel.dart';

part 'content_editor_scaffold.dart';

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
      firstDate: DateTime(kDateRangeStartYear),
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
