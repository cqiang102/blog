// 内容相关 API
// 包含内容列表、详情、评论、点赞等

import '../models.dart';
import 'api_client_base.dart';

/// 内容相关 API Mixin
mixin ContentApi on ApiClientBase {
  /// 获取首页推荐内容
  Future<Recommendations> fetchRecommendations() async {
    final data = await get('/contents/recommendations');
    return Recommendations.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取内容列表（分页）
  Future<PageResult<BlogContent>> fetchContents(ContentListQuery query) async {
    final data = await get(
      '/contents',
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.tag != null) 'tag': query.tag,
        if (query.type != null) 'type': query.type!.apiValue,
        if (query.startDate != null)
          'from': query.startDate!.toUtc().toIso8601String(),
        if (query.endDate != null)
          'to': _endOfLocalDay(query.endDate!).toUtc().toIso8601String(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    final json = (data as Map).cast<String, dynamic>();
    return PageResult<BlogContent>(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => BlogContent.fromSummaryJson(item.cast<String, dynamic>()),
          )
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// 获取内容详情
  Future<BlogContent> fetchContent(String id, {String? accessToken}) async {
    final data = await get('/contents/$id', accessToken: accessToken);
    return BlogContent.fromDetailJson((data as Map).cast<String, dynamic>());
  }

  /// 获取所有标签
  Future<List<TagItem>> fetchTags() async {
    final data = await get('/contents/tags');
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => TagItem.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 获取内容评论列表
  Future<PageResult<CommentItem>> fetchComments(String contentId) async {
    final data = await get('/contents/$contentId/comments');
    return pageResult(data, CommentItem.fromJson);
  }

  /// 创建评论
  Future<CommentItem> createComment({
    required String accessToken,
    required String contentId,
    required String body,
  }) async {
    final data = await post(
      '/contents/$contentId/comments',
      accessToken: accessToken,
      body: {'body': body},
    );
    return CommentItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除评论
  Future<void> deleteComment({
    required String accessToken,
    required String commentId,
  }) async {
    await delete('/comments/$commentId', accessToken: accessToken);
  }

  /// 点赞内容
  Future<bool> likeContent({
    required String accessToken,
    required String contentId,
  }) async {
    final data = await post(
      '/contents/$contentId/likes',
      accessToken: accessToken,
    );
    return ((data as Map).cast<String, dynamic>())['liked'] == true;
  }

  /// 取消点赞内容
  Future<bool> unlikeContent({
    required String accessToken,
    required String contentId,
  }) async {
    final data = await delete(
      '/contents/$contentId/likes',
      accessToken: accessToken,
    );
    return ((data as Map).cast<String, dynamic>())['liked'] == true;
  }

  /// 记录浏览
  Future<void> recordView({
    required String contentId,
    String? accessToken,
  }) async {
    await post('/contents/$contentId/views', accessToken: accessToken);
  }
}

DateTime _endOfLocalDay(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day + 1,
).subtract(const Duration(microseconds: 1));
