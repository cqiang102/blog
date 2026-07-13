import 'dart:async';

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
import 'markdown_edit_command.dart';
import 'markdown_editing_controller.dart';
import 'markdown_paste_image.dart';
import 'content_editor_state.dart';
import 'widgets/cover_picker_dialog.dart';
import 'widgets/editor_main_panel.dart';
import 'widgets/media_section.dart';
import 'widgets/publish_settings_panel.dart';

part 'content_editor_scaffold.dart';
part 'content_editor_dialogs.dart';
part 'content_editor_actions.dart';

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
  final _bodyController = MarkdownEditingController();
  final _bodyFocusNode = FocusNode();

  AdminContentItem? _content;
  List<TagItem> _tags = const [];
  Object? _loadError;
  bool _loading = true;
  bool _updatingBodyFromCommand = false;
  String _lastBodyText = '';

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
    _lastBodyText = state.bodyMarkdown;
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
            _applyMarkdownEdit(MarkdownEditCommand.bold),
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () =>
            _applyMarkdownEdit(MarkdownEditCommand.bold),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            _applyMarkdownEdit(MarkdownEditCommand.italic),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () =>
            _applyMarkdownEdit(MarkdownEditCommand.italic),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _applyMarkdownEdit(MarkdownEditCommand.link),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            _applyMarkdownEdit(MarkdownEditCommand.link),
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          control: true,
          shift: true,
        ): () =>
            _applyMarkdownEdit(MarkdownEditCommand.codeBlock),
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          meta: true,
          shift: true,
        ): () =>
            _applyMarkdownEdit(MarkdownEditCommand.codeBlock),
        const SingleActivator(
          LogicalKeyboardKey.keyQ,
          control: true,
          shift: true,
        ): () =>
            _applyMarkdownEdit(MarkdownEditCommand.quote),
        const SingleActivator(
          LogicalKeyboardKey.keyQ,
          meta: true,
          shift: true,
        ): () =>
            _applyMarkdownEdit(MarkdownEditCommand.quote),
        const SingleActivator(
          LogicalKeyboardKey.keyU,
          control: true,
          shift: true,
        ): () =>
            _applyMarkdownEdit(MarkdownEditCommand.unorderedList),
        const SingleActivator(
          LogicalKeyboardKey.keyU,
          meta: true,
          shift: true,
        ): () =>
            _applyMarkdownEdit(MarkdownEditCommand.unorderedList),
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          control: true,
          shift: true,
        ): () =>
            _applyMarkdownEdit(MarkdownEditCommand.orderedList),
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          meta: true,
          shift: true,
        ): () =>
            _applyMarkdownEdit(MarkdownEditCommand.orderedList),
      },
      child: MarkdownPasteImageListener(
        focusNode: _bodyFocusNode,
        onImage: (image) => unawaited(_uploadPastedImage(image)),
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
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

enum _LeaveAction { discard, saveLocal }
