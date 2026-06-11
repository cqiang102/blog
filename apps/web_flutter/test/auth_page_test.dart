import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/theme.dart';
import 'package:personal_blog_web/src/features/auth/auth_page.dart';

void main() {
  Future<void> pumpAuthPage(WidgetTester tester, {required Size size}) async {
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders mobile login layout', (tester) async {
    await pumpAuthPage(tester, size: const Size(390, 844));

    expect(find.text('沐凉·日记'), findsOneWidget);
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
