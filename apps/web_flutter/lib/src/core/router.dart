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

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      if (!auth.isLoaded) return null;

      final location = state.uri.path;
      final isLogin = location == '/login';
      final isProtected =
          location.startsWith('/profile') || location.startsWith('/admin');

      if (isProtected && !auth.isAuthenticated) {
        return Uri(
          path: '/login',
          queryParameters: {'from': location},
        ).toString();
      }
      if (isLogin && auth.isAuthenticated) {
        return state.uri.queryParameters['from'] ?? '/profile';
      }
      return null;
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

class BlogShell extends ConsumerWidget {
  const BlogShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(location);
    final auth = ref.watch(authControllerProvider);
    final nickname = auth.user?.nickname.trim();
    final avatarText =
        nickname == null || nickname.isEmpty ? 'C' : nickname.characters.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

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
                      child: Text(avatarText),
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
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

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

  int _selectedIndex(String location) {
    if (location.startsWith('/contents')) return 1;
    if (location.startsWith('/friends')) return 2;
    if (location.startsWith('/about')) return 3;
    if (location.startsWith('/profile')) return 4;
    if (location.startsWith('/admin')) return 5;
    if (location.startsWith('/login')) return 6;
    return 0;
  }
}

class _Destination {
  const _Destination(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

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
