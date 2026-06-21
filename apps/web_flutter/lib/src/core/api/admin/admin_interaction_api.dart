import '../../models.dart';
import '../api_client_base.dart';

/// 管理后台 AdminInteractionApi 接口。
mixin AdminInteractionApi on ApiClientBase {
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
}
