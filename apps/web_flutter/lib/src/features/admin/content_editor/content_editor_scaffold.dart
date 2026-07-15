part of 'content_editor_page.dart';

extension _ContentEditorScaffold on _ContentEditorPageState {
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
            children: [const Spacer(), ..._serverActionButtons(state)],
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
      onBodyChanged: _handleBodyChanged,
      onMarkdownAction: _applyMarkdownAction,
      onInsertCodeBlockLanguage: _insertCodeBlockLanguage,
      onInsertImage: _showImagePicker,
      onOpenTableEditor: _showTableEditor,
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
      onCollapse: wide ? _toggleSettings : null,
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

    const settingsWidth = 320.0;
    final scheme = Theme.of(context).colorScheme;
    final duration = AppMotion.duration(
      context,
      const Duration(milliseconds: 220),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AnimatedPadding(
                duration: duration,
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(right: _settingsExpanded ? 0 : 48),
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
            ),
            CollapsibleInspector(
              expanded: _settingsExpanded,
              width: settingsWidth,
              duration: duration,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      children: [settings],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!_settingsExpanded)
          Positioned(
            top: AppSpacing.lg,
            right: AppSpacing.sm,
            child: IconButton(
              key: const ValueKey('content-editor-settings-expand'),
              tooltip: '展开发布设置',
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              onPressed: _toggleSettings,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedSidebarLeft01,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
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
}

class _SaveStatusText extends StatelessWidget {
  const _SaveStatusText({required this.state, required this.isNew});

  final ContentEditorState state;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final text = state.isSavingDraft
        ? '正在自动保存…'
        : state.hasUnsavedChanges
        ? state.lastLocalSavedAt == null
              ? '更改将在本机自动保存'
              : '已自动保存到本机 · 尚未提交'
        : isNew
        ? '本机自动保存已开启'
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
