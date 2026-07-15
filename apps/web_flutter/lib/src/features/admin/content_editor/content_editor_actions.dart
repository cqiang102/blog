part of 'content_editor_page.dart';

extension _ContentEditorActions on _ContentEditorPageState {
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

  void _applyMarkdownAction(MarkdownEditAction action) {
    _applyMarkdownEdit((value) => MarkdownEditCommand.apply(value, action));
  }

  void _applyMarkdownShortcut(MarkdownEditAction action) {
    if (!_bodyFocusNode.hasFocus) return;
    _applyMarkdownAction(action);
  }

  void _applyCodeBlockShortcut() {
    if (!_bodyFocusNode.hasFocus) return;
    _insertCodeBlockLanguage('');
  }

  void _insertMarkdownImage(String url) {
    _applyMarkdownEdit((value) => MarkdownEditCommand.image(value, url: url));
  }

  void _insertCodeBlockLanguage(String language) {
    _applyMarkdownEdit(
      (value) => MarkdownEditCommand.codeBlock(value, language: language),
    );
  }

  void _insertTable(int columns, int rows) {
    _applyMarkdownEdit(
      (value) => MarkdownEditCommand.table(value, columns: columns, rows: rows),
    );
  }

  void _applyMarkdownEdit(TextEditingValue Function(TextEditingValue) command) {
    final state = ref.read(contentEditorControllerProvider(widget.contentId));
    if (state.isSubmitting) return;
    _bodyFocusNode.requestFocus();
    _setBodyEditingValue(command(_bodyController.value));
  }

  void _setBodyEditingValue(TextEditingValue value) {
    _updatingBodyFromCommand = true;
    _bodyController.value = value;
    _updatingBodyFromCommand = false;
    _lastBodyText = value.text;
    _controller.updateBody(value.text);
  }

  void _handleBodyChanged(String value) {
    if (_updatingBodyFromCommand) return;

    final autocompleted = MarkdownEditCommand.autocomplete(
      previousText: _lastBodyText,
      value: _bodyController.value,
    );
    if (autocompleted != null) {
      _setBodyEditingValue(autocompleted);
      return;
    }

    _lastBodyText = value;
    _controller.updateBody(value);
  }

  Future<void> _showImagePicker() async {
    var state = ref.read(contentEditorControllerProvider(widget.contentId));
    if (state.mediaUrls.isEmpty) {
      await _uploadMedia(forceImage: true, allowMultiple: false);
      if (!mounted) return;
      state = ref.read(contentEditorControllerProvider(widget.contentId));
      if (state.mediaUrls.isNotEmpty) {
        _insertMarkdownImage(state.mediaUrls.last);
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
      await _uploadMedia(forceImage: true, allowMultiple: false);
      if (!mounted) return;
      final next = ref.read(contentEditorControllerProvider(widget.contentId));
      if (next.mediaUrls.length > previousLength) {
        _insertMarkdownImage(next.mediaUrls.last);
      }
      return;
    }
    _insertMarkdownImage(selected);
  }

  Future<void> _showTableEditor() async {
    final spec = await showDialog<_TableSpec>(
      context: context,
      builder: (dialogContext) => const _TableEditorDialog(),
    );
    if (!mounted || spec == null) return;
    _insertTable(spec.columns, spec.rows);
  }

  void _queuePastedImage(PastedMarkdownImage image) {
    final state = ref.read(contentEditorControllerProvider(widget.contentId));
    if (state.isSubmitting) {
      showAdminSnack(context, '正在提交，暂时无法粘贴图片');
      return;
    }

    final marker = '<!-- image-upload-${++_pastedImageSequence} -->';
    _applyMarkdownEdit((value) => MarkdownEditCommand.insert(value, marker));

    final previousUpload = _pastedImageQueue;
    _pastedImageQueue = () async {
      try {
        await previousUpload;
      } catch (_) {
        // 前一项失败不应阻断后续粘贴任务。
      }
      if (!mounted) return;
      await _uploadPastedImage(image, marker);
    }();
  }

  Future<void> _uploadPastedImage(
    PastedMarkdownImage image,
    String marker,
  ) async {
    while (true) {
      if (!mounted) return;
      final state = ref.read(contentEditorControllerProvider(widget.contentId));
      if (state.isSubmitting) {
        _replacePastedImageMarker(marker, '');
        showAdminSnack(context, '图片未插入：内容正在提交');
        return;
      }
      if (!state.isUploading) break;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted) return;

    final result = await _controller.uploadMediaBytes(
      bytes: image.bytes,
      filename: image.filename,
      type: MediaAssetType.image,
    );
    if (!mounted) return;
    if (result.error != null) {
      _replacePastedImageMarker(marker, '');
      showAdminSnack(context, result.error!);
      return;
    }
    final url = result.url;
    if (url != null) {
      _replacePastedImageMarker(marker, '![图片]($url)');
      showAdminSnack(context, '图片已上传并插入正文');
      return;
    }
    _replacePastedImageMarker(marker, '');
    showAdminSnack(context, '图片上传未完成，请重试');
  }

  void _replacePastedImageMarker(String marker, String replacement) {
    final current = _bodyController.value;
    final next = MarkdownEditCommand.replaceMarker(
      current,
      marker: marker,
      replacement: replacement,
    );
    if (identical(current, next) || current.text == next.text) return;
    _setBodyEditingValue(next);
  }

  Future<void> _uploadMedia({
    required bool forceImage,
    bool allowMultiple = true,
  }) async {
    final state = ref.read(contentEditorControllerProvider(widget.contentId));
    if (state.isSubmitting) return;
    final error = await _controller.uploadMedia(
      forceImage: forceImage,
      allowMultiple: allowMultiple,
    );
    if (error != null && mounted) showAdminSnack(context, error);
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
}
