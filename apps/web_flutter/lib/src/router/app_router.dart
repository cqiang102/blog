// GoRouter 路由配置

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/state.dart';
import 'app_shell.dart';
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
