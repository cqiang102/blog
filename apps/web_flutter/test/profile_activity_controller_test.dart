import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/auth_controller.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/profile/application/profile_activity_controller.dart';
import 'package:personal_blog_web/src/state/state.dart';

class _AuthenticatedController extends AuthController {
  _AuthenticatedController(super.apiClient);

  @override
  String? get accessToken => 'test-token';
}

void main() {
  test('loads and deletes a profile activity through its controller', () async {
    final dio = Dio();
    final requestedPaths = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedPaths.add('${options.method} ${options.path}');
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: options.method == 'DELETE'
                  ? {'success': true, 'data': null}
                  : {
                      'success': true,
                      'data': {
                        'items': [
                          {
                            'id': 'activity-1',
                            'type': 'LIKE',
                            'contentId': 'content-1',
                            'title': 'Architecture Notes',
                            'createdAt': '2026-07-13T10:00:00Z',
                          },
                        ],
                        'page': 0,
                        'size': 20,
                        'total': 1,
                      },
                    },
            ),
          );
        },
      ),
    );
    final api = BlogApiClient(dio: dio, baseUrl: 'http://test/api/v1');
    final auth = _AuthenticatedController(api);
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      profileActivityProvider(ProfileActivityType.likes),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final provider = profileActivityProvider(ProfileActivityType.likes);
    final controller = container.read(provider.notifier);

    await controller.loadMore();
    var state = container.read(provider);
    expect(state.items.single.title, 'Architecture Notes');
    expect(state.hasMore, isFalse);

    expect(await controller.delete(state.items.single), isNull);
    state = container.read(provider);
    expect(state.items, isEmpty);
    expect(state.total, 0);
    expect(requestedPaths, ['GET /me/likes', 'DELETE /me/likes/activity-1']);
  });

  test(
    'a stale page response cannot restore an activity deleted in flight',
    () async {
      final getStarted = Completer<void>();
      final releaseGet = Completer<void>();
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.method == 'GET') {
              getStarted.complete();
              await releaseGet.future;
            }
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: options.method == 'DELETE'
                    ? {'success': true, 'data': null}
                    : {
                        'success': true,
                        'data': {
                          'items': [
                            {
                              'id': 'activity-1',
                              'type': 'LIKE',
                              'contentId': 'content-1',
                              'title': 'Stale activity',
                              'createdAt': '2026-07-13T10:00:00Z',
                            },
                          ],
                          'page': 0,
                          'size': 20,
                          'total': 1,
                        },
                      },
              ),
            );
          },
        ),
      );
      final api = BlogApiClient(dio: dio, baseUrl: 'http://test/api/v1');
      final auth = _AuthenticatedController(api);
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authControllerProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileActivityProvider(ProfileActivityType.likes),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final provider = profileActivityProvider(ProfileActivityType.likes);
      final controller = container.read(provider.notifier);
      final item = UserActivity(
        id: 'activity-1',
        type: 'LIKE',
        contentId: 'content-1',
        title: 'Stale activity',
        createdAt: DateTime.utc(2026, 7, 13, 10),
      );

      final loading = controller.loadMore();
      await getStarted.future;
      expect(await controller.delete(item), isNull);
      expect(container.read(provider).isLoading, isFalse);

      releaseGet.complete();
      await loading;

      final state = container.read(provider);
      expect(state.items, isEmpty);
      expect(state.total, 0);
      expect(state.isLoading, isFalse);
    },
  );
}
