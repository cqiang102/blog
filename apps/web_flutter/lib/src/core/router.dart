// GoRouter 路由配置
// 包含 8 个路由、响应式 Shell 布局和认证守卫逻辑

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_providers.dart';
import 'constants.dart';
import 'theme.dart';
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
  // 不使用 ref.watch，避免 auth 状态变化时整个 GoRouter 被重新创建
  // refreshListenable 已经足够触发路由刷新
  final auth = ref.read(authControllerProvider);
  return GoRouter(
    initialLocation: '/', // 初始路由为首页
    refreshListenable: auth, // 认证状态变化时刷新路由
    redirect: (context, state) {
      // 每次重定向时读取最新的 auth 状态
      final currentAuth = ref.read(authControllerProvider);
      // 认证守卫：未加载完成时不重定向
      if (!currentAuth.isLoaded) return null;

      final location = state.uri.path;
      final isLogin = location == '/login';
      // OAuth 回调路由不做拦截
      if (location.startsWith('/login/oauth2/')) return null;
      // 受保护的路由：个人中心和管理后台
      final isProtected =
          location.startsWith('/profile') || location.startsWith('/admin');

      // 未登录访问受保护路由 -> 跳转登录页
      if (isProtected && !currentAuth.isAuthenticated) {
        return Uri(
          path: '/login',
          queryParameters: {'from': location}, // 记录来源页面
        ).toString();
      }
      // 非 ADMIN 角色访问管理后台 -> 跳转首页
      if (location.startsWith('/admin') &&
          !(currentAuth.user?.isAdmin ?? false)) {
        return '/';
      }
      // 已登录访问登录页 -> 跳转来源页或个人中心
      if (isLogin && currentAuth.isAuthenticated) {
        return state.uri.queryParameters['from'] ?? '/profile';
      }
      return null; // 无需重定向
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                BlogShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const HomePage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contents',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const ContentListPage(),
                    ),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder:
                        (context, state) => NoTransitionPage(
                          key: state.pageKey,
                          child: ContentDetailPage(
                            id: state.pathParameters['id']!,
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/friends',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const FriendsPage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/about',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const AboutPage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const ProfilePage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const AdminPage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/login',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const AuthPage(),
                    ),
              ),
            ],
          ),
        ],
      ),
      // GitHub OAuth 回调路由（不使用 Shell 布局）
      GoRoute(
        path: '/login/oauth2/code/github',
        builder:
            (context, state) => OAuthCallbackPage(
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
class BlogShell extends ConsumerStatefulWidget {
  const BlogShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<BlogShell> createState() => _BlogShellState();
}

class _BlogShellState extends ConsumerState<BlogShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prewarmPublicData().catchError((_) {}));
    });
  }

  Future<void> _prewarmPublicData() async {
    final query = ref.read(contentFilterProvider).toQuery();
    final pagination = ref.read(contentPaginationProvider(query));
    if (pagination.items.isEmpty &&
        !pagination.isLoading &&
        pagination.error == null) {
      unawaited(
        ref.read(contentPaginationProvider(query).notifier).resetAndLoad(),
      );
    }

    await Future.wait<Object?>([
      ref.read(recommendationsProvider.future),
      ref.read(friendsProvider.future),
      ref.read(tagsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final nickname = auth.user?.nickname.trim();
    final avatarText =
        nickname == null || nickname.isEmpty ? 'C' : nickname.characters.first;
    final currentPath = _destinations[widget.navigationShell.currentIndex].path;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideBreakpoint;

        if (wide) {
          final expanded = constraints.maxWidth >= kDesktopBreakpoint;
          return Scaffold(
            body: Row(
              children: [
                _BrandSidebar(
                  expanded: expanded,
                  currentPath: currentPath,
                  authenticated: auth.isAuthenticated,
                  isAdmin: auth.user?.isAdmin ?? false,
                  nickname: nickname,
                  avatarText: avatarText,
                  avatarUrl: auth.user?.avatarUrl,
                  onNavigate: _goTo,
                ),
                Expanded(child: widget.navigationShell),
              ],
            ),
          );
        }

        final selectedIndex = _publicDestinations.indexWhere(
          (item) => item.path == currentPath,
        );
        final showBottomNavigation = selectedIndex >= 0;
        return Scaffold(
          body: widget.navigationShell,
          bottomNavigationBar:
              showBottomNavigation
                  ? NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected:
                        (index) => _goTo(_publicDestinations[index]),
                    destinations: [
                      for (final item in _publicDestinations)
                        NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                        ),
                    ],
                  )
                  : null,
        );
      },
    );
  }

  void _goTo(_Destination destination) {
    final branchIndex = _destinations.indexOf(destination);
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }
}

