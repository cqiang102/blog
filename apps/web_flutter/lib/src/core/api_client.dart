/// API 客户端单例
/// 基于 Dio 封装所有 HTTP 请求，支持 401 自动刷新令牌、SSE 流式请求
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'models.dart';

/// API 基础 URL，通过编译时常量配置
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api/v1',
);

/// SSE 事件模型
class SseEvent {
  const SseEvent(this.type, this.data);

  final String type; // 事件类型
  final String data; // 事件数据
}

/// API 异常类
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message; // 错误信息
  final int? statusCode; // HTTP 状态码

  @override
  String toString() => message;
}

/// 博客 API 客户端
/// 基于 Dio 封装所有 HTTP 请求，支持 401 自动刷新令牌、SSE 流式请求
class BlogApiClient {
  BlogApiClient({
    required Dio dio,
    this.baseUrl = apiBaseUrl,
  }) : _dio = dio {
    _dio.options.baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    _dio.options.headers = {'Accept': 'application/json'};
  }

  final Dio _dio; // Dio 实例
  final String baseUrl; // API 基础 URL

  /// 401 时的回调，用于刷新令牌
  Future<String?> Function()? onUnauthorized;

  /// 获取 GitHub OAuth 授权 URL
  String get githubAuthorizationUrl {
    final apiUri = Uri.parse(baseUrl);
    return apiUri
        .replace(path: '/oauth2/authorization/github', query: '')
        .toString();
  }

