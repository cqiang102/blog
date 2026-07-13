import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/features/content/content_detail_page.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';

BlogApiClient _detailTestApi() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Object? data;
        if (options.method == 'POST' && options.path.endsWith('/views')) {
          data = <String, Object?>{};
        } else if (options.path.endsWith('/comments')) {
          data = {'items': <Object?>[], 'page': 0, 'size': 20, 'total': 0};
        } else {
          data = {
            'id': 'content-1',
            'title': '把复杂的界面写成安静的阅读体验',
            'slug': 'calm-reading-experience',
            'type': 'ARTICLE',
            'status': 'PUBLISHED',
            'summary': '用稳定的内容宽度、清楚的字阶和克制的动效，让读者把注意力放回文章。',
            'coverUrl': '',
            'tags': ['Flutter', '设计'],
            'pinned': true,
            'likeCount': 12,
            'viewCount': 128,
            'commentCount': 0,
            'likedByCurrentUser': false,
            'publishedAt': '2026-07-10T08:00:00Z',
            'bodyMarkdown': '# 阅读是一种节奏\n\n正文需要舒适的行宽和足够的留白。',
            'mediaAssets': <Object?>[],
          };
        }
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': data},
          ),
        );
      },
    ),
  );
  return BlogApiClient(dio: dio, baseUrl: 'http://detail.test/api/v1');
}

Future<void> _pumpDetail(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(_detailTestApi())],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ContentDetailPage(id: 'content-1')),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('article stays readable on a desktop viewport', (tester) async {
    await _pumpDetail(tester, const Size(1440, 1000));

    expect(find.text('约 1 分钟'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(
      tester.getSize(find.byType(MarkdownBody)).width,
      lessThanOrEqualTo(760),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('article does not overflow on a mobile viewport', (tester) async {
    await _pumpDetail(tester, const Size(390, 844));

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(tester.getSize(find.byType(MarkdownBody)).width, lessThan(390));
    expect(tester.takeException(), isNull);
  });
}
