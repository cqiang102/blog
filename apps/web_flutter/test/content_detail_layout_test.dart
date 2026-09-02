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

BlogApiClient _invalidVideoDetailTestApi() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final Object? data;
        if (options.method == 'POST' && options.path.endsWith('/views')) {
          data = <String, Object?>{};
        } else if (options.path.endsWith('/comments')) {
          data = {'items': <Object?>[], 'page': 0, 'size': 20, 'total': 0};
        } else {
          data = {
            'id': 'video-1',
            'title': '无效视频地址',
            'slug': 'invalid-video',
            'type': 'VIDEO',
            'status': 'PUBLISHED',
            'summary': '',
            'coverUrl': '',
            'tags': <String>[],
            'pinned': false,
            'likeCount': 0,
            'viewCount': 0,
            'commentCount': 0,
            'likedByCurrentUser': false,
            'publishedAt': '2026-07-10T08:00:00Z',
            'bodyMarkdown': '',
            'mediaAssets': [
              {'publicUrl': 'relative-video.mp4'},
            ],
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

double _backToTopOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.byKey(const ValueKey('detail-back-to-top-fade')),
      )
      .opacity;
}

BlogApiClient _tocDetailTestApi() {
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
            'id': 'toc-content-1',
            'title': '长文目录与回到顶部测试',
            'slug': 'toc-test',
            'type': 'ARTICLE',
            'status': 'PUBLISHED',
            'summary': '',
            'coverUrl': '',
            'tags': <String>[],
            'pinned': false,
            'likeCount': 0,
            'viewCount': 0,
            'commentCount': 0,
            'likedByCurrentUser': false,
            'publishedAt': '2026-07-10T08:00:00Z',
            'bodyMarkdown': _longArticleMarkdown(),
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

String _longArticleMarkdown() {
  final buffer = StringBuffer('''
# 开头总览

这是文章的开头段落，用来撑起足够的高度以便测试滚动时的目录与回到顶部按钮。

''');
  for (var i = 0; i < 24; i++) {
    buffer.writeln('这是第 $i 段正文内容，用于让文章变得足够长，从而可以向下滚动。');
  }
  buffer.writeln('''
## 第一节 背景介绍

这里介绍背景，包含若干段落用于排版。

### 1.1 现状与问题

这里说明当前遇到的问题和思考过程。

## 第二节 实现细节

实现部分包含更长的说明文字，用来验证点击目录后能够正确跳转。

### 2.1 关键代码

代码前后的说明文字。

## 第三节 总结

这里是文章总结段落。
''');
  for (var i = 0; i < 16; i++) {
    buffer.writeln('结尾补充段落 $i，让评论区上方保留足够滚动距离。');
  }
  return buffer.toString();
}

Future<void> _pumpDetailApi(
  WidgetTester tester,
  Size size,
  BlogApiClient api,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ContentDetailPage(id: 'toc-content-1')),
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

  testWidgets('video viewer rejects a relative non-API media URL safely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_invalidVideoDetailTestApi()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: ContentDetailPage(id: 'video-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('视频加载失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('article shows toc and back-to-top after scrolling', (
    tester,
  ) async {
    await _pumpDetailApi(tester, const Size(1440, 1000), _tocDetailTestApi());

    expect(find.text('目录'), findsNothing);
    expect(_backToTopOpacity(tester), 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(find.text('目录'), findsOneWidget);
    expect(_backToTopOpacity(tester), 1);

    // 目录应位于正文左侧，且不与右下角回到顶部重叠。
    expect(
      tester.getTopLeft(find.text('目录')).dx,
      lessThan(tester.getTopLeft(find.byType(MarkdownBody)).dx),
    );

    // 点击目录应跳到对应小节。
    await tester.tap(find.widgetWithText(TextButton, '第三节 总结'));
    await tester.pumpAndSettle();
    final heading = find.descendant(
      of: find.byType(MarkdownBody),
      matching: find.text('第三节 总结'),
    );
    expect(heading, findsOneWidget);
    final headingTop = tester.getTopLeft(heading).dy;
    expect(headingTop, greaterThanOrEqualTo(0));
    expect(headingTop, lessThan(900));

    // 回到顶部后目录与按钮都应收起。
    await tester.tap(find.byTooltip('回到顶部'));
    await tester.pumpAndSettle();
    expect(find.text('目录'), findsNothing);
    expect(_backToTopOpacity(tester), 0);
  });

  testWidgets('back-to-top works on narrow screens without toc', (
    tester,
  ) async {
    await _pumpDetailApi(tester, const Size(900, 900), _tocDetailTestApi());

    expect(_backToTopOpacity(tester), 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(find.text('目录'), findsNothing);
    expect(_backToTopOpacity(tester), 1);

    await tester.tap(find.byTooltip('回到顶部'));
    await tester.pumpAndSettle();
    expect(_backToTopOpacity(tester), 0); // 常驻树内，仅透明隐藏
    expect(tester.takeException(), isNull);
  });
}
