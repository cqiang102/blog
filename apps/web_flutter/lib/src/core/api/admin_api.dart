// 管理后台 API
// 包含仪表盘、标签、友链、评论、点赞、浏览记录、用户、内容、媒体、AI、知识库、审计日志等

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models.dart';
import 'api_client_base.dart';

/// 管理后台 API Mixin
mixin AdminApi on ApiClientBase {
  /// 获取管理后台仪表盘数据
  Future<AdminDashboard> fetchAdminDashboard(String accessToken) async {
    final data = await get('/admin/dashboard', accessToken: accessToken);
    return AdminDashboard.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取管理后台标签列表
  Future<List<TagItem>> fetchAdminTags(String accessToken) async {
    final data = await get('/admin/tags', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => TagItem.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 创建管理后台标签
  Future<TagItem> createAdminTag({
    required String accessToken,
    required TagDraft draft,
  }) async {
    final data = await post(
      '/admin/tags',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return TagItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台标签
  Future<TagItem> updateAdminTag({
    required String accessToken,
    required String id,
    required TagDraft draft,
  }) async {
    final data = await put(
      '/admin/tags/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return TagItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台标签
  Future<void> deleteAdminTag({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/tags/$id', accessToken: accessToken);
  }

  /// 获取管理后台友情链接列表
  Future<List<FriendLink>> fetchAdminFriends(String accessToken) async {
    final data = await get('/admin/friends', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => FriendLink.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 创建管理后台友情链接
  Future<FriendLink> createAdminFriend({
    required String accessToken,
    required FriendDraft draft,
  }) async {
    final data = await post(
      '/admin/friends',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return FriendLink.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台友情链接
  Future<FriendLink> updateAdminFriend({
    required String accessToken,
    required String id,
    required FriendDraft draft,
  }) async {
    final data = await put(
      '/admin/friends/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return FriendLink.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台友情链接
  Future<void> deleteAdminFriend({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/friends/$id', accessToken: accessToken);
  }

  /// 获取管理后台评论列表
  Future<PageResult<AdminCommentItem>> fetchAdminComments({
    required String accessToken,
    required AdminCommentQuery query,
  }) async {
    final data = await get(
      '/admin/comments',
      accessToken: accessToken,
      queryParameters: {
        if (query.status != null) 'status': query.status!.apiValue,
        if (query.contentId.trim().isNotEmpty)
          'contentId': query.contentId.trim(),
        if (query.userId.trim().isNotEmpty) 'userId': query.userId.trim(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminCommentItem.fromJson);
  }

  /// 更新管理后台评论状态
  Future<AdminCommentItem> updateAdminCommentStatus({
    required String accessToken,
    required String id,
    required AdminCommentStatus status,
  }) async {
    final data = await put(
      '/admin/comments/$id/status',
      accessToken: accessToken,
      body: {'status': status.apiValue},
    );
    return AdminCommentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台评论
  Future<void> deleteAdminComment({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/comments/$id', accessToken: accessToken);
  }

  /// 获取管理后台点赞列表
  Future<PageResult<AdminLikeItem>> fetchAdminLikes({
    required String accessToken,
    required AdminRecordQuery query,
  }) async {
    final data = await get(
      '/admin/likes',
      accessToken: accessToken,
      queryParameters: {
        if (query.contentId.trim().isNotEmpty)
          'contentId': query.contentId.trim(),
        if (query.userId.trim().isNotEmpty) 'userId': query.userId.trim(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminLikeItem.fromJson);
  }

  /// 删除管理后台点赞
  Future<void> deleteAdminLike({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/likes/$id', accessToken: accessToken);
  }

  /// 获取管理后台浏览记录列表
  Future<PageResult<AdminViewRecordItem>> fetchAdminViews({
    required String accessToken,
    required AdminRecordQuery query,
  }) async {
    final data = await get(
      '/admin/views',
      accessToken: accessToken,
      queryParameters: {
        if (query.contentId.trim().isNotEmpty)
          'contentId': query.contentId.trim(),
        if (query.userId.trim().isNotEmpty) 'userId': query.userId.trim(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminViewRecordItem.fromJson);
  }

  /// 删除管理后台浏览记录
  Future<void> deleteAdminView({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/views/$id', accessToken: accessToken);
  }

  /// 获取管理后台用户列表
  Future<PageResult<AdminUserItem>> fetchAdminUsers({
    required String accessToken,
    required AdminUserQuery query,
  }) async {
    final data = await get(
      '/admin/users',
      accessToken: accessToken,
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.role != null) 'role': query.role!.apiValue,
        if (query.status != null) 'status': query.status!.apiValue,
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminUserItem.fromJson);
  }

  /// 更新管理后台用户
  Future<AdminUserItem> updateAdminUser({
    required String accessToken,
    required String id,
    required AdminUserDraft draft,
  }) async {
    final data = await put(
      '/admin/users/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminUserItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台用户
  Future<void> deleteAdminUser({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/users/$id', accessToken: accessToken);
  }

  /// 获取管理后台 AI 聊天会话列表
  Future<PageResult<AdminAiChatSessionItem>> fetchAdminAiChats({
    required String accessToken,
    required AdminAiChatQuery query,
  }) async {
    final data = await get(
      '/admin/ai/chats',
      accessToken: accessToken,
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.userId.trim().isNotEmpty) 'userId': query.userId.trim(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminAiChatSessionItem.fromJson);
  }

  /// 获取管理后台 AI 聊天详情
  Future<AdminAiChatDetail> fetchAdminAiChatDetail({
    required String accessToken,
    required String id,
  }) async {
    final data = await get('/admin/ai/chats/$id', accessToken: accessToken);
    return AdminAiChatDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台 AI 聊天会话
  Future<void> deleteAdminAiChat({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/ai/chats/$id', accessToken: accessToken);
  }

  /// 获取管理后台知识库文档列表
  Future<PageResult<AdminKnowledgeDocItem>> fetchAdminKnowledgeDocs({
    required String accessToken,
    required AdminKnowledgeDocQuery query,
  }) async {
    final data = await get(
      '/admin/knowledge/docs',
      accessToken: accessToken,
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.enabled != null) 'enabled': query.enabled.toString(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminKnowledgeDocItem.fromJson);
  }

  /// 创建管理后台知识库文档
  Future<AdminKnowledgeDocItem> createAdminKnowledgeDoc({
    required String accessToken,
    required AdminKnowledgeDocDraft draft,
  }) async {
    final data = await post(
      '/admin/knowledge/docs',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminKnowledgeDocItem.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  /// 更新管理后台知识库文档
  Future<AdminKnowledgeDocItem> updateAdminKnowledgeDoc({
    required String accessToken,
    required String id,
    required AdminKnowledgeDocDraft draft,
  }) async {
    final data = await put(
      '/admin/knowledge/docs/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminKnowledgeDocItem.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  /// 删除管理后台知识库文档
  Future<void> deleteAdminKnowledgeDoc({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/knowledge/docs/$id', accessToken: accessToken);
  }

  /// 获取管理后台内容列表
  Future<PageResult<AdminContentItem>> fetchAdminContents({
    required String accessToken,
    int page = 0,
    int size = 50,
  }) async {
    final data = await get(
      '/admin/contents',
      accessToken: accessToken,
      queryParameters: {'page': page.toString(), 'size': size.toString()},
    );
    return pageResult(data, AdminContentItem.fromJson);
  }

  /// 创建管理后台内容
  Future<AdminContentItem> createAdminContent({
    required String accessToken,
    required AdminContentDraft draft,
  }) async {
    final data = await post(
      '/admin/contents',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminContentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台内容
  Future<AdminContentItem> updateAdminContent({
    required String accessToken,
    required String id,
    required AdminContentDraft draft,
  }) async {
    final data = await put(
      '/admin/contents/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminContentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 归档管理后台内容
  Future<void> archiveAdminContent({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/contents/$id', accessToken: accessToken);
  }

  /// 获取管理后台媒体列表
  Future<PageResult<AdminMediaItem>> fetchAdminMedia({
    required String accessToken,
    String? contentId,
    int page = 0,
    int size = 80,
  }) async {
    final data = await get(
      '/admin/media-assets',
      accessToken: accessToken,
      queryParameters: {
        if (contentId != null && contentId.isNotEmpty) 'contentId': contentId,
        'page': page.toString(),
        'size': size.toString(),
      },
    );
    return pageResult(data, AdminMediaItem.fromJson);
  }

  /// 创建管理后台媒体
  Future<AdminMediaItem> createAdminMedia({
    required String accessToken,
    required AdminMediaDraft draft,
  }) async {
    final data = await post(
      '/admin/media-assets',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 上传管理后台媒体文件
  Future<AdminMediaItem> uploadAdminMedia({
    required String accessToken,
    required Uint8List bytes,
    required String filename,
    required MediaAssetType type,
    String contentId = '',
  }) async {
    final formData = FormData.fromMap({
      if (contentId.isNotEmpty) 'contentId': contentId,
      'type': type.apiValue,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final data = await send(
      'POST',
      '/admin/media-assets/upload',
      accessToken: accessToken,
      formData: formData,
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台媒体
  Future<AdminMediaItem> updateAdminMedia({
    required String accessToken,
    required String id,
    required AdminMediaDraft draft,
  }) async {
    final data = await put(
      '/admin/media-assets/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台媒体
  Future<void> deleteAdminMedia({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/media-assets/$id', accessToken: accessToken);
  }

  /// 设置内容封面
  Future<AdminContentItem> setAdminContentCover({
    required String accessToken,
    required String contentId,
    required String mediaId,
  }) async {
    final data = await put(
      '/admin/contents/$contentId/cover/$mediaId',
      accessToken: accessToken,
      body: const {},
    );
    return AdminContentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取管理后台审计日志
  Future<PageResult<AuditLogItem>> fetchAdminAuditLogs({
    required String accessToken,
    required AuditLogQuery query,
  }) async {
    final data = await get(
      '/admin/logs',
      accessToken: accessToken,
      queryParameters: {
        if (query.action != null && query.action!.isNotEmpty)
          'action': query.action,
        if (query.resourceType != null && query.resourceType!.isNotEmpty)
          'resourceType': query.resourceType,
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AuditLogItem.fromJson);
  }
}
