import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_providers.dart';
import '../../../core/constants.dart';
import '../../../core/media_url.dart';
import '../../../core/models.dart';
import 'content_editor_draft.dart';
import 'content_editor_state.dart';

/// 内容编辑器控制器
/// 使用 Riverpod Notifier 管理所有编辑器状态和业务逻辑
class ContentEditorController extends Notifier<ContentEditorState> {
  ContentEditorController(this.contentId);

  final String? contentId;

  late ContentEditorDraftService _draftService;
  Timer? _autoSaveTimer;
  Future<void>? _initFuture;

  @override
  ContentEditorState build() {
    _initFuture = _initDraftService();
    return const ContentEditorState(
      title: '',
      slug: '',
      type: ContentType.markdown,
      status: ContentStatus.draft,
      summary: '',
      bodyMarkdown: '',
      pinned: false,
      tagSlugs: [],
    );
  }

  /// 初始化草稿服务
  Future<void> _initDraftService() async {
    final prefs = await SharedPreferences.getInstance();
    _draftService = ContentEditorDraftService(prefs);

    // 启动自动保存定时器
    _autoSaveTimer = Timer.periodic(
      kAutoSaveInterval,
      (_) => saveDraft(),
    );
  }

  /// 确保草稿服务已初始化
  Future<void> _ensureInitialized() async {
    await _initFuture;
  }

  /// 从现有内容初始化状态
  void initFromContent(AdminContentItem? content) {
    if (content != null) {
      state = ContentEditorState.fromContent(content);
    }
  }

  /// 加载草稿
  Future<void> loadDraft() async {
    await _ensureInitialized();
    final draft = await _draftService.loadDraft(contentId);
    if (draft != null) {
      state = draft;
    }
  }

  /// 保存草稿
  Future<bool> saveDraft() async {
    await _ensureInitialized();
    final success = await _draftService.saveDraft(contentId, state);
    if (success) {
      state = state.copyWith(hasUnsavedChanges: false);
    }
    return success;
  }

  /// 清除草稿
  Future<void> clearDraft() async {
    await _ensureInitialized();
    await _draftService.clearDraft(contentId);
  }

  /// 更新标题
  void updateTitle(String title) {
    state = state.copyWith(
      title: title,
      hasUnsavedChanges: true,
    );
  }

  /// 更新 Slug
  void updateSlug(String slug) {
    state = state.copyWith(
      slug: slug,
      hasUnsavedChanges: true,
    );
  }

  /// 更新类型
  Future<bool> updateType(ContentType type) async {
    if (type == state.type) return true;

    // 如果已有媒体文件，需要确认
    if (state.mediaUrls.isNotEmpty && (state.isMediaType || type == ContentType.image || type == ContentType.video)) {
      return false; // 返回 false 表示需要用户确认
    }

    _applyTypeChange(type);
    return true;
  }

  /// 确认类型切换
  void confirmTypeChange(ContentType type) {
    _applyTypeChange(type);
  }

  void _applyTypeChange(ContentType type) {
    state = state.copyWith(
      type: type,
      mediaUrls: [],
      clearCoverUrl: true,
      hasUnsavedChanges: true,
    );
  }

  /// 更新状态
  void updateStatus(ContentStatus status) {
    state = state.copyWith(
      status: status,
      hasUnsavedChanges: true,
    );
  }

  /// 更新置顶
  void updatePinned(bool pinned) {
    state = state.copyWith(
      pinned: pinned,
      hasUnsavedChanges: true,
    );
  }

  /// 更新摘要
  void updateSummary(String summary) {
    state = state.copyWith(
      summary: summary,
      hasUnsavedChanges: true,
    );
  }

  /// 更新正文
  void updateBody(String bodyMarkdown) {
    state = state.copyWith(
      bodyMarkdown: bodyMarkdown,
      hasUnsavedChanges: true,
    );
  }

  /// 切换标签
  void toggleTag(String tagSlug) {
    final tags = List<String>.from(state.tagSlugs);
    if (tags.contains(tagSlug)) {
      tags.remove(tagSlug);
    } else {
      tags.add(tagSlug);
    }
    state = state.copyWith(
      tagSlugs: tags,
      hasUnsavedChanges: true,
    );
  }

  /// 切换编辑模式：源码 -> 分屏 -> 预览 -> 源码
  void cycleEditMode() {
    final modes = EditorEditMode.values;
    final nextIndex = (state.editMode.index + 1) % modes.length;
    state = state.copyWith(editMode: modes[nextIndex]);
  }

