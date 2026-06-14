// 内容相关 Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/models.dart';
import 'api_providers.dart';
import 'content_filter_state.dart';
import 'pagination_state.dart';

/// 首页推荐内容 Provider
final recommendationsProvider = FutureProvider<Recommendations>((ref) {
  return ref.watch(apiClientProvider).fetchRecommendations();
});

/// 标签列表 Provider
final tagsProvider = FutureProvider<List<TagItem>>((ref) {
  return ref.watch(apiClientProvider).fetchTags();
});

/// 内容列表 Provider（支持查询参数）
final contentListProvider =
    FutureProvider.autoDispose.family<PageResult<BlogContent>, ContentListQuery>((
      ref,
      query,
    ) {
      return ref.watch(apiClientProvider).fetchContents(query);
    });

/// 内容详情 Provider
final contentDetailProvider = FutureProvider.autoDispose.family<BlogContent, String>((
  ref,
  id,
) {
  final token = ref.watch(
    authControllerProvider.select((auth) => auth.accessToken),
  );
  return ref.watch(apiClientProvider).fetchContent(id, accessToken: token);
});

/// 评论列表 Provider
final commentsProvider =
    FutureProvider.autoDispose.family<PageResult<CommentItem>, String>(
  (ref, contentId) {
    return ref.watch(apiClientProvider).fetchComments(contentId);
  },
);

/// 友情链接 Provider
final friendsProvider = FutureProvider<List<FriendLink>>((ref) {
  return ref.watch(apiClientProvider).fetchFriends();
});

/// 内容筛选状态 Provider
final contentFilterProvider =
    StateNotifierProvider<ContentFilterNotifier, ContentFilterState>((ref) {
  return ContentFilterNotifier();
});

/// 内容分页状态 Provider
/// 根据筛选条件动态创建分页状态
final contentPaginationProvider = StateNotifierProvider.autoDispose.family<
    PaginationNotifier<BlogContent>,
    PaginationState<BlogContent>,
    ContentListQuery>((ref, query) {
  final api = ref.watch(apiClientProvider);
  return PaginationNotifier<BlogContent>((page, size) {
    final q = ContentListQuery(
      query: query.query,
      tag: query.tag,
      type: query.type,
      startDate: query.startDate,
      endDate: query.endDate,
      page: page,
      size: size,
    );
    return api.fetchContents(q);
  });
});
