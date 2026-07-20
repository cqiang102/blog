// 内容相关 API
// 包含内容列表、详情、评论、点赞等

import '../models.dart';
import 'api_client_base.dart';

/// 内容相关 API Mixin
mixin ContentApi on ApiClientBase {
  /// 获取首页推荐内容
  Future<Recommendations> fetchRecommendations() async {
    final data = await get('/contents/recommendations');
    return decodeObject(data, Recommendations.fromJson);
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
    return pageResult(data, BlogContent.fromSummaryJson);
  }

  /// 获取内容详情
  Future<BlogContent> fetchContent(String id, {String? accessToken}) async {
    final data = await get('/contents/$id', accessToken: accessToken);
    return decodeObject(data, BlogContent.fromDetailJson);
  }

  /// 获取所有标签
  Future<List<TagItem>> fetchTags() async {
    final data = await get('/contents/tags');
    return decodeObjectList(data, TagItem.fromJson);
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
    return decodeObject(data, CommentItem.fromJson);
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
    return decodeObject(data, (json) => json['liked'] as bool);
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
    return decodeObject(data, (json) => json['liked'] as bool);
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
