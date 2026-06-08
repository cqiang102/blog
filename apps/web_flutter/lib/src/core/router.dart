// GoRouter 路由配置
// 包含 8 个路由、响应式 Shell 布局和认证守卫逻辑

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_providers.dart';
import 'constants.dart';
import '../features/about/about_page.dart';
import '../features/admin/admin_page.dart';
import '../features/auth/auth_page.dart';
import '../features/content/content_detail_page.dart';
import '../features/content/content_list_page.dart';
import '../features/friends/friends_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import '../features/auth/oauth_callback_page.dart';

/// 路由 Provider
/// 创建并配置 GoRouter 实例，包含认证守卫
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider); // 监听认证状态变化
  return GoRouter(
    initialLocation: '/', // 初始路由为首页
    refreshListenable: auth, // 认证状态变化时刷新路由
    redirect: (context, state) {
      // 认证守卫：未加载完成时不重定向
      if (!auth.isLoaded) return null;

      final location = state.uri.path;
      final isLogin = location == '/login';
      // OAuth 回调路由不做拦截
      if (location.startsWith('/login/oauth2/')) return null;
      // 受保护的路由：个人中心和管理后台
      final isProtected =
          location.startsWith('/profile') || location.startsWith('/admin');

      // 未登录访问受保护路由 -> 跳转登录页
      if (isProtected && !auth.isAuthenticated) {
        return Uri(
          path: '/login',
          queryParameters: {'from': location}, // 记录来源页面
        ).toString();
      }
      // 非 ADMIN 角色访问管理后台 -> 跳转首页
      if (location.startsWith('/admin') && !(auth.user?.isAdmin ?? false)) {
        return '/';
      }
      // 已登录访问登录页 -> 跳转来源页或个人中心
      if (isLogin && auth.isAuthenticated) {
        return state.uri.queryParameters['from'] ?? '/profile';
      }
      return null; // 无需重定向
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BlogShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/contents',
              builder: (context, state) => const ContentListPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      ContentDetailPage(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/friends',
              builder: (context, state) => const FriendsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/about',
              builder: (context, state) => const AboutPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/login',
              builder: (context, state) => const AuthPage(),
            ),
          ]),
        ],
      ),
      // GitHub OAuth 回调路由（不使用 Shell 布局）
      GoRoute(
        path: '/login/oauth2/code/github',
        builder: (context, state) => OAuthCallbackPage(
          code: state.uri.queryParameters['code'],
          state: state.uri.queryParameters['state'],
          token: state.uri.queryParameters['token'],
          refresh: state.uri.queryParameters['refresh'],
          expires: state.uri.queryParameters['expires'],
        ),
      ),
    ],
  );
});

/// 响应式 Shell 布局组件
/// 使用 StatefulNavigationShell 保持页面状态，避免切换标签时销毁重建
class BlogShell extends ConsumerWidget {
  const BlogShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final nickname = auth.user?.nickname.trim();
    final avatarText =
        nickname == null || nickname.isEmpty ? 'C' : nickname.characters.first;

    // 所有导航目的地配置（与 branches 顺序对应）
    const allDestinations = _destinations;

    // 根据登录状态和角色过滤可见的导航目的地
    final visibleDestinations = allDestinations.where((item) {
      if (item.path == '/profile' && !auth.isAuthenticated) return false;
      if (item.path == '/admin') {
        if (!auth.isAuthenticated || !(auth.user?.isAdmin ?? false)) {
          return false;
        }
      }
      if (item.path == '/login' && auth.isAuthenticated) return false;
      return true;
    }).toList();

    // 计算当前选中的导航索引（在过滤后的列表中）
    final currentPath = allDestinations[navigationShell.currentIndex].path;
    int selectedIndex = visibleDestinations.indexWhere(
      (d) => d.path == currentPath,
    );
    if (selectedIndex < 0) selectedIndex = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideBreakpoint;

        // 宽屏布局：左侧 NavigationRail
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      _onNavigate(visibleDestinations, index),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundImage: auth.user?.avatarUrl != null
                          ? NetworkImage(auth.user!.avatarUrl!)
                          : null,
                      child: auth.user?.avatarUrl == null
                          ? Text(avatarText)
                          : null,
                    ),
                  ),
                  destinations: [
                    for (final item in visibleDestinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        // 窄屏布局：底部 NavigationBar
        final navItems = visibleDestinations.take(5).toList();
        final navSelectedIndex =
            selectedIndex > navItems.length - 1 ? 0 : selectedIndex;
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navSelectedIndex,
            onDestinationSelected: (index) =>
                _onNavigate(navItems, index),
            destinations: [
              for (final item in navItems)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
            ],
          ),
        );
      },
    );
  }

  /// 导航到指定目的地
  void _onNavigate(List<_Destination> destinations, int index) {
    final destination = destinations[index];
    final branchIndex = _destinations.indexOf(destination);
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }
}

/// 导航目的地数据模型
class _Destination {
  const _Destination(this.path, this.label, this.icon, this.selectedIcon);

  final String path; // 路由路径
  final String label; // 导航标签文本
  final IconData icon; // 未选中图标
  final IconData selectedIcon; // 选中图标
}

/// 所有导航目的地配置列表
const _destinations = <_Destination>[
  _Destination('/', '推荐', Icons.auto_awesome_outlined, Icons.auto_awesome),
  _Destination('/contents', '全部', Icons.article_outlined, Icons.article),
  _Destination('/friends', '朋友', Icons.people_outline, Icons.people),
  _Destination('/about', '关于我', Icons.smart_toy_outlined, Icons.smart_toy),
  _Destination('/profile', '我的', Icons.person_outline, Icons.person),
  _Destination(
    '/admin',
    '管理',
    Icons.admin_panel_settings_outlined,
    Icons.admin_panel_settings,
  ),
  _Destination('/login', '登录', Icons.login_outlined, Icons.login),
];
