import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/auth_controller.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
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
      profileLikesProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(profileLikesProvider.notifier);

    await controller.loadMore();
    var state = container.read(profileLikesProvider);
    expect(state.items.single.title, 'Architecture Notes');
    expect(state.hasMore, isFalse);

    expect(await controller.delete(state.items.single), isNull);
    state = container.read(profileLikesProvider);
    expect(state.items, isEmpty);
    expect(state.total, 0);
    expect(requestedPaths, ['GET /me/likes', 'DELETE /me/likes/activity-1']);
  });
}
