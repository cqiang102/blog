import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';
import 'package:personal_blog_web/src/features/auth/auth_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpAuthPage(WidgetTester tester, {required Size size}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: AuthPage()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('renders desktop login layout', (tester) async {
    await pumpAuthPage(tester, size: const Size(1280, 720));

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('使用 GitHub 登录'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-card'))),
      const Size(1000, 600),
    );
    final formWidth = tester
        .getSize(find.byKey(const ValueKey('auth-form')))
        .width;
    expect(formWidth, inInclusiveRange(392, 400));
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-mode-switch'))).height,
      48,
    );
    for (final key in ['auth-email-field', 'auth-password-field']) {
      final height = tester.getSize(find.byKey(ValueKey(key))).height;
      expect(height, inInclusiveRange(48, 52));
    }
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(AuthPage),
      matchesGoldenFile('goldens/auth_login_1280.png'),
    );
  });

  testWidgets('renders mobile login layout', (tester) async {
    await pumpAuthPage(tester, size: const Size(390, 844));

    expect(find.text('沐凉·日记'), findsOneWidget);
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('auth-form'))).width, 342);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(AuthPage),
      matchesGoldenFile('goldens/auth_login_390.png'),
    );
  });

  testWidgets('registration mode grows without changing the form width', (
    tester,
  ) async {
    await pumpAuthPage(tester, size: const Size(1280, 720));

    await tester.tap(find.text('注册'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('auth-card'))),
      const Size(1000, 680),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-form'))).width,
      inInclusiveRange(392, 400),
    );
    expect(find.byKey(const ValueKey('auth-nickname-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(AuthPage),
      matchesGoldenFile('goldens/auth_register_1280.png'),
    );
  });
}
