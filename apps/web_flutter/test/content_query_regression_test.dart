import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api/api_client_base.dart';
import 'package:personal_blog_web/src/core/api/content_api.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/core/constants.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/content/content_list_page.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';

class _ContentApiClient extends ApiClientBase with ContentApi {
  _ContentApiClient({required super.dio, required super.baseUrl});
}

void main() {
  test('password policy matches the backend minimum', () {
    expect(kMinPasswordLength, 8);
  });

  test('end date includes the full selected local day', () async {
    final dio = Dio();
    Uri? requestedUri;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedUri = options.uri;
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': <Object?>[],
                  'page': 0,
                  'size': 20,
                  'total': 0,
                },
              },
            ),
          );
        },
      ),
    );
    final client = _ContentApiClient(dio: dio, baseUrl: 'http://test/api/v1');
    final selectedDate = DateTime(2026, 6, 5);

    await client.fetchContents(
      ContentListQuery(endDate: selectedDate, size: 20),
    );

    final expected = DateTime(
      2026,
      6,
      6,
    ).subtract(const Duration(microseconds: 1)).toUtc().toIso8601String();
    expect(requestedUri?.queryParameters['to'], expected);
  });

  testWidgets('mobile content list uses a horizontal month heading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final data = options.path.endsWith('/tags')
              ? <Object?>[]
              : {
                  'items': [
                    {
                      'id': 'content-1',
                      'title': '六月文章',
                      'slug': 'june-post',
                      'type': 'ARTICLE',
                      'status': 'PUBLISHED',
                      'summary': '回归测试',
                      'publishedAt': '2026-06-05T08:00:00Z',
                      'tags': <Object?>[],
                    },
                  ],
                  'page': 0,
                  'size': 20,
                  'total': 1,
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
    final api = BlogApiClient(dio: dio, baseUrl: 'http://test/api/v1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: ContentListPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('2026 年 6 月'), findsOneWidget);
    expect(find.text('1 篇'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
