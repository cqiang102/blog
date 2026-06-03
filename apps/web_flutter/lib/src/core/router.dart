/// GoRouter 路由配置
/// 包含 8 个路由、响应式 Shell 布局和认证守卫逻辑
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_providers.dart';
import '../features/about/about_page.dart';
import '../features/admin/admin_page.dart';
import '../features/auth/auth_page.dart';
import '../features/content/content_detail_page.dart';
import '../features/content/content_list_page.dart';
import '../features/friends/friends_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';

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
      // 已登录访问登录页 -> 跳转来源页或个人中心
      if (isLogin && auth.isAuthenticated) {
        return state.uri.queryParameters['from'] ?? '/profile';
      }
      return null; // 无需重定向
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => BlogShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/contents',
            builder: (context, state) => const ContentListPage(),
          ),
          GoRoute(
            path: '/contents/:id',
            builder:
                (context, state) =>
                    ContentDetailPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/friends',
            builder: (context, state) => const FriendsPage(),
          ),
          GoRoute(
            path: '/about',
            builder: (context, state) => const AboutPage(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const AuthPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminPage(),
          ),
        ],
      ),
    ],
  );
});

/// 响应式 Shell 布局组件
/// 根据屏幕宽度切换 NavigationRail（宽屏）和 NavigationBar（窄屏）
class BlogShell extends ConsumerWidget {
  const BlogShell({required this.child, super.key});

  final Widget child; // 子路由页面内容

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path; // 当前路由路径
    final selectedIndex = _selectedIndex(location); // 当前选中索引
    final auth = ref.watch(authControllerProvider);
    final nickname = auth.user?.nickname.trim();
    // 头像文字：取昵称首字符，默认 'C'
    final avatarText =
        nickname == null || nickname.isEmpty ? 'C' : nickname.characters.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900; // 宽屏阈值 900px

        // 宽屏布局：左侧 NavigationRail
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected:
                      (index) => context.go(_destinations[index].path),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      child: Text(avatarText), // 头像首字母
                    ),
                  ),
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1), // 分隔线
                Expanded(child: child), // 路由内容区域
              ],
            ),
          );
        }

        // 窄屏布局：底部 NavigationBar（只显示前 5 个导航项）
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex > 4 ? 0 : selectedIndex,
            onDestinationSelected:
                (index) => context.go(_destinations[index].path),
            destinations: [
              for (final item in _destinations.take(5))
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

  /// 根据路由路径返回选中的导航索引
  /// [location] 当前路由路径
  /// 返回值：导航项索引
  int _selectedIndex(String location) {
    if (location.startsWith('/contents')) return 1;
    if (location.startsWith('/friends')) return 2;
    if (location.startsWith('/about')) return 3;
    if (location.startsWith('/profile')) return 4;
    if (location.startsWith('/admin')) return 5;
    if (location.startsWith('/login')) return 6;
    return 0; // 默认首页
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
