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

import 'tabs/tag_admin_tab.dart';
import 'tabs/user_admin_tab.dart';

/// 管理后台主页 Widget
/// 根据用户角色显示不同的管理标签页
/// ADMIN: 所有 11 个标签页
/// USER: 仅概览、内容、评论、点赞、浏览 5 个标签页
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider); // 获取认证状态
    final isAdmin = auth.user?.isAdmin ?? false; // 是否为管理员

    if (!auth.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理员中心')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAdmin && auth.user?.role.toUpperCase() != 'USER') {
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

    // 根据角色过滤标签页
    final tabs = <_AdminTab>[
      const _AdminTab(
        icon: Icon(Icons.space_dashboard_outlined),
        selectedIcon: Icon(Icons.space_dashboard),
        label: '概览',
        builder: AdminDashboardTab(),
      ),
      const _AdminTab(
        icon: Icon(Icons.article_outlined),
        selectedIcon: Icon(Icons.article),
        label: '内容',
        builder: AdminContentTab(),
      ),

      const _AdminTab(
        icon: Icon(Icons.mode_comment_outlined),
        selectedIcon: Icon(Icons.mode_comment),
        label: '评论',
        builder: AdminCommentTab(),
      ),
      const _AdminTab(
        icon: Icon(Icons.favorite_border),
        selectedIcon: Icon(Icons.favorite),
        label: '点赞',
        builder: AdminLikeTab(),
      ),
      const _AdminTab(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: '浏览',
        builder: AdminViewTab(),
      ),
      // 以下标签页仅 ADMIN 可见
      if (isAdmin)
        const _AdminTab(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: '朋友',
          builder: AdminFriendTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          icon: Icon(Icons.sell_outlined),
          selectedIcon: Icon(Icons.sell),
          label: '标签',
          builder: AdminTagTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts),
          label: '用户',
          builder: AdminUserTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          icon: Icon(Icons.smart_toy_outlined),
          selectedIcon: Icon(Icons.smart_toy),
          label: 'AI',
          builder: AdminAiChatTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          icon: Icon(Icons.library_books_outlined),
          selectedIcon: Icon(Icons.library_books),
          label: '知识库',
          builder: AdminKnowledgeTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          icon: Icon(Icons.shield_outlined),
          selectedIcon: Icon(Icons.shield),
          label: '日志',
          builder: AdminAuditLogTab(),
        ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAdmin ? '管理员中心' : '内容管理'),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final tab in tabs) Tab(icon: tab.icon, text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [for (final tab in tabs) tab.builder],
        ),
      ),
    );
  }

  /// 刷新所有管理数据
  /// 使所有管理相关的 Provider 失效，触发重新加载
  void _refresh(WidgetRef ref) {
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);

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

/// 管理标签页数据模型
class _AdminTab {
  const _AdminTab({
    required this.icon,
    required this.label,
    required this.builder,
    this.selectedIcon,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
  final Widget builder;
}