  /// 设置编辑模式
  void setEditMode(EditorEditMode mode) {
    if (state.editMode != mode) {
      state = state.copyWith(editMode: mode);
    }
  }

  /// 上传媒体文件
  /// [forceImage] 为 true 时强制选择图片（用于 Markdown 插入图片）
  Future<String?> uploadMedia({bool forceImage = false}) async {
    try {
      state = state.copyWith(isUploading: true);

      // 根据情况决定文件类型过滤
      // 1. 强制图片模式（插入图片按钮）
      // 2. 图片类型内容
      // 3. 视频类型内容
      final FileType fileType;
      if (forceImage || state.type == ContentType.image) {
        fileType = FileType.image;
      } else if (state.type == ContentType.video) {
        fileType = FileType.video;
      } else {
        // article/text 类型，允许选择图片
        fileType = FileType.image;
      }

      final result = await FilePicker.pickFiles(
        type: fileType,
        withData: true,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isUploading: false);
        return null;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        state = state.copyWith(isUploading: false);
        return null;
      }

      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) {
        state = state.copyWith(isUploading: false);
        return '请先登录';
      }

      // 根据文件扩展名判断媒体类型
      final mediaType = _inferMediaType(file.name);

      final media = await ref.read(apiClientProvider).uploadAdminMedia(
            accessToken: token,
            bytes: file.bytes!,
            filename: file.name,
            type: mediaType,
          );

      final mediaReference = mediaFileReference(media.id);
      final mediaUrls = [...state.mediaUrls, mediaReference];
      state = state.copyWith(
        mediaUrls: mediaUrls,
        coverUrl: mediaUrls.length == 1 ? mediaReference : state.coverUrl,
        isUploading: false,
        hasUnsavedChanges: true,
      );

      return null; // 成功
    } catch (e) {
      state = state.copyWith(isUploading: false);
      return _getErrorMessage(e);
    }
  }

  /// 根据文件名推断媒体类型
  MediaAssetType _inferMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov')) {
      return MediaAssetType.video;
    }
    return MediaAssetType.image;
  }

  /// 删除媒体
  void removeMedia(int index) {
    final mediaUrls = List<String>.from(state.mediaUrls);
    final removedUrl = mediaUrls[index];
    mediaUrls.removeAt(index);

    String? newCoverUrl = state.coverUrl;
    if (state.coverUrl == removedUrl) {
      newCoverUrl = mediaUrls.isNotEmpty ? mediaUrls.first : null;
    }

    state = state.copyWith(
      mediaUrls: mediaUrls,
      coverUrl: newCoverUrl,
      clearCoverUrl: newCoverUrl == null,
      hasUnsavedChanges: true,
    );
  }

  /// 设置封面
  void setCover(String? url) {
    state = state.copyWith(
      coverUrl: url,
      clearCoverUrl: url == null,
      hasUnsavedChanges: true,
    );
  }

  /// 提交表单
  Future<AdminContentDraft?> submit() async {
    // 验证
    if (state.title.trim().isEmpty) {
      return null;
    }

    if (state.isMediaType && state.mediaUrls.isEmpty) {
      return null;
    }

    state = state.copyWith(isSubmitting: true);
    return state.toDraft();
  }

  /// 提交成功后调用，清除草稿并重置状态
  Future<void> onSubmitSuccess() async {
    await clearDraft();
    state = state.copyWith(isSubmitting: false);
  }

  /// 提交失败后调用，重置提交状态
  void onSubmitFailure() {
    state = state.copyWith(isSubmitting: false);
  }

  /// 获取错误信息
  String _getErrorMessage(Object error) {
    if (error is Exception) {
      final message = error.toString();
      if (message.contains('timeout')) {
        return '网络连接超时，请检查网络';
      }
      if (message.contains('401') || message.contains('403')) {
        return '登录已过期，请重新登录';
      }
      if (message.contains('413')) {
        return '文件太大，请压缩后上传';
      }
      if (message.contains('415')) {
        return '不支持的文件格式';
      }
    }
    return '操作失败，请重试';
  }

  /// 释放资源
  void dispose() {
    _autoSaveTimer?.cancel();
  }
}

/// 内容编辑器控制器 Provider
final contentEditorControllerProvider = NotifierProvider.autoDispose
    .family<ContentEditorController, ContentEditorState, String?>(
  ContentEditorController.new,
);
