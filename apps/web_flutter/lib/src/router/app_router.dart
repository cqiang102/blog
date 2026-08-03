// GoRouter 路由配置

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/state.dart';
import 'app_shell.dart';
import '../features/about/about_page.dart';
import '../features/admin/admin_page.dart';
import '../features/admin/admin_tab_registry.dart';
import '../features/admin/content_editor/content_editor_page.dart';
import '../features/auth/auth_page.dart';
import '../features/content/content_detail_page.dart';
import '../features/content/content_list_page.dart';
import '../features/friends/friends_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import '../features/auth/oauth_callback_page.dart';
import 'internal_redirect.dart';

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
      return appRedirectForAuth(
        uri: state.uri,
        isLoaded: currentAuth.isLoaded,
        isAuthenticated: currentAuth.isAuthenticated,
        isAdmin: currentAuth.user?.isAdmin,
      );
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BlogShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => NoTransitionPage(
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
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const ContentListPage(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: ContentDetailPage(id: state.pathParameters['id']!),
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
                pageBuilder: (context, state) => NoTransitionPage(
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
                pageBuilder: (context, state) => NoTransitionPage(
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
                pageBuilder: (context, state) => NoTransitionPage(
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
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: AdminPage(initialTab: adminTabForUri(state.uri)),
                ),
                routes: [
                  GoRoute(
                    path: 'contents/new',
                    builder: (context, state) => const ContentEditorPage(),
                  ),
                  GoRoute(
                    path: 'contents/:id/edit',
                    builder: (context, state) => ContentEditorPage(
                      contentId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/login',
                pageBuilder: (context, state) => NoTransitionPage(
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
        builder: (context, state) => OAuthCallbackPage(
          code: state.uri.queryParameters['code'],
          state: state.uri.queryParameters['state'],
        ),
      ),
      // 404 兜底：未匹配的 URL 重定向到首页
      GoRoute(path: '/:rest(.*)', redirect: (_, _) => '/'),
    ],
  );
});

/// 根据认证快照计算路由重定向。
///
/// [isAdmin] 为 `null` 表示登录用户资料仍在恢复，此时不提前拒绝后台深链接。
String? appRedirectForAuth({
  required Uri uri,
  required bool isLoaded,
  required bool isAuthenticated,
  required bool? isAdmin,
}) {
  if (!isLoaded) return null;

  final location = uri.path;
  if (location.startsWith('/login/oauth2/')) return null;

  final isLogin = location == '/login';
  final isAdminRoute = _isRouteOrDescendant(location, '/admin');
  final isProtected =
      _isRouteOrDescendant(location, '/profile') || isAdminRoute;

  if (isProtected && !isAuthenticated) {
    return Uri(
      path: '/login',
      queryParameters: {'from': uri.toString()},
    ).toString();
  }
  if (isAdminRoute && isAdmin == false) return '/';
  if (isLogin && isAuthenticated) {
    return safeInternalRedirect(uri.queryParameters['from']);
  }
  return null;
}

bool _isRouteOrDescendant(String location, String route) =>
    location == route || location.startsWith('$route/');
