import '../../models.dart';
import '../api_client_base.dart';

/// 管理后台 AdminAiApi 接口。
mixin AdminAiApi on ApiClientBase {
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
    return decodeObject(data, AdminAiChatDetail.fromJson);
  }

  /// 删除管理后台 AI 聊天会话
  Future<void> deleteAdminAiChat({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/ai/chats/$id', accessToken: accessToken);
  }
}