class _BrandSidebar extends StatelessWidget {
  const _BrandSidebar({
    required this.expanded,
    required this.currentPath,
    required this.authenticated,
    required this.isAdmin,
    required this.avatarText,
    required this.onNavigate,
    this.nickname,
    this.avatarUrl,
  });

  final bool expanded;
  final String currentPath;
  final bool authenticated;
  final bool isAdmin;
  final String? nickname;
  final String avatarText;
  final String? avatarUrl;
  final ValueChanged<_Destination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accountItems = [
      if (authenticated) _destinations[4],
      if (isAdmin) _destinations[5],
      if (!authenticated) _destinations[6],
    ];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: expanded ? 232 : 88,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
            border: Border(right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? AppSpacing.md : AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              child: Column(
                children: [
                  _SidebarIdentity(
                    expanded: expanded,
                    avatarText: avatarText,
                    avatarUrl: avatarUrl,
                    nickname: nickname,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final item in _publicDestinations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _SidebarItem(
                        item: item,
                        expanded: expanded,
                        selected: currentPath == item.path,
                        onTap: () => onNavigate(item),
                      ),
                    ),
                  const Spacer(),
                  Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final item in accountItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: item == _destinations[6]
                          ? _SidebarCapsuleButton(
                              item: item,
                              expanded: expanded,
                              onTap: () => onNavigate(item),
                            )
                          : _SidebarItem(
                              item: item,
                              expanded: expanded,
                              selected: currentPath == item.path,
                              onTap: () => onNavigate(item),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarIdentity extends StatelessWidget {
  const _SidebarIdentity({
    required this.expanded,
    required this.avatarText,
    this.avatarUrl,
    this.nickname,
  });

  final bool expanded;
  final String avatarText;
  final String? avatarUrl;
  final String? nickname;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      backgroundImage:
          avatarUrl == null || avatarUrl!.isEmpty
              ? null
              : NetworkImage(avatarUrl!),
      child:
          avatarUrl == null || avatarUrl!.isEmpty
              ? Text(
                avatarText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
              : null,
    );

    if (!expanded) {
      return Tooltip(message: '沐凉·日记', child: avatar);
    }

    return Row(
      children: [
        avatar,
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('沐凉·日记', style: Theme.of(context).textTheme.titleMedium),
              Text(
                nickname?.isNotEmpty == true ? nickname! : '写代码，也记录生活',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final _Destination item;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 浅绿色选中效果
    final selectedBg = const Color(0xFF27665A).withValues(alpha: 0.1);
    final selectedFg = const Color(0xFF27665A);
    final foreground = selected ? selectedFg : scheme.onSurfaceVariant;

    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(selected ? item.selectedIcon : item.icon, size: 22, color: foreground),
            if (expanded) ...[
              const SizedBox(width: 14),
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return expanded ? child : Tooltip(message: item.label, child: child);
  }
}

class _SidebarCapsuleButton extends StatelessWidget {
  const _SidebarCapsuleButton({
    required this.item,
    required this.expanded,
    required this.onTap,
  });

  final _Destination item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final child = Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 22, color: scheme.onPrimary),
              if (expanded) ...[
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return expanded ? child : Tooltip(message: item.label, child: child);
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
const _recommendDestination = _Destination(
  '/',
  '推荐',
  Icons.home_outlined,
  Icons.home_rounded,
);
const _contentsDestination = _Destination(
  '/contents',
  '全部',
  Icons.menu_book_outlined,
  Icons.menu_book_rounded,
);
const _friendsDestination = _Destination(
  '/friends',
  '朋友',
  Icons.link_outlined,
  Icons.link_rounded,
);
const _aboutDestination = _Destination(
  '/about',
  '关于我',
  Icons.account_circle_outlined,
  Icons.account_circle_rounded,
);
const _profileDestination = _Destination(
  '/profile',
  '我的',
  Icons.person_outline_rounded,
  Icons.person_rounded,
);
const _adminDestination = _Destination(
  '/admin',
  '管理',
  Icons.admin_panel_settings_outlined,
  Icons.admin_panel_settings,
);
const _loginDestination = _Destination(
  '/login',
  '登录',
  Icons.login_outlined,
  Icons.login,
);

const _destinations = <_Destination>[
  _recommendDestination,
  _contentsDestination,
  _friendsDestination,
  _aboutDestination,
  _profileDestination,
  _adminDestination,
  _loginDestination,
];

const _publicDestinations = <_Destination>[
  _recommendDestination,
  _contentsDestination,
  _friendsDestination,
  _aboutDestination,
];