  /// 获取首页推荐内容
  /// 返回值：推荐内容（置顶、最新、最热）
  Future<Recommendations> fetchRecommendations() async {
    final data = await _get('/contents/recommendations');
    return Recommendations.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取内容列表（分页）
  /// [query] 查询参数
  /// 返回值：分页结果
  Future<PageResult<BlogContent>> fetchContents(ContentListQuery query) async {
    final data = await _get(
      '/contents',
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.tag != null) 'tag': query.tag,
        if (query.type != null) 'type': query.type!.apiValue,
        if (query.startDate != null)
          'from': query.startDate!.toUtc().toIso8601String(),
        if (query.endDate != null)
          'to': query.endDate!.toUtc().toIso8601String(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    final json = (data as Map).cast<String, dynamic>();
    return PageResult<BlogContent>(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                BlogContent.fromSummaryJson(item.cast<String, dynamic>()),
          )
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// 获取内容详情
  /// [id] 内容 ID
  /// [accessToken] 可选访问令牌
  /// 返回值：内容详情
  Future<BlogContent> fetchContent(String id, {String? accessToken}) async {
    final data = await _get('/contents/$id', accessToken: accessToken);
    return BlogContent.fromDetailJson((data as Map).cast<String, dynamic>());
  }

  /// 获取随机友情链接
  /// 返回值：友情链接列表
  Future<List<FriendLink>> fetchFriends() async {
    final data = await _get('/friends/random');
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => FriendLink.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 获取所有标签
  /// 返回值：标签列表
  Future<List<TagItem>> fetchTags() async {
    final data = await _get('/contents/tags');
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => TagItem.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 用户登录
  /// [email] 邮箱
  /// [password] 密码
  /// 返回值：认证会话
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 用户注册
  /// [email] 邮箱
  /// [password] 密码
  /// [nickname] 昵称
  /// 返回值：认证会话
  Future<AuthSession> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final data = await _post(
      '/auth/register',
      body: {'email': email, 'password': password, 'nickname': nickname},
    );
    return AuthSession.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 刷新访问令牌
  /// [refreshToken] 刷新令牌
  /// 返回值：新的认证会话
  Future<AuthSession> refreshAccessToken(String refreshToken) async {
    final data = await _post(
      '/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    return AuthSession.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取当前用户信息
  /// [accessToken] 访问令牌
  /// 返回值：用户资料
  Future<UserProfile> me(String accessToken) async {
    final data = await _get('/me', accessToken: accessToken);
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新当前用户信息
  /// [accessToken] 访问令牌
  /// [email] 邮箱
  /// [nickname] 昵称
  /// [avatarUrl] 头像 URL
  /// [bio] 个人简介
  /// [blogUrl] 博客链接
  /// 返回值：更新后的用户资料
  Future<UserProfile> updateMe({
    required String accessToken,
    required String email,
    required String nickname,
    String? avatarUrl,
    String? bio,
    String? blogUrl,
  }) async {
    final data = await _put(
      '/me',
      accessToken: accessToken,
      body: {
        'email': email,
        'nickname': nickname,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'blogUrl': blogUrl,
      },
    );
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取内容评论列表
  /// [contentId] 内容 ID
  /// 返回值：评论分页结果
  Future<PageResult<CommentItem>> fetchComments(String contentId) async {
    final data = await _get('/contents/$contentId/comments');
    return _page(data, CommentItem.fromJson);
  }

  /// 创建评论
  /// [accessToken] 访问令牌
  /// [contentId] 内容 ID
  /// [body] 评论内容
  /// 返回值：创建的评论
  Future<CommentItem> createComment({
    required String accessToken,
    required String contentId,
    required String body,
  }) async {
    final data = await _post(
      '/contents/$contentId/comments',
      accessToken: accessToken,
      body: {'body': body},
    );
    return CommentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除评论
  /// [accessToken] 访问令牌
  /// [commentId] 评论 ID
  Future<void> deleteComment({
    required String accessToken,
    required String commentId,
  }) async {
    await _delete('/comments/$commentId', accessToken: accessToken);
  }

  /// 点赞内容
  /// [accessToken] 访问令牌
  /// [contentId] 内容 ID
  /// 返回值：是否已点赞
  Future<bool> likeContent({
    required String accessToken,
    required String contentId,
  }) async {
    final data = await _post(
      '/contents/$contentId/likes',
      accessToken: accessToken,
    );
    return ((data as Map).cast<String, dynamic>())['liked'] == true;
  }

  /// 取消点赞内容
  /// [accessToken] 访问令牌
  /// [contentId] 内容 ID
  /// 返回值：是否已点赞
  Future<bool> unlikeContent({
    required String accessToken,
    required String contentId,
  }) async {
    final data = await _delete(
      '/contents/$contentId/likes',
      accessToken: accessToken,
    );
    return ((data as Map).cast<String, dynamic>())['liked'] == true;
  }

  /// 记录浏览
  /// [contentId] 内容 ID
  /// [accessToken] 可选访问令牌
  Future<void> recordView({
    required String contentId,
    String? accessToken,
  }) async {
    await _post('/contents/$contentId/views', accessToken: accessToken);
  }

  /// 获取我的活动记录
  /// [accessToken] 访问令牌
  /// [type] 活动类型
  /// [page] 页码
  /// [size] 每页大小
  /// 返回值：活动分页结果
  Future<PageResult<UserActivity>> fetchMyActivity({
    required String accessToken,
    required String type,
    int page = 0,
    int size = 20,
  }) async {
    final data = await _get(
      '/me/$type',
      accessToken: accessToken,
      queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      },
    );
    return _page(data, UserActivity.fromJson);
  }

  /// 删除我的活动记录
  /// [accessToken] 访问令牌
  /// [type] 活动类型
  /// [id] 记录 ID
  Future<void> deleteMyActivity({
    required String accessToken,
    required String type,
    required String id,
  }) async {
    await _delete('/me/$type/$id', accessToken: accessToken);
  }

  /// 获取 AI 配额
  /// [accessToken] 访问令牌
  /// 返回值：AI 配额信息
  Future<AiQuota> fetchAiQuota(String accessToken) async {
    final data = await _get('/ai/quota', accessToken: accessToken);
    return AiQuota.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 修改密码
  /// [accessToken] 访问令牌
  /// [oldPassword] 旧密码
  /// [newPassword] 新密码
  Future<void> changePassword({
    required String accessToken,
    required String oldPassword,
    required String newPassword,
  }) async {
    await _put(
      '/me/password',
      accessToken: accessToken,
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  /// 获取管理后台审计日志
  /// [accessToken] 访问令牌
  /// [query] 查询参数
  /// 返回值：审计日志分页结果
  Future<PageResult<AuditLogItem>> fetchAdminAuditLogs({
    required String accessToken,
    required AuditLogQuery query,
  }) async {
    final data = await _get(
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
    return _page(data, AuditLogItem.fromJson);
  }

  /// 发送 AI 聊天消息
  /// [accessToken] 访问令牌
  /// [message] 消息内容
  /// [sessionId] 可选会话 ID
  /// 返回值：AI 回复
  Future<AiChatReply> sendAiMessage({
    required String accessToken,
    required String message,
    String? sessionId,
  }) async {
    final data = await _post(
      '/ai/chat',
      accessToken: accessToken,
      body: {'sessionId': sessionId, 'message': message},
    );
    return AiChatReply.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 发送 AI 聊天消息（SSE 流式）
  /// 使用 Dio 的 ResponseType.stream 获取原始字节流，手动解析 SSE 协议
  /// [accessToken] 访问令牌
  /// [message] 消息内容
  /// [sessionId] 可选会话 ID
  /// 返回值：SSE 事件流
  Stream<SseEvent> sendAiMessageStream({
    required String accessToken,
    required String message,
    String? sessionId,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      '/ai/chat/stream',
      data: {'sessionId': sessionId, 'message': message},
      options: Options(
        headers: {
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $accessToken',
        },
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data!.stream;

    String buffer = '';
    try {
      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        while (true) {
          final eventEnd = buffer.indexOf('\n\n');
          if (eventEnd < 0) break;

          final eventBlock = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          String eventType = 'message';
          final dataLines = <String>[];
          for (final line in eventBlock.split('\n')) {
            if (line.startsWith('event:')) {
              eventType = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              dataLines.add(line.substring(5).trim());
            }
          }
          if (dataLines.isNotEmpty) {
            yield SseEvent(eventType, dataLines.join('\n'));
          }
        }
      }
    } on DioException catch (e) {
      // SSE 流结束时 Dio 可能抛出连接错误，忽略已完成的流
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        // 流已正常处理完毕，忽略连接关闭错误
        return;
      }
      rethrow;
    }
  }

  /// 创建 AI 会话
  /// [accessToken] 访问令牌
  /// [title] 可选会话标题
  /// 返回值：创建的会话
  Future<AiSessionItem> createAiSession({
    required String accessToken,
    String? title,
  }) async {
    final data = await _post(
      '/ai/sessions',
      accessToken: accessToken,
      body: {if (title != null) 'title': title},
    );
    return AiSessionItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取 AI 会话列表
  /// [accessToken] 访问令牌
  /// 返回值：会话列表
  Future<List<AiSessionItem>> fetchAiSessions(String accessToken) async {
    final data = await _get('/ai/sessions', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => AiSessionItem.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 获取 AI 会话消息列表
  /// [accessToken] 访问令牌
  /// [sessionId] 会话 ID
  /// [page] 页码
  /// [size] 每页大小
  /// 返回值：消息分页结果
  Future<PageResult<AiMessageItem>> fetchAiSessionMessages({
    required String accessToken,
    required String sessionId,
    int page = 0,
    int size = 50,
  }) async {
    final data = await _get(
      '/ai/sessions/$sessionId/messages',
      accessToken: accessToken,
      queryParameters: {'page': page.toString(), 'size': size.toString()},
    );
    return _page(data, AiMessageItem.fromJson);
  }

  /// 获取管理后台仪表盘数据
  /// [accessToken] 访问令牌
  /// 返回值：仪表盘数据
  Future<AdminDashboard> fetchAdminDashboard(String accessToken) async {
    final data = await _get('/admin/dashboard', accessToken: accessToken);
    return AdminDashboard.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取管理后台标签列表
  /// [accessToken] 访问令牌
  /// 返回值：标签列表
  Future<List<TagItem>> fetchAdminTags(String accessToken) async {
    final data = await _get('/admin/tags', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => TagItem.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 创建管理后台标签
  /// [accessToken] 访问令牌
  /// [draft] 标签草稿
  /// 返回值：创建的标签
  Future<TagItem> createAdminTag({
    required String accessToken,
    required TagDraft draft,
  }) async {
    final data = await _post(
      '/admin/tags',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return TagItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台标签
  /// [accessToken] 访问令牌
  /// [id] 标签 ID
  /// [draft] 标签草稿
  /// 返回值：更新后的标签
  Future<TagItem> updateAdminTag({
    required String accessToken,
    required String id,
    required TagDraft draft,
  }) async {
    final data = await _put(
      '/admin/tags/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return TagItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台标签
  /// [accessToken] 访问令牌
  /// [id] 标签 ID
  Future<void> deleteAdminTag({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/tags/$id', accessToken: accessToken);
  }

  /// 获取管理后台友情链接列表
  /// [accessToken] 访问令牌
  /// 返回值：友情链接列表
  Future<List<FriendLink>> fetchAdminFriends(String accessToken) async {
    final data = await _get('/admin/friends', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => FriendLink.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 创建管理后台友情链接
  /// [accessToken] 访问令牌
  /// [draft] 友链草稿
  /// 返回值：创建的友链
  Future<FriendLink> createAdminFriend({
    required String accessToken,
    required FriendDraft draft,
  }) async {
    final data = await _post(
      '/admin/friends',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return FriendLink.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台友情链接
  /// [accessToken] 访问令牌
  /// [id] 友链 ID
  /// [draft] 友链草稿
  /// 返回值：更新后的友链
  Future<FriendLink> updateAdminFriend({
    required String accessToken,
    required String id,
    required FriendDraft draft,
  }) async {
    final data = await _put(
      '/admin/friends/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return FriendLink.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台友情链接
  /// [accessToken] 访问令牌
  /// [id] 友链 ID
  Future<void> deleteAdminFriend({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/friends/$id', accessToken: accessToken);
  }

  /// 获取管理后台评论列表
  /// [accessToken] 访问令牌
  /// [query] 查询参数
  /// 返回值：评论分页结果
  Future<PageResult<AdminCommentItem>> fetchAdminComments({
    required String accessToken,
    required AdminCommentQuery query,
  }) async {
    final data = await _get(
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
    return _page(data, AdminCommentItem.fromJson);
  }

  /// 更新管理后台评论状态
  /// [accessToken] 访问令牌
  /// [id] 评论 ID
  /// [status] 评论状态
  /// 返回值：更新后的评论
  Future<AdminCommentItem> updateAdminCommentStatus({
    required String accessToken,
    required String id,
    required AdminCommentStatus status,
  }) async {
    final data = await _put(
      '/admin/comments/$id/status',
      accessToken: accessToken,
      body: {'status': status.apiValue},
    );
    return AdminCommentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台评论
  /// [accessToken] 访问令牌
  /// [id] 评论 ID
  Future<void> deleteAdminComment({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/comments/$id', accessToken: accessToken);
  }

  /// 获取管理后台点赞列表
  /// [accessToken] 访问令牌
  /// [query] 查询参数
  /// 返回值：点赞分页结果
  Future<PageResult<AdminLikeItem>> fetchAdminLikes({
    required String accessToken,
    required AdminRecordQuery query,
  }) async {
    final data = await _get(
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
    return _page(data, AdminLikeItem.fromJson);
  }

  /// 删除管理后台点赞
  /// [accessToken] 访问令牌
  /// [id] 点赞 ID
  Future<void> deleteAdminLike({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/likes/$id', accessToken: accessToken);
  }

  /// 获取管理后台浏览记录列表
  /// [accessToken] 访问令牌
  /// [query] 查询参数
  /// 返回值：浏览记录分页结果
  Future<PageResult<AdminViewRecordItem>> fetchAdminViews({
    required String accessToken,
    required AdminRecordQuery query,
  }) async {
    final data = await _get(
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
    return _page(data, AdminViewRecordItem.fromJson);
  }

  /// 删除管理后台浏览记录
  /// [accessToken] 访问令牌
  /// [id] 记录 ID
  Future<void> deleteAdminView({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/views/$id', accessToken: accessToken);
  }

  /// 获取管理后台用户列表
  /// [accessToken] 访问令牌
  /// [query] 查询参数
  /// 返回值：用户分页结果
  Future<PageResult<AdminUserItem>> fetchAdminUsers({
    required String accessToken,
    required AdminUserQuery query,
  }) async {
    final data = await _get(
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
    return _page(data, AdminUserItem.fromJson);
  }

  /// 更新管理后台用户
  /// [accessToken] 访问令牌
  /// [id] 用户 ID
  /// [draft] 用户草稿
  /// 返回值：更新后的用户
  Future<AdminUserItem> updateAdminUser({
    required String accessToken,
    required String id,
    required AdminUserDraft draft,
  }) async {
    final data = await _put(
      '/admin/users/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminUserItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台用户
  /// [accessToken] 访问令牌
  /// [id] 用户 ID
  Future<void> deleteAdminUser({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/users/$id', accessToken: accessToken);
  }

  /// 获取管理后台 AI 聊天会话列表
  /// [accessToken] 访问令牌
  /// [query] 查询参数
  /// 返回值：会话分页结果
  Future<PageResult<AdminAiChatSessionItem>> fetchAdminAiChats({
    required String accessToken,
    required AdminAiChatQuery query,
  }) async {
    final data = await _get(
      '/admin/ai/chats',
      accessToken: accessToken,
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.userId.trim().isNotEmpty) 'userId': query.userId.trim(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return _page(data, AdminAiChatSessionItem.fromJson);
  }

  /// 获取管理后台 AI 聊天详情
  /// [accessToken] 访问令牌
  /// [id] 会话 ID
  /// 返回值：聊天详情
  Future<AdminAiChatDetail> fetchAdminAiChatDetail({
    required String accessToken,
    required String id,
  }) async {
    final data = await _get('/admin/ai/chats/$id', accessToken: accessToken);
    return AdminAiChatDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台 AI 聊天会话
  /// [accessToken] 访问令牌
  /// [id] 会话 ID
  Future<void> deleteAdminAiChat({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/ai/chats/$id', accessToken: accessToken);
  }

  /// 获取管理后台知识库文档列表
  /// [accessToken] 访问令牌
  /// [query] 查询参数
  /// 返回值：文档分页结果
  Future<PageResult<AdminKnowledgeDocItem>> fetchAdminKnowledgeDocs({
    required String accessToken,
    required AdminKnowledgeDocQuery query,
  }) async {
    final data = await _get(
      '/admin/knowledge/docs',
      accessToken: accessToken,
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.enabled != null) 'enabled': query.enabled.toString(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return _page(data, AdminKnowledgeDocItem.fromJson);
  }

  /// 创建管理后台知识库文档
  /// [accessToken] 访问令牌
  /// [draft] 文档草稿
  /// 返回值：创建的文档
  Future<AdminKnowledgeDocItem> createAdminKnowledgeDoc({
    required String accessToken,
    required AdminKnowledgeDocDraft draft,
  }) async {
    final data = await _post(
      '/admin/knowledge/docs',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminKnowledgeDocItem.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  /// 更新管理后台知识库文档
  /// [accessToken] 访问令牌
  /// [id] 文档 ID
  /// [draft] 文档草稿
  /// 返回值：更新后的文档
  Future<AdminKnowledgeDocItem> updateAdminKnowledgeDoc({
    required String accessToken,
    required String id,
    required AdminKnowledgeDocDraft draft,
  }) async {
    final data = await _put(
      '/admin/knowledge/docs/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminKnowledgeDocItem.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  /// 删除管理后台知识库文档
  /// [accessToken] 访问令牌
  /// [id] 文档 ID
  Future<void> deleteAdminKnowledgeDoc({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/knowledge/docs/$id', accessToken: accessToken);
  }

  /// 获取管理后台内容列表
  /// [accessToken] 访问令牌
  /// [page] 页码
  /// [size] 每页大小
  /// 返回值：内容分页结果
  Future<PageResult<AdminContentItem>> fetchAdminContents({
    required String accessToken,
    int page = 0,
    int size = 50,
  }) async {
    final data = await _get(
      '/admin/contents',
      accessToken: accessToken,
      queryParameters: {'page': page.toString(), 'size': size.toString()},
    );
    return _page(data, AdminContentItem.fromJson);
  }

  /// 创建管理后台内容
  /// [accessToken] 访问令牌
  /// [draft] 内容草稿
  /// 返回值：创建的内容
  Future<AdminContentItem> createAdminContent({
    required String accessToken,
    required AdminContentDraft draft,
  }) async {
    final data = await _post(
      '/admin/contents',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminContentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台内容
  /// [accessToken] 访问令牌
  /// [id] 内容 ID
  /// [draft] 内容草稿
  /// 返回值：更新后的内容
  Future<AdminContentItem> updateAdminContent({
    required String accessToken,
    required String id,
    required AdminContentDraft draft,
  }) async {
    final data = await _put(
      '/admin/contents/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminContentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 归档管理后台内容
  /// [accessToken] 访问令牌
  /// [id] 内容 ID
  Future<void> archiveAdminContent({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/contents/$id', accessToken: accessToken);
  }

  /// 获取管理后台媒体列表
  /// [accessToken] 访问令牌
  /// [contentId] 可选内容 ID
  /// [page] 页码
  /// [size] 每页大小
  /// 返回值：媒体分页结果
  Future<PageResult<AdminMediaItem>> fetchAdminMedia({
    required String accessToken,
    String? contentId,
    int page = 0,
    int size = 80,
  }) async {
    final data = await _get(
      '/admin/media-assets',
      accessToken: accessToken,
      queryParameters: {
        if (contentId != null && contentId.isNotEmpty) 'contentId': contentId,
        'page': page.toString(),
        'size': size.toString(),
      },
    );
    return _page(data, AdminMediaItem.fromJson);
  }

  /// 创建管理后台媒体
  /// [accessToken] 访问令牌
  /// [draft] 媒体草稿
  /// 返回值：创建的媒体
  Future<AdminMediaItem> createAdminMedia({
    required String accessToken,
    required AdminMediaDraft draft,
  }) async {
    final data = await _post(
      '/admin/media-assets',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 上传管理后台媒体文件
  /// 使用 Dio 的 FormData 实现 multipart 上传
  /// [accessToken] 访问令牌
  /// [bytes] 文件字节
  /// [filename] 文件名
  /// [type] 媒体类型
  /// [contentId] 可选内容 ID
  /// 返回值：上传的媒体
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

    final data = await _send(
      'POST',
      '/admin/media-assets/upload',
      accessToken: accessToken,
      formData: formData,
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台媒体
  /// [accessToken] 访问令牌
  /// [id] 媒体 ID
  /// [draft] 媒体草稿
  /// 返回值：更新后的媒体
  Future<AdminMediaItem> updateAdminMedia({
    required String accessToken,
    required String id,
    required AdminMediaDraft draft,
  }) async {
    final data = await _put(
      '/admin/media-assets/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台媒体
  /// [accessToken] 访问令牌
  /// [id] 媒体 ID
  Future<void> deleteAdminMedia({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/media-assets/$id', accessToken: accessToken);
  }

  /// 设置内容封面
  /// [accessToken] 访问令牌
  /// [contentId] 内容 ID
  /// [mediaId] 媒体 ID
  /// 返回值：更新后的内容
  Future<AdminContentItem> setAdminContentCover({
    required String accessToken,
    required String contentId,
    required String mediaId,
  }) async {
    final data = await _put(
      '/admin/contents/$contentId/cover/$mediaId',
      accessToken: accessToken,
      body: const {},
    );
    return AdminContentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 发送 GET 请求
  Future<Object?> _get(
    String path, {
    Map<String, dynamic> queryParameters = const {},
    String? accessToken,
  }) {
    return _send(
      'GET',
      path,
      queryParameters: queryParameters,
      accessToken: accessToken,
    );
  }

  /// 发送 POST 请求
  Future<Object?> _post(
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
  }) {
    return _send('POST', path, accessToken: accessToken, body: body);
  }

  /// 发送 PUT 请求
  Future<Object?> _put(
    String path, {
    required String accessToken,
    required Map<String, Object?> body,
  }) {
    return _send('PUT', path, accessToken: accessToken, body: body);
  }

  /// 发送 DELETE 请求
  Future<Object?> _delete(String path, {required String accessToken}) {
    return _send('DELETE', path, accessToken: accessToken);
  }

  /// 发送 HTTP 请求的核心方法
  /// 支持 401 自动刷新令牌，使用 Dio 拦截器模式
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic> queryParameters = const {},
    String? accessToken,
    Map<String, Object?>? body,
    FormData? formData,
  }) async {
    final headers = <String, String>{
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await _dio.request<Object?>(
        path,
        data: formData ?? (body != null ? jsonEncode(body) : null),
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          contentType: body != null || formData != null
              ? 'application/json'
              : null,
        ),
      );

      return _extractData(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 &&
          accessToken != null &&
          onUnauthorized != null) {
        final newToken = await onUnauthorized!();
        if (newToken != null) {
          headers['Authorization'] = 'Bearer $newToken';
          final retryResponse = await _dio.request<Object?>(
            path,
            data: formData ?? (body != null ? jsonEncode(body) : null),
            queryParameters: queryParameters,
            options: Options(
              method: method,
              headers: headers,
              contentType: body != null || formData != null
                  ? 'application/json'
                  : null,
            ),
          );
          return _extractData(retryResponse);
        }
      }
      rethrow;
    }
  }

  /// 从 Dio 响应中提取业务数据
  Object? _extractData(Response<Object?> response) {
    final decoded = response.data;
    if (decoded is! Map) {
      throw ApiException(
        '后端响应格式不正确',
        statusCode: response.statusCode,
      );
    }

    final envelope = decoded.cast<String, dynamic>();
    final success = envelope['success'] == true;
    if (!success) {
      throw ApiException(
        envelope['message']?.toString() ?? '请求失败',
        statusCode: response.statusCode,
      );
    }

    return envelope['data'];
  }

  /// 解析分页结果
  PageResult<T> _page<T>(
    Object? data,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final json = (data as Map).cast<String, dynamic>();
    return PageResult<T>(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => mapper(item.cast<String, dynamic>()))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
