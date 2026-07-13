import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/features/content/content_list_page.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';

BlogApiClient _visualTestApi() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final Object data = options.path.endsWith('/tags')
            ? [
                {'name': 'Flutter', 'slug': 'flutter'},
                {'name': '生活', 'slug': 'life'},
                {'name': 'AI', 'slug': 'ai'},
              ]
            : {
                'items': [
                  {
                    'id': 'content-1',
                    'title': '把复杂的状态管理，写成清楚的日常代码',
                    'slug': 'clear-state-management',
                    'type': 'ARTICLE',
                    'status': 'PUBLISHED',
                    'summary': '从页面状态、异步边界到可测试的交互，记录一次 Flutter 重构。',
                    'pinned': true,
                    'likeCount': 128,
                    'publishedAt': '2026-07-08T08:00:00Z',
                    'tags': ['Flutter', '架构'],
                  },
                  {
                    'id': 'content-2',
                    'title': '雨后的傍晚，适合慢慢走回家',
                    'slug': 'walk-home-after-rain',
                    'type': 'IMAGE',
                    'status': 'PUBLISHED',
                    'summary': '城市安静下来以后，路灯、树影和潮湿的风。',
                    'pinned': false,
                    'likeCount': 42,
                    'publishedAt': '2026-07-03T10:00:00Z',
                    'tags': ['生活'],
                  },
                  {
                    'id': 'content-3',
                    'title': '让 AI 助手真正理解个人知识库',
                    'slug': 'personal-ai-knowledge',
                    'type': 'ARTICLE',
                    'status': 'PUBLISHED',
                    'summary': '检索、上下文与回答质量之间，需要哪些可靠的工程约束。',
                    'pinned': false,
                    'likeCount': 86,
                    'publishedAt': '2026-06-21T06:00:00Z',
                    'tags': ['AI', '架构'],
                  },
                ],
                'page': 0,
                'size': 20,
                'total': 3,
              };
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
  return BlogApiClient(dio: dio, baseUrl: 'http://visual.test/api/v1');
}

Future<void> _pumpContentList(
  WidgetTester tester,
  Size size, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(_visualTestApi())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark
            ? buildDarkAppTheme()
            : buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: const Scaffold(body: ContentListPage()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  final viewports = <String, Size>{
    '390': const Size(390, 844),
    '768': const Size(768, 1024),
    '1440': const Size(1440, 1000),
  };

  for (final entry in viewports.entries) {
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('content list $mode visual regression at ${entry.key}px', (
        tester,
      ) async {
        await _pumpContentList(tester, entry.value, brightness: brightness);

        expect(
          find.byType(ContentListPage),
          matchesGoldenFile(
            brightness == Brightness.dark
                ? 'goldens/content_list_dark_${entry.key}.png'
                : 'goldens/content_list_${entry.key}.png',
          ),
        );
      });
    }
  }
}
