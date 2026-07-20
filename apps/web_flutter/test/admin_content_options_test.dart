import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/auth_controller.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/admin/admin_content_option_picker.dart';
import 'package:personal_blog_web/src/features/admin/tabs/media_admin_tab.dart';
import 'package:personal_blog_web/src/state/state.dart';

class _AuthenticatedController extends AuthController {
  _AuthenticatedController(super.apiClient);

  @override
  String? get accessToken => 'token';

  @override
  Future<String?> getValidAccessToken() async => 'token';
}

class _CancellableContentOptionsApi extends BlogApiClient {
  _CancellableContentOptionsApi()
    : super(dio: Dio(), baseUrl: 'http://admin.test/api/v1');

  final started = Completer<void>();
  final cancelled = Completer<void>();
  CancelToken? requestToken;

  @override
  Future<PageResult<AdminContentOption>> fetchAdminContentOptions({
    required String accessToken,
    required AdminContentOptionsQuery query,
    CancelToken? cancelToken,
  }) async {
    requestToken = cancelToken;
    if (!started.isCompleted) started.complete();
    await cancelToken!.whenCancel;
    if (!cancelled.isCompleted) cancelled.complete();
    throw const ApiException('请求已取消');
  }
}

void main() {
  test(
    'content options API sends search pagination and decodes the light DTO',
    () async {
      late RequestOptions request;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'items': [
                      {'id': 'content-1', 'title': 'Java 生态'},
                    ],
                    'page': 2,
                    'size': 10,
                    'total': 31,
                  },
                },
              ),
            );
          },
        ),
      );
      final api = BlogApiClient(dio: dio, baseUrl: 'http://admin.test/api/v1');

      final page = await api.fetchAdminContentOptions(
        accessToken: 'token',
        query: const AdminContentOptionsQuery(
          query: '  Java  ',
          page: 2,
          size: 10,
        ),
      );

      expect(request.path, '/admin/contents/options');
      expect(request.queryParameters, {
        'query': 'Java',
        'page': '2',
        'size': '10',
      });
      expect(request.headers['Authorization'], 'Bearer token');
      expect(page.page, 2);
      expect(page.total, 31);
      expect(page.items.single.id, 'content-1');
      expect(page.items.single.title, 'Java 生态');
    },
  );

  test(
    'disposing a content option query cancels its in-flight request',
    () async {
      final api = _CancellableContentOptionsApi();
      final auth = _AuthenticatedController(api);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authControllerProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      final subscription = container.listen(
        adminContentOptionsProvider(
          const AdminContentOptionsQuery(query: 'Java', size: 10),
        ),
        (_, _) {},
        fireImmediately: true,
      );
      await api.started.future;

      subscription.close();
      await container.pump();
      await api.cancelled.future.timeout(const Duration(seconds: 1));

      expect(api.requestToken?.isCancelled, isTrue);
    },
  );

  testWidgets('content option picker searches remotely and changes page', (
    tester,
  ) async {
    final queries = <AdminContentOptionsQuery>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminContentOptionsProvider.overrideWith((ref, query) async {
            queries.add(query);
            return PageResult<AdminContentOption>(
              items: [
                AdminContentOption(
                  id: 'content-${query.page}',
                  title: '内容 ${query.page + 1}',
                ),
              ],
              page: query.page,
              size: query.size,
              total: 21,
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AdminContentOptionPicker(value: '', onChanged: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  Java  ');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    expect(queries.last.query, 'Java');
    expect(queries.last.page, 0);

    await tester.tap(find.byTooltip('下一页内容'));
    await tester.pumpAndSettle();

    expect(queries.last.query, 'Java');
    expect(queries.last.page, 1);
  });

  testWidgets('media list does not load content options until a dialog opens', (
    tester,
  ) async {
    var optionLoads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminMediaProvider.overrideWith((ref, query) async {
            return PageResult<AdminMediaItem>(
              items: const [],
              page: query.page,
              size: query.size,
              total: 0,
            );
          }),
          adminContentOptionsProvider.overrideWith((ref, query) async {
            optionLoads += 1;
            return PageResult<AdminContentOption>(
              items: const [],
              page: query.page,
              size: query.size,
              total: 0,
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: AdminMediaTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(optionLoads, 0);
  });
}
