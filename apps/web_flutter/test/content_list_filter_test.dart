import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/content/content_list_page.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';

class _FilterTestApi {
  final requests = <RequestOptions>[];
  final pending =
      <({RequestOptions options, RequestInterceptorHandler handler})>[];
  bool delayResponses = false;

  late final client = _createClient();

  BlogApiClient _createClient() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/tags')) {
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': [
                    {'name': '生活', 'slug': 'life'},
                    {'name': 'Flutter', 'slug': 'flutter'},
                  ],
                },
              ),
            );
            return;
          }
          requests.add(options);
          if (delayResponses) {
            pending.add((options: options, handler: handler));
          } else {
            respond(options, handler);
          }
        },
      ),
    );
    return BlogApiClient(dio: dio, baseUrl: 'http://test/api/v1');
  }

  void respond(RequestOptions options, RequestInterceptorHandler handler) {
    final isImage = options.queryParameters['type'] == 'IMAGE';
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'data': {
            'items': [
              {
                'id': isImage ? 'photo' : 'article',
                'title': isImage ? '筛选后的照片' : '默认文章',
                'type': isImage ? 'IMAGE' : 'ARTICLE',
                'summary': '内容筛选回归测试',
                'publishedAt': '2026-06-05T08:00:00Z',
                'tags': <String>[],
              },
            ],
            'page': int.parse(options.queryParameters['page'] as String),
            'size': 20,
            'total': 1,
          },
        },
      ),
    );
  }
}

Future<ProviderContainer> _pumpList(
  WidgetTester tester,
  _FilterTestApi api, {
  DateTime? startDate,
  DateTime? endDate,
}) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer.test(
    overrides: [apiClientProvider.overrideWithValue(api.client)],
  );
  addTearDown(container.dispose);
  final filters = container.read(contentFilterProvider.notifier);
  filters.updateStartDate(startDate);
  filters.updateEndDate(endDate);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ContentListPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('展开筛选'));
  await tester.pumpAndSettle();
  return container;
}

Finder _typeChip(String label) => find.widgetWithText(ChoiceChip, label);
Finder _tagChip(String label) => find.widgetWithText(FilterChip, label);

void main() {
  testWidgets('combines search, type and tag, then clears the query', (
    tester,
  ) async {
    final api = _FilterTestApi();
    final container = await _pumpList(tester, api);

    await tester.enterText(find.byType(TextField), '  Flutter  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(_typeChip('图片'));
    await tester.pumpAndSettle();
    await tester.tap(_tagChip('生活'));
    await tester.pumpAndSettle();

    expect(api.requests.last.queryParameters, {
      'query': 'Flutter',
      'type': 'IMAGE',
      'tag': 'life',
      'page': '0',
      'size': '20',
    });
    expect(find.text('筛选后的照片'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '清空筛选'));
    await tester.pumpAndSettle();

    expect(container.read(contentFilterProvider), const ContentFilterState());
    expect(api.requests.last.queryParameters, {'page': '0', 'size': '20'});
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text('默认文章'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clicking a selected tag removes it and keeps the type', (
    tester,
  ) async {
    final api = _FilterTestApi();
    final container = await _pumpList(tester, api);
    await tester.tap(_typeChip('图片'));
    await tester.pumpAndSettle();
    await tester.tap(_tagChip('生活'));
    await tester.pumpAndSettle();
    await tester.tap(_tagChip('生活'));
    await tester.pumpAndSettle();

    expect(container.read(contentFilterProvider).tag, isNull);
    expect(container.read(contentFilterProvider).type, ContentType.image);
    expect(api.requests.last.queryParameters.containsKey('tag'), isFalse);
    expect(tester.widget<FilterChip>(_tagChip('全部')).selected, isTrue);
  });

  for (final changeStart in [true, false]) {
    testWidgets(
      'changing ${changeStart ? 'start' : 'end'} date sends one valid range',
      (tester) async {
        final api = _FilterTestApi();
        final container = await _pumpList(
          tester,
          api,
          startDate: DateTime(2026, 6, 5),
          endDate: DateTime(2026, 6, 10),
        );
        final filterChanges = <ContentFilterState>[];
        final subscription = container.listen(
          contentFilterProvider,
          (_, next) => filterChanges.add(next),
        );
        addTearDown(subscription.close);
        api.requests.clear();
        await tester.tap(
          find.widgetWithText(
            ActionChip,
            changeStart ? '2026-06-05' : '2026-06-10',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(changeStart ? '12' : '3'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final filter = container.read(contentFilterProvider);
        expect(filter.startDate, changeStart ? DateTime(2026, 6, 12) : null);
        expect(filter.endDate, changeStart ? null : DateTime(2026, 6, 3));
        expect(filterChanges, hasLength(1));
        expect(api.requests, hasLength(1));
        expect(
          api.requests.single.queryParameters.containsKey(
            changeStart ? 'to' : 'from',
          ),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reselecting all does not reload unchanged filters', (
    tester,
  ) async {
    final api = _FilterTestApi();
    await _pumpList(tester, api);
    api.requests.clear();
    await tester.tap(_typeChip('全部'));
    await tester.pumpAndSettle();
    expect(api.requests, isEmpty);
  });

  testWidgets(
    'scrolling an exhausted filtered list does not request another page',
    (tester) async {
      final api = _FilterTestApi();
      await _pumpList(tester, api);
      await tester.tap(_typeChip('图片'));
      await tester.pumpAndSettle();
      api.requests.clear();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(api.requests, isEmpty);
      expect(find.text('筛选后的照片'), findsOneWidget);
    },
  );

  testWidgets(
    'late responses from old filters do not replace the current list',
    (tester) async {
      final api = _FilterTestApi();
      await _pumpList(tester, api);
      api.delayResponses = true;
      await tester.tap(_typeChip('文章'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_typeChip('图片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.pending, hasLength(2));

      final latest = api.pending.last;
      api.respond(latest.options, latest.handler);
      await tester.pumpAndSettle();
      final older = api.pending.first;
      api.respond(older.options, older.handler);
      await tester.pumpAndSettle();

      expect(find.text('筛选后的照片'), findsOneWidget);
      expect(find.text('默认文章'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'multiple filter changes in one frame load only the final query',
    (tester) async {
      final api = _FilterTestApi();
      await _pumpList(tester, api);
      api.requests.clear();

      await tester.tap(_typeChip('文章'));
      await tester.tap(_typeChip('图片'));
      await tester.pumpAndSettle();

      expect(api.requests, hasLength(1));
      expect(api.requests.single.queryParameters['type'], 'IMAGE');
      expect(find.text('筛选后的照片'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
