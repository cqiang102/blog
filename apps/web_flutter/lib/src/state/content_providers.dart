// 内容相关 Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import 'api_providers.dart';
import 'content_filter_state.dart';
import 'pagination_state.dart';

/// 跨页面共享的首页推荐查询缓存。
final recommendationsProvider = FutureProvider<Recommendations>((ref) {
  return ref.watch(apiClientProvider).fetchRecommendations();
});

/// 标签列表 Provider
final tagsProvider = FutureProvider<List<TagItem>>((ref) {
  return ref.watch(apiClientProvider).fetchTags();
});

/// 内容列表 Provider（支持查询参数）
final contentListProvider = FutureProvider.autoDispose
    .family<PageResult<BlogContent>, ContentListQuery>((ref, query) {
      return ref.watch(apiClientProvider).fetchContents(query);
    });

/// 内容详情 Provider
final contentDetailProvider = FutureProvider.autoDispose
    .family<BlogContent, String>((ref, id) {
      final token = ref.watch(
        authControllerProvider.select((auth) => auth.accessToken),
      );
      return ref.watch(apiClientProvider).fetchContent(id, accessToken: token);
    });

/// 评论列表 Provider
final commentsProvider = FutureProvider.autoDispose
    .family<PageResult<CommentItem>, String>((ref, contentId) {
      return ref.watch(apiClientProvider).fetchComments(contentId);
    });

/// 友情链接 Provider
final friendsProvider = FutureProvider<List<FriendLink>>((ref) {
  return ref.watch(apiClientProvider).fetchFriends();
});

/// 内容筛选状态 Provider
final contentFilterProvider =
    NotifierProvider<ContentFilterNotifier, ContentFilterState>(
      ContentFilterNotifier.new,
    );

class ContentPaginationNotifier extends PaginationNotifier<BlogContent> {
  ContentPaginationNotifier(this.query);

  final ContentListQuery query;

  @override
  PaginationState<BlogContent> build() {
    ref.watch(apiClientProvider);
    return super.build();
  }

  @override
  Future<PageResult<BlogContent>> fetchPage(int page, int size) {
    final q = ContentListQuery(
      query: query.query,
      tag: query.tag,
      type: query.type,
      startDate: query.startDate,
      endDate: query.endDate,
      page: page,
      size: size,
    );
    return ref.read(apiClientProvider).fetchContents(q);
  }
}

/// 内容分页状态 Provider
/// 根据筛选条件动态创建分页状态
final contentPaginationProvider = NotifierProvider.autoDispose
    .family<
      ContentPaginationNotifier,
      PaginationState<BlogContent>,
      ContentListQuery
    >(ContentPaginationNotifier.new);
