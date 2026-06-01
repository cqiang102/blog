import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_blog_web/src/core/app.dart';

void main() {
  testWidgets('renders blog app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BlogApp()));
    await tester.pump();

    expect(find.text('个人博客'), findsOneWidget);
  });
}
