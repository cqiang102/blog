import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api/v1',
);

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class BlogApiClient {
  const BlogApiClient({
    required http.Client httpClient,
    this.baseUrl = apiBaseUrl,
  }) : _httpClient = httpClient;

  final http.Client _httpClient;
  final String baseUrl;

  String get githubAuthorizationUrl {
    final apiUri = Uri.parse(baseUrl);
    return apiUri
        .replace(path: '/oauth2/authorization/github', query: '')
        .toString();
  }

  Future<Recommendations> fetchRecommendations() async {
    final data = await _get('/contents/recommendations');
    return Recommendations.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PageResult<BlogContent>> fetchContents(ContentListQuery query) async {
    final data = await _get(
      '/contents',
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.tag != null) 'tag': query.tag,
        if (query.type != null) 'type': query.type!.apiValue,
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    final json = (data as Map).cast<String, dynamic>();
    return PageResult<BlogContent>(
      items:
          (json['items'] as List? ?? const [])
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

  Future<BlogContent> fetchContent(String id, {String? accessToken}) async {
    final data = await _get('/contents/$id', accessToken: accessToken);
    return BlogContent.fromDetailJson((data as Map).cast<String, dynamic>());
  }

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

  Future<UserProfile> me(String accessToken) async {
    final data = await _get('/me', accessToken: accessToken);
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

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

  Future<PageResult<CommentItem>> fetchComments(String contentId) async {
    final data = await _get('/contents/$contentId/comments');
    return _page(data, CommentItem.fromJson);
  }

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

  Future<void> deleteComment({
    required String accessToken,
    required String commentId,
  }) async {
    await _delete('/comments/$commentId', accessToken: accessToken);
  }

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

  Future<void> recordView({
    required String contentId,
    String? accessToken,
  }) async {
    await _post('/contents/$contentId/views', accessToken: accessToken);
  }

  Future<PageResult<UserActivity>> fetchMyActivity({
    required String accessToken,
    required String type,
  }) async {
    final data = await _get('/me/$type', accessToken: accessToken);
    return _page(data, UserActivity.fromJson);
  }

  Future<void> deleteMyActivity({
    required String accessToken,
    required String type,
    required String id,
  }) async {
    await _delete('/me/$type/$id', accessToken: accessToken);
  }

  Future<AiQuota> fetchAiQuota(String accessToken) async {
    final data = await _get('/ai/quota', accessToken: accessToken);
    return AiQuota.fromJson((data as Map).cast<String, dynamic>());
  }

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

  Future<AdminDashboard> fetchAdminDashboard(String accessToken) async {
    final data = await _get('/admin/dashboard', accessToken: accessToken);
    return AdminDashboard.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<TagItem>> fetchAdminTags(String accessToken) async {
    final data = await _get('/admin/tags', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => TagItem.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

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

  Future<void> deleteAdminTag({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/tags/$id', accessToken: accessToken);
  }

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

  Future<void> archiveAdminContent({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/contents/$id', accessToken: accessToken);
  }

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

  Future<void> deleteAdminMedia({
    required String accessToken,
    required String id,
  }) async {
    await _delete('/admin/media-assets/$id', accessToken: accessToken);
  }

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

  Future<Object?> _get(
    String path, {
    Map<String, String?> queryParameters = const {},
    String? accessToken,
  }) {
    return _send(
      'GET',
      path,
      queryParameters: queryParameters,
      accessToken: accessToken,
    );
  }

  Future<Object?> _post(
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
  }) {
    return _send('POST', path, accessToken: accessToken, body: body);
  }

  Future<Object?> _put(
    String path, {
    required String accessToken,
    required Map<String, Object?> body,
  }) {
    return _send('PUT', path, accessToken: accessToken, body: body);
  }

  Future<Object?> _delete(String path, {required String accessToken}) {
    return _send('DELETE', path, accessToken: accessToken);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String?> queryParameters = const {},
    String? accessToken,
    Map<String, Object?>? body,
  }) async {
    final uri = _uri(path, queryParameters);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    final response = switch (method) {
      'POST' => await _httpClient.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      'PUT' => await _httpClient.put(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ),
      'DELETE' => await _httpClient.delete(uri, headers: headers),
      _ => await _httpClient.get(uri, headers: headers),
    };

    final decoded =
        response.body.isEmpty ? <String, Object?>{} : jsonDecode(response.body);
    if (decoded is! Map) {
      throw ApiException('后端响应格式不正确', statusCode: response.statusCode);
    }

    final envelope = decoded.cast<String, dynamic>();
    final success = envelope['success'] == true;
    if (response.statusCode >= 400 || !success) {
      throw ApiException(
        envelope['message']?.toString() ?? '请求失败',
        statusCode: response.statusCode,
      );
    }

    return envelope['data'];
  }

  PageResult<T> _page<T>(
    Object? data,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final json = (data as Map).cast<String, dynamic>();
    return PageResult<T>(
      items:
          (json['items'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => mapper(item.cast<String, dynamic>()))
              .toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Uri _uri(String path, Map<String, String?> queryParameters) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final query = Map.fromEntries(
      queryParameters.entries.where(
        (entry) => entry.value != null && entry.value!.isNotEmpty,
      ),
    );
    final resolved = base.resolve(cleanPath);
    return query.isEmpty ? resolved : resolved.replace(queryParameters: query);
  }
}
