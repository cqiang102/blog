import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/auth_controller.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/admin/admin_page.dart';
import 'package:personal_blog_web/src/features/admin/admin_tab_registry.dart';
import 'package:personal_blog_web/src/router/app_router.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';
import 'package:personal_blog_web/src/widgets/app_horizontal_tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('admin tab registry', () {
    test('is the single ordered source for every administrator tab', () {
      expect(adminTabs.map((tab) => tab.id), AdminTabId.values);
      expect(adminTabs.map((tab) => tab.id).toSet(), hasLength(11));
      expect(adminTabs.map((tab) => tab.label).toSet(), hasLength(11));
    });

    test('round-trips query deep links and keeps editor routes on content', () {
      for (final tab in adminTabs) {
        expect(adminTabForUri(Uri.parse(tab.location)), tab.id);
        expect(adminTabIndex(tab.id), adminTabs.indexOf(tab));
      }

      expect(
        adminTabForUri(Uri.parse('/admin/contents/new')),
        AdminTabId.content,
      );
      expect(
        adminTabForUri(Uri.parse('/admin/contents/content-1/edit')),
        AdminTabId.content,
      );
      expect(
        adminTabForUri(Uri.parse('/admin?tab=unknown')),
        AdminTabId.overview,
      );
    });
  });

  group('route permission policy', () {
    test('waits for auth restoration before redirecting', () {
      expect(
        appRedirectForAuth(
          uri: Uri.parse('/admin?tab=comments'),
          isLoaded: false,
          isAuthenticated: false,
          isAdmin: null,
        ),
        isNull,
      );
    });

    test('preserves an administrator deep link through login', () {
      final redirect = appRedirectForAuth(
        uri: Uri.parse('/admin?tab=comments'),
        isLoaded: true,
        isAuthenticated: false,
        isAdmin: null,
      );

      expect(
        Uri.parse(redirect!).queryParameters['from'],
        '/admin?tab=comments',
      );
      expect(
        appRedirectForAuth(
          uri: Uri(
            path: '/login',
            queryParameters: {'from': '/admin?tab=comments'},
          ),
          isLoaded: true,
          isAuthenticated: true,
          isAdmin: true,
        ),
        '/admin?tab=comments',
      );
    });

    test('allows only a resolved ADMIN account into admin routes', () {
      expect(
        appRedirectForAuth(
          uri: Uri.parse('/admin?tab=users'),
          isLoaded: true,
          isAuthenticated: true,
          isAdmin: true,
        ),
        isNull,
      );
      expect(
        appRedirectForAuth(
          uri: Uri.parse('/admin?tab=users'),
          isLoaded: true,
          isAuthenticated: true,
          isAdmin: false,
        ),
        '/',
      );
      expect(
        appRedirectForAuth(
          uri: Uri.parse('/admin?tab=users'),
          isLoaded: true,
          isAuthenticated: true,
          isAdmin: null,
        ),
        isNull,
      );
    });

    test('does not accept an external post-login destination', () {
      expect(
        appRedirectForAuth(
          uri: Uri(path: '/login', queryParameters: {'from': '//example.com'}),
          isLoaded: true,
          isAuthenticated: true,
          isAdmin: true,
        ),
        '/profile',
      );
    });
  });

  testWidgets('AdminPage never exposes partial management to a USER', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = BlogApiClient(dio: Dio(), baseUrl: 'http://admin.test/api/v1');
    final auth = AuthController(api);
    addTearDown(auth.dispose);
    await auth.loginWithSession(
      AuthSession(
        accessToken: 'user-token',
        expiresAt: DateTime.utc(2027),
        user: const UserProfile(
          id: 'user-1',
          email: 'user@example.com',
          nickname: 'User',
          role: 'USER',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWithValue(auth)],
        child: MaterialApp(theme: buildAppTheme(), home: const AdminPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前账号没有管理员权限'), findsOneWidget);
    expect(find.byType(AppHorizontalTabs), findsNothing);
    expect(find.text('概览'), findsNothing);
  });
}
