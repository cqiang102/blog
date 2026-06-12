// Widget 测试
// 验证博客应用外壳的基本渲染
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_blog_web/src/core/app.dart';

void main() {
  /// 测试博客应用外壳是否正确渲染
  /// 验证新版首页标题是否显示
  testWidgets('renders blog app shell', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(child: BlogApp()));
      await tester.pump(const Duration(milliseconds: 100));
    });

    expect(find.text('首页'), findsOneWidget);
  });
}
