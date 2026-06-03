// 管理后台模块
// 管理后台主页 Shell，导入各标签页模块并组装 TabBar
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_providers.dart';
import 'tabs/ai_chat_admin_tab.dart';
import 'tabs/audit_log_admin_tab.dart';
import 'tabs/comment_admin_tab.dart';
import 'tabs/content_admin_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/friend_admin_tab.dart';
import 'tabs/interaction_admin_tab.dart';
import 'tabs/knowledge_admin_tab.dart';
import 'tabs/media_admin_tab.dart';
import 'tabs/tag_admin_tab.dart';
import 'tabs/user_admin_tab.dart';

/// 管理后台主页 Widget
/// 需要 ADMIN 角色才能访问，包含 12 个管理标签页
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider); // 获取认证状态
    final role = auth.user?.role.toUpperCase(); // 用户角色（大写）

    if (!auth.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理员中心')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (role != 'ADMIN') {
      return Scaffold(
        appBar: AppBar(title: const Text('管理员中心')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('当前账号没有管理员权限'),
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 12,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('管理员中心'),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.space_dashboard_outlined), text: '概览'),
              Tab(icon: Icon(Icons.article_outlined), text: '内容'),
              Tab(icon: Icon(Icons.perm_media_outlined), text: '媒体'),
              Tab(icon: Icon(Icons.people_outline), text: '朋友'),
              Tab(icon: Icon(Icons.sell_outlined), text: '标签'),
              Tab(icon: Icon(Icons.mode_comment_outlined), text: '评论'),
              Tab(icon: Icon(Icons.favorite_border), text: '点赞'),
              Tab(icon: Icon(Icons.history_outlined), text: '浏览'),
              Tab(icon: Icon(Icons.manage_accounts_outlined), text: '用户'),
              Tab(icon: Icon(Icons.smart_toy_outlined), text: 'AI'),
              Tab(icon: Icon(Icons.library_books_outlined), text: '知识库'),
              Tab(icon: Icon(Icons.shield_outlined), text: '日志'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminDashboardTab(),
            AdminContentTab(),
            AdminMediaTab(),
            AdminFriendTab(),
            AdminTagTab(),
            AdminCommentTab(),
            AdminLikeTab(),
            AdminViewTab(),
            AdminUserTab(),
            AdminAiChatTab(),
            AdminKnowledgeTab(),
            AdminAuditLogTab(),
          ],
        ),
      ),
    );
  }

  /// 刷新所有管理数据
  /// 使所有管理相关的 Provider 失效，触发重新加载
  void _refresh(WidgetRef ref) {
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminMediaProvider);
    ref.invalidate(adminFriendsProvider);
    ref.invalidate(adminTagsProvider);
    ref.invalidate(adminCommentsProvider);
    ref.invalidate(adminLikesProvider);
    ref.invalidate(adminViewsProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminAiChatsProvider);
    ref.invalidate(adminKnowledgeDocsProvider);
    ref.invalidate(adminAuditLogsProvider);
  }
}
