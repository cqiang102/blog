// 管理后台模块
// 管理后台主页 Shell，导入各标签页模块并组装 TabBar
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/constants.dart';
import '../../state/state.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/widgets.dart';
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
/// 添加 AutomaticKeepAliveClientMixin 保持页面状态
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage>
    with AutomaticKeepAliveClientMixin {
  late int _selectedIndex;
  late final Set<int> _visitedTabs;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _visitedTabs = {widget.initialTab};
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    _selectedIndex = widget.initialTab;
    _visitedTabs.add(widget.initialTab);
  }

  @override
  bool get wantKeepAlive => true;

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = ref.watch(authControllerProvider);
    final isAdmin = auth.user?.isAdmin ?? false;

    if (!auth.isLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('管理员中心'),
          actions: const [AppThemeToggle()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAdmin && auth.user?.role.toUpperCase() != 'USER') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('管理员中心'),
          actions: const [AppThemeToggle()],
        ),
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
        id: 'overview',
        label: '概览',
        group: '工作台',
        icon: Icons.space_dashboard_outlined,
        builder: AdminDashboardTab(),
      ),
      const _AdminTab(
        id: 'content',
        label: '内容',
        group: '内容',
        icon: Icons.article_outlined,
        builder: AdminContentTab(),
      ),

      const _AdminTab(
        id: 'comments',
        label: '评论',
        group: '内容',
        icon: Icons.mode_comment_outlined,
        builder: AdminCommentTab(),
      ),
      const _AdminTab(
        id: 'likes',
        label: '点赞',
        group: '内容',
        icon: Icons.favorite_border_rounded,
        builder: AdminLikeTab(),
      ),
      const _AdminTab(
        id: 'views',
        label: '浏览',
        group: '内容',
        icon: Icons.visibility_outlined,
        builder: AdminViewTab(),
      ),
      // 以下标签页仅 ADMIN 可见
      if (isAdmin)
        const _AdminTab(
          id: 'friends',
          label: '朋友',
          group: '运营',
          icon: Icons.link_rounded,
          builder: AdminFriendTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          id: 'tags',
          label: '标签',
          group: '运营',
          icon: Icons.label_outline_rounded,
          builder: AdminTagTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          id: 'users',
          label: '用户',
          group: '运营',
          icon: Icons.group_outlined,
          builder: AdminUserTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          id: 'ai',
          label: 'AI 会话',
          group: 'AI',
          icon: Icons.auto_awesome_outlined,
          builder: AdminAiChatTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          id: 'knowledge',
          label: '知识库',
          group: 'AI',
          icon: Icons.library_books_outlined,
          builder: AdminKnowledgeTab(),
        ),
      if (isAdmin)
        const _AdminTab(
          id: 'logs',
          label: '日志',
          group: '系统',
          icon: Icons.history_rounded,
          builder: AdminAuditLogTab(),
        ),
    ];

    final selectedIndex = _selectedIndex.clamp(0, tabs.length - 1);

    return AppPageFrame(
      child: Column(
        children: [
          AppPageHeader(
            title: isAdmin ? '管理员中心' : '内容管理',
            subtitle: '当前模块：${tabs[selectedIndex].label}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppThemeToggle(),
                IconButton(
                  tooltip: '刷新当前管理数据',
                  onPressed: () => _refresh(ref),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pages = IndexedStack(
                  index: selectedIndex,
                  children: [
                    for (var index = 0; index < tabs.length; index++)
                      _visitedTabs.contains(index)
                          ? tabs[index].builder
                          : const SizedBox.shrink(),
                  ],
                );
                void select(int index) {
                  _selectTab(index);
                  context.go('/admin?tab=${tabs[index].id}');
                }

                if (constraints.maxWidth >= kWideBreakpoint) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 208,
                        child: _AdminDesktopNavigation(
                          tabs: tabs,
                          selectedIndex: selectedIndex,
                          onSelected: select,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: pages),
                    ],
                  );
                }

                return Column(
                  children: [
                    AppHorizontalTabs(
                      labels: tabs.map((tab) => tab.label).toList(),
                      selectedIndex: selectedIndex,
                      onSelected: select,
                    ),
                    Expanded(child: pages),
                  ],
                );
              },
            ),
          ),
        ],
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
    required this.id,
    required this.label,
    required this.group,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String label;
  final String group;
  final IconData icon;
  final Widget builder;
}

class _AdminDesktopNavigation extends StatelessWidget {
  const _AdminDesktopNavigation({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdminTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);
    final children = <Widget>[];
    String? currentGroup;
    for (var index = 0; index < tabs.length; index++) {
      final tab = tabs[index];
      if (currentGroup != tab.group) {
        currentGroup = tab.group;
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: AppSpacing.md));
        }
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Text(
              tab.group,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.1,
              ),
            ),
          ),
        );
      }
      final selected = index == selectedIndex;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: ListTile(
            selected: selected,
            selectedColor: scheme.primary,
            selectedTileColor: design.mint,
            leading: Icon(tab.icon, size: 20),
            title: Text(tab.label),
            dense: true,
            minTileHeight: 44,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            onTap: () => onSelected(index),
          ),
        ),
      );
    }

    return ColoredBox(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.68),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: children,
      ),
    );
  }
}
