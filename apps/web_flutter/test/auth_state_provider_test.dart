import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'auth provider bridges controller notifications without legacy API',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth.refreshToken': 'legacy-token-that-must-be-removed',
      });
      final dio = Dio();
      String? requestedPath;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedPath = options.path;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': null},
              ),
            );
          },
        ),
      );
      final api = BlogApiClient(dio: dio, baseUrl: 'http://test/api/v1');
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      var notifications = 0;
      final subscription = container.listen(
        authControllerProvider,
        (_, _) => notifications++,
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(authControllerProvider);

      await controller.load();
      await controller.logout();

      expect(notifications, greaterThan(1));
      expect(requestedPath, '/auth/logout');
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('auth.refreshToken'), isFalse);
    },
  );
}
