part of 'editor_main_panel.dart';

class _MarkdownPanel extends StatefulWidget {
  const _MarkdownPanel({
    required this.state,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.onBodyChanged,
    required this.onMarkdownAction,
    required this.onInsertCodeBlockLanguage,
    required this.onInsertImage,
    required this.onOpenTableEditor,
    required this.onEditModeChanged,
  });

  final ContentEditorState state;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<MarkdownEditAction> onMarkdownAction;
  final ValueChanged<String> onInsertCodeBlockLanguage;
  final VoidCallback onInsertImage;
  final VoidCallback onOpenTableEditor;
  final ValueChanged<EditorEditMode> onEditModeChanged;

  @override
  State<_MarkdownPanel> createState() => _MarkdownPanelState();
}

class _MarkdownPanelState extends State<_MarkdownPanel> {
  final _sourceScrollController = ScrollController();
  final _previewScrollController = ScrollController();
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();
    _sourceScrollController.addListener(_handleSourceScroll);
    _previewScrollController.addListener(_handlePreviewScroll);
  }

  @override
  void didUpdateWidget(covariant _MarkdownPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.editMode != widget.state.editMode ||
        oldWidget.state.bodyMarkdown != widget.state.bodyMarkdown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _clampScrollOffset(_sourceScrollController);
        _clampScrollOffset(_previewScrollController);
        if (widget.state.editMode == EditorEditMode.split) {
          _handleSourceScroll();
        }
      });
    }
  }

  @override
  void dispose() {
    _sourceScrollController.removeListener(_handleSourceScroll);
    _previewScrollController.removeListener(_handlePreviewScroll);
    _sourceScrollController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  void _handleSourceScroll() {
    if (!_sourceScrollController.hasClients) return;
    _syncScrollMetrics(
      sourceMetrics: _sourceScrollController.position,
      target: _previewScrollController,
    );
  }

  void _handlePreviewScroll() {
    if (!_previewScrollController.hasClients) return;
    _syncScrollMetrics(
      sourceMetrics: _previewScrollController.position,
      target: _sourceScrollController,
    );
  }

  void _syncScrollMetrics({
    required ScrollMetrics sourceMetrics,
    required ScrollController target,
  }) {
    if (widget.state.editMode != EditorEditMode.split ||
        _isSyncingScroll ||
        !target.hasClients) {
      return;
    }

    final targetPosition = target.position;
    if (!targetPosition.hasContentDimensions) {
      return;
    }

    final sourceMax = sourceMetrics.maxScrollExtent;
    final targetMax = targetPosition.maxScrollExtent;
    final ratio = sourceMax <= 0
        ? 0.0
        : (sourceMetrics.pixels / sourceMax).clamp(0.0, 1.0).toDouble();
    final nextOffset = targetMax <= 0 ? 0.0 : targetMax * ratio;
    final clampedOffset = nextOffset
        .clamp(targetPosition.minScrollExtent, targetPosition.maxScrollExtent)
        .toDouble();

    if ((targetPosition.pixels - clampedOffset).abs() < 0.5) return;

    _isSyncingScroll = true;
    try {
      target.jumpTo(clampedOffset);
    } finally {
      _isSyncingScroll = false;
    }
  }

  void _clampScrollOffset(ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    final clampedOffset = position.pixels
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - clampedOffset).abs() < 0.5) return;
    controller.jumpTo(clampedOffset);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width < kTabletBreakpoint;
    final panelHeight = (viewport.height * 0.56)
        .clamp(compact ? 420.0 : 480.0, compact ? 600.0 : 660.0)
        .toDouble();
    final characterCount = widget.state.bodyMarkdown.trim().runes.length;
    return RepaintBoundary(
      key: const ValueKey('content-editor-markdown-panel'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 520),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MarkdownToolbar(
                        onAction: widget.onMarkdownAction,
                        editMode: widget.state.editMode,
                        onSetEditMode: widget.onEditModeChanged,
                        onInsertImage: widget.onInsertImage,
                        onInsertCodeBlockLanguage:
                            widget.onInsertCodeBlockLanguage,
                        onOpenTableEditor: widget.onOpenTableEditor,
                      ),
                    ),
                    if (constraints.maxWidth >= kTabletBreakpoint) ...[
                      const SizedBox(width: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.only(top: 11, right: 6),
                        child: _CharacterCount(value: characterCount),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            SizedBox(
              height: panelHeight,
              child: switch (widget.state.editMode) {
                EditorEditMode.source => _buildSourcePane(scheme),
                EditorEditMode.split => LayoutBuilder(
                  builder: (context, constraints) {
                    final source = _buildSourcePane(scheme);
                    final preview = _buildPreviewPane(scheme);
                    if (constraints.maxWidth >= kTabletBreakpoint) {
                      return Row(
                        children: [
                          Expanded(flex: 11, child: source),
                          VerticalDivider(
                            width: 1,
                            color: scheme.outlineVariant,
                          ),
                          Expanded(flex: 9, child: preview),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(flex: 11, child: source),
                        Divider(height: 1, color: scheme.outlineVariant),
                        Expanded(flex: 9, child: preview),
                      ],
                    );
                  },
                ),
                EditorEditMode.preview => _buildPreviewPane(scheme),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcePane(ColorScheme scheme) {
    return ColoredBox(
      key: const ValueKey('content-editor-source-pane'),
      color: scheme.surfaceContainerLow.withValues(alpha: 0.46),
      child: _SourceEditor(
        controller: widget.bodyController,
        focusNode: widget.bodyFocusNode,
        scrollController: _sourceScrollController,
        onScrollMetrics: (metrics) => _syncScrollMetrics(
          sourceMetrics: metrics,
          target: _previewScrollController,
        ),
        onChanged: widget.onBodyChanged,
      ),
    );
  }

  Widget _buildPreviewPane(ColorScheme scheme) {
    return ColoredBox(
      key: const ValueKey('content-editor-preview-pane'),
      color: scheme.surface,
      child: _MarkdownPreview(
        data: widget.state.bodyMarkdown,
        scrollController: _previewScrollController,
        onScrollMetrics: (metrics) => _syncScrollMetrics(
          sourceMetrics: metrics,
          target: _sourceScrollController,
        ),
      ),
    );
  }
}
