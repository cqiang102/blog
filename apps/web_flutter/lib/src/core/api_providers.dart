/// Riverpod Provider 定义
/// 全局状态管理，提供 API 客户端、认证控制器和各业务数据 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'auth_controller.dart';
import 'models.dart';

/// API 客户端 Provider
final apiClientProvider = Provider<BlogApiClient>((ref) {
  final httpClient = http.Client();
  ref.onDispose(httpClient.close); // 销毁时关闭 HTTP 客户端
  return BlogApiClient(httpClient: httpClient);
});

/// 认证控制器 Provider
final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController(ref.watch(apiClientProvider));
  controller.load(); // 初始化时加载认证状态
  return controller;
});

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
    FutureProvider.family<PageResult<BlogContent>, ContentListQuery>((
      ref,
      query,
    ) {
      return ref.watch(apiClientProvider).fetchContents(query);
    });

/// 内容详情 Provider
final contentDetailProvider = FutureProvider.family<BlogContent, String>((
  ref,
  id,
) {
  final token = ref.watch(authControllerProvider).accessToken;
  return ref.watch(apiClientProvider).fetchContent(id, accessToken: token);
});

/// 评论列表 Provider
final commentsProvider = FutureProvider.family<PageResult<CommentItem>, String>(
  (ref, contentId) {
    return ref.watch(apiClientProvider).fetchComments(contentId);
  },
);

/// 友情链接 Provider
final friendsProvider = FutureProvider<List<FriendLink>>((ref) {
  return ref.watch(apiClientProvider).fetchFriends();
});

/// 用户活动记录 Provider
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

/// AI 配额 Provider
final aiQuotaProvider = FutureProvider<AiQuota>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAiQuota(token);
});

/// 管理后台仪表盘 Provider
final adminDashboardProvider = FutureProvider<AdminDashboard>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminDashboard(token);
});

/// 管理后台标签列表 Provider
final adminTagsProvider = FutureProvider<List<TagItem>>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminTags(token);
});

/// 管理后台友情链接列表 Provider
final adminFriendsProvider = FutureProvider<List<FriendLink>>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminFriends(token);
});

/// 管理后台评论列表 Provider
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

/// 管理后台点赞列表 Provider
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

/// 管理后台浏览记录列表 Provider
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

/// 管理后台用户列表 Provider
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

/// 管理后台 AI 聊天会话列表 Provider
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

/// 管理后台知识库文档列表 Provider
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

/// 管理后台内容列表 Provider
final adminContentsProvider = FutureProvider<PageResult<AdminContentItem>>((
  ref,
) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminContents(accessToken: token);
});

/// 管理后台媒体列表 Provider
final adminMediaProvider = FutureProvider<PageResult<AdminMediaItem>>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAdminMedia(accessToken: token);
});

/// 管理后台审计日志列表 Provider
final adminAuditLogsProvider =
    FutureProvider.family<PageResult<AuditLogItem>, AuditLogQuery>((
      ref,
      query,
    ) {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchAdminAuditLogs(accessToken: token, query: query);
    });
