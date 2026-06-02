import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'auth_controller.dart';
import 'models.dart';

final apiClientProvider = Provider<BlogApiClient>((ref) {
  final httpClient = http.Client();
  ref.onDispose(httpClient.close);
  return BlogApiClient(httpClient: httpClient);
});

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController(ref.watch(apiClientProvider));
  controller.load();
  return controller;
});

final recommendationsProvider = FutureProvider<Recommendations>((ref) {
  return ref.watch(apiClientProvider).fetchRecommendations();
});

final contentListProvider =
    FutureProvider.family<PageResult<BlogContent>, ContentListQuery>((
      ref,
      query,
    ) {
      return ref.watch(apiClientProvider).fetchContents(query);
    });

final contentDetailProvider = FutureProvider.family<BlogContent, String>((
  ref,
  id,
) {
  final token = ref.watch(authControllerProvider).accessToken;
  return ref.watch(apiClientProvider).fetchContent(id, accessToken: token);
});

final commentsProvider = FutureProvider.family<PageResult<CommentItem>, String>(
  (ref, contentId) {
    return ref.watch(apiClientProvider).fetchComments(contentId);
  },
);

final friendsProvider = FutureProvider<List<FriendLink>>((ref) {
  return ref.watch(apiClientProvider).fetchFriends();
});

final userActivityProvider =
    FutureProvider.family<PageResult<UserActivity>, String>((ref, type) {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchMyActivity(accessToken: token, type: type);
    });

final aiQuotaProvider = FutureProvider<AiQuota>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAiQuota(token);
});

final adminDashboardProvider = FutureProvider<AdminDashboard>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminDashboard(token);
});

final adminTagsProvider = FutureProvider<List<TagItem>>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminTags(token);
});

final adminFriendsProvider = FutureProvider<List<FriendLink>>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminFriends(token);
});

final adminCommentsProvider =
    FutureProvider.family<PageResult<AdminCommentItem>, AdminCommentQuery>((
      ref,
      query,
    ) {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchAdminComments(accessToken: token, query: query);
    });

final adminLikesProvider =
    FutureProvider.family<PageResult<AdminLikeItem>, AdminRecordQuery>((
      ref,
      query,
    ) {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchAdminLikes(accessToken: token, query: query);
    });

final adminViewsProvider =
    FutureProvider.family<PageResult<AdminViewRecordItem>, AdminRecordQuery>((
      ref,
      query,
    ) {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchAdminViews(accessToken: token, query: query);
    });

final adminUsersProvider =
    FutureProvider.family<PageResult<AdminUserItem>, AdminUserQuery>((
      ref,
      query,
    ) {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchAdminUsers(accessToken: token, query: query);
    });

final adminAiChatsProvider =
    FutureProvider.family<PageResult<AdminAiChatSessionItem>, AdminAiChatQuery>(
      (ref, query) {
        final token = ref.watch(authControllerProvider).accessToken;
        if (token == null) {
          throw const ApiException('请先登录');
        }
        return ref
            .watch(apiClientProvider)
            .fetchAdminAiChats(accessToken: token, query: query);
      },
    );

final adminKnowledgeDocsProvider = FutureProvider.family<
  PageResult<AdminKnowledgeDocItem>,
  AdminKnowledgeDocQuery
>((ref, query) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref
      .watch(apiClientProvider)
      .fetchAdminKnowledgeDocs(accessToken: token, query: query);
});

final adminContentsProvider = FutureProvider<PageResult<AdminContentItem>>((
  ref,
) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminContents(accessToken: token);
});

final adminMediaProvider = FutureProvider<PageResult<AdminMediaItem>>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminMedia(accessToken: token);
});
