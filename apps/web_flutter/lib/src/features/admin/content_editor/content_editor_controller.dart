import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';
import '../../../core/media_url.dart';
import '../../../core/models.dart';
import '../../../state/state.dart';
import 'content_editor_draft.dart';
import 'content_editor_state.dart';

class ContentEditorController extends Notifier<ContentEditorState> {
  ContentEditorController(this.contentId);

  final String? contentId;

  late ContentEditorDraftService _draftService;
  late Future<void> _initFuture;
  Timer? _autoSaveTimer;
  ContentEditorState? _baseline;
  bool _disposed = false;

  static const ContentEditorState _emptyState = ContentEditorState(
    title: '',
    slug: '',
    type: ContentType.markdown,
    status: ContentStatus.draft,
    summary: '',
    bodyMarkdown: '',
    pinned: false,
    tagSlugs: [],
  );

  @override
  ContentEditorState build() {
    _initFuture = _initDraftService();
    ref.onDispose(() {
      _disposed = true;
      _autoSaveTimer?.cancel();
    });
    return _emptyState;
  }

  Future<void> _initDraftService() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    _draftService = ContentEditorDraftService(prefs);
    _autoSaveTimer = Timer.periodic(kAutoSaveInterval, (_) {
      if (!_disposed &&
          state.hasUnsavedChanges &&
          !state.isSubmitting &&
          !state.isUploading) {
        saveLocalDraft();
      }
    });
  }

  Future<void> _ensureInitialized() => _initFuture;

  void initialize(AdminContentItem? content) {
    final initial = ContentEditorState.fromContent(content);
    _baseline = initial;
    state = initial;
  }

  Future<ContentEditorDraftSnapshot?> loadDraftSnapshot() async {
    await _ensureInitialized();
    if (_disposed) return null;
    return _draftService.loadDraft(contentId);
  }

  void restoreDraft(ContentEditorDraftSnapshot snapshot) {
    final restored = snapshot.state;
    state = restored.copyWith(
      hasUnsavedChanges: !_sameAsBaseline(restored),
      lastLocalSavedAt: snapshot.savedAt,
      isSavingDraft: false,
      isSubmitting: false,
      isUploading: false,
      uploadedCount: 0,
      uploadTotal: 0,
    );
  }

  Future<void> discardLocalDraft() async {
    await _ensureInitialized();
    if (_disposed) return;
    await _draftService.clearDraft(contentId);
    if (!_disposed) {
      state = state.copyWith(clearLastLocalSavedAt: true);
    }
  }

  Future<bool> saveLocalDraft() async {
    await _ensureInitialized();
    if (_disposed || !state.hasUnsavedChanges || state.isSavingDraft) {
      return false;
    }

    state = state.copyWith(isSavingDraft: true);
    final savedAt = DateTime.now();
    final success = await _draftService.saveDraft(contentId, state);
    if (_disposed) return success;

    state = state.copyWith(
      isSavingDraft: false,
      lastLocalSavedAt: success ? savedAt : state.lastLocalSavedAt,
    );
    return success;
  }

  void updateTitle(String value) =>
      _updateContent(state.copyWith(title: value));

  void updateSlug(String value) => _updateContent(state.copyWith(slug: value));

  bool canChangeType(ContentType type) {
    if (type == state.type) return true;
    return state.mediaUrls.isEmpty;
  }

  void updateType(ContentType type) {
    _updateContent(
      state.copyWith(type: type, mediaUrls: const [], clearCoverUrl: true),
    );
  }

  void updateStatus(ContentStatus value) =>
      _updateContent(state.copyWith(status: value));

  void updatePinned(bool value) =>
      _updateContent(state.copyWith(pinned: value));

  void updatePublishedAt(DateTime? value) {
    _updateContent(
      state.copyWith(publishedAt: value, clearPublishedAt: value == null),
    );
  }

  void updateSummary(String value) =>
      _updateContent(state.copyWith(summary: value));

  void updateBody(String value) =>
      _updateContent(state.copyWith(bodyMarkdown: value));

  void toggleTag(String slug) {
    final values = [...state.tagSlugs];
    values.contains(slug) ? values.remove(slug) : values.add(slug);
    _updateContent(state.copyWith(tagSlugs: values));
  }

  void setEditMode(EditorEditMode value) {
    state = state.copyWith(editMode: value);
  }

  Future<String?> uploadMedia({
    bool forceImage = false,
    bool allowMultiple = true,
  }) async {
    if (state.isUploading) return null;

    try {
      final fileType = forceImage || state.type == ContentType.image
          ? FileType.image
          : state.type == ContentType.video
          ? FileType.video
          : FileType.image;
      final result = await FilePicker.pickFiles(
        type: fileType,
        withData: true,
        allowMultiple: allowMultiple,
      );
      if (result == null || result.files.isEmpty) return null;

      final files = result.files.where((file) => file.bytes != null).toList();
      if (files.isEmpty) return '无法读取所选文件';

      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) return '请先登录';

      state = state.copyWith(
        isUploading: true,
        uploadedCount: 0,
        uploadTotal: files.length,
      );

      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        final media = await ref
            .read(apiClientProvider)
            .uploadAdminMedia(
              accessToken: token,
              bytes: file.bytes!,
              filename: file.name,
              type: _inferMediaType(file.name),
            );
        if (_disposed) return null;
        final urls = [...state.mediaUrls, mediaFileReference(media.id)];
        _updateContent(
          state.copyWith(
            mediaUrls: urls,
            coverUrl: state.coverUrl ?? urls.first,
            uploadedCount: index + 1,
          ),
        );
      }

      if (_disposed) return null;
      state = state.copyWith(
        isUploading: false,
        uploadedCount: 0,
        uploadTotal: 0,
      );
      return null;
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          isUploading: false,
          uploadedCount: 0,
          uploadTotal: 0,
        );
      }
      return _errorMessage(error);
    }
  }

  Future<({String? url, String? error})> uploadMediaBytes({
    required Uint8List bytes,
    required String filename,
    MediaAssetType type = MediaAssetType.image,
  }) async {
    if (state.isUploading) return (url: null, error: null);

    try {
      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) return (url: null, error: '请先登录');

      state = state.copyWith(
        isUploading: true,
        uploadedCount: 0,
        uploadTotal: 1,
      );

      final media = await ref
          .read(apiClientProvider)
          .uploadAdminMedia(
            accessToken: token,
            bytes: bytes,
            filename: filename,
            type: type,
            contentId: contentId ?? '',
          );
      if (_disposed) return (url: null, error: null);

      final url = mediaFileReference(media.id);
      final urls = [...state.mediaUrls, url];
      _updateContent(
        state.copyWith(
          mediaUrls: urls,
          coverUrl: state.coverUrl ?? urls.first,
          uploadedCount: 1,
        ),
      );
      state = state.copyWith(
        isUploading: false,
        uploadedCount: 0,
        uploadTotal: 0,
      );
      return (url: url, error: null);
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          isUploading: false,
          uploadedCount: 0,
          uploadTotal: 0,
        );
      }
      return (url: null, error: _errorMessage(error));
    }
  }

  void removeMedia(int index) {
    if (index < 0 || index >= state.mediaUrls.length) return;
    final values = [...state.mediaUrls];
    final removed = values.removeAt(index);
    final nextCover = state.coverUrl == removed
        ? (values.isEmpty ? null : values.first)
        : state.coverUrl;
    _updateContent(
      state.copyWith(
        mediaUrls: values,
        coverUrl: nextCover,
        clearCoverUrl: nextCover == null,
      ),
    );
  }

  void moveMedia(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= state.mediaUrls.length ||
        newIndex < 0 ||
        newIndex >= state.mediaUrls.length) {
      return;
    }
    final values = [...state.mediaUrls];
    final item = values.removeAt(oldIndex);
    values.insert(newIndex, item);
    _updateContent(state.copyWith(mediaUrls: values));
  }

  void setCover(String? value) {
    _updateContent(
      state.copyWith(coverUrl: value, clearCoverUrl: value == null),
    );
  }

  AdminContentDraft buildDraft({ContentStatus? status}) {
    return state.copyWith(status: status ?? state.status).toDraft();
  }

  void beginSubmit() => state = state.copyWith(isSubmitting: true);

  void submitFailed() => state = state.copyWith(isSubmitting: false);

  Future<void> submitSucceeded(AdminContentItem content) async {
    await _ensureInitialized();
    await _draftService.clearDraft(contentId);
    if (_disposed) return;
    final saved = ContentEditorState.fromContent(content);
    _baseline = saved;
    state = saved;
  }

  void _updateContent(ContentEditorState next) {
    state = next.copyWith(hasUnsavedChanges: !_sameAsBaseline(next));
  }

  bool _sameAsBaseline(ContentEditorState value) {
    return value.sameContentAs(_baseline ?? _emptyState);
  }

  MediaAssetType _inferMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov')) {
      return MediaAssetType.video;
    }
    return MediaAssetType.image;
  }

  String _errorMessage(Object error) {
    final message = error.toString();
    if (message.contains('timeout')) return '网络连接超时，请检查网络';
    if (message.contains('401') || message.contains('403')) {
      return '登录已过期，请重新登录';
    }
    if (message.contains('413')) return '文件太大，请压缩后上传';
    if (message.contains('415')) return '不支持的文件格式';
    return '上传失败，请重试';
  }
}

final contentEditorControllerProvider = NotifierProvider.autoDispose
    .family<ContentEditorController, ContentEditorState, String?>(
      ContentEditorController.new,
    );
