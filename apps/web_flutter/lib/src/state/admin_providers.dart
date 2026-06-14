// 管理后台 Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import 'api_providers.dart';

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
    FutureProvider.autoDispose.family<PageResult<AdminCommentItem>, AdminCommentQuery>((
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
    FutureProvider.autoDispose.family<PageResult<AdminLikeItem>, AdminRecordQuery>((
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
    FutureProvider.autoDispose.family<PageResult<AdminViewRecordItem>, AdminRecordQuery>((
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
    FutureProvider.autoDispose.family<PageResult<AdminUserItem>, AdminUserQuery>((
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
    FutureProvider.autoDispose.family<PageResult<AdminAiChatSessionItem>, AdminAiChatQuery>(
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
final adminKnowledgeDocsProvider = FutureProvider.autoDispose.family<
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

/// 内容列表查询条件 Notifier
class AdminContentQueryNotifier extends Notifier<AdminContentQuery> {
  @override
  AdminContentQuery build() => const AdminContentQuery();

  void update(AdminContentQuery query) => state = query;
}

/// 管理后台内容列表查询条件
final adminContentQueryProvider = NotifierProvider<
    AdminContentQueryNotifier, AdminContentQuery>(
  AdminContentQueryNotifier.new,
);

/// 管理后台内容列表 Provider
/// 自动 watch 查询条件，条件变化时自动 refetch
final adminContentsProvider =
    FutureProvider<PageResult<AdminContentItem>>((ref) {
      final query = ref.watch(adminContentQueryProvider);
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchAdminContents(accessToken: token, query: query);
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
    FutureProvider.autoDispose.family<PageResult<AuditLogItem>, AuditLogQuery>((
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
