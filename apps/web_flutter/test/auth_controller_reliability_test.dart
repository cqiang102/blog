import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/auth_controller.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = UserProfile(
  id: 'user-1',
  email: 'user@example.com',
  nickname: 'User',
  role: 'USER',
);

AuthSession _session(String accessToken, DateTime expiresAt) {
  return AuthSession(
    accessToken: accessToken,
    expiresAt: expiresAt,
    user: _user,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('malformed cached user never blocks auth initialization', () async {
    SharedPreferences.setMockInitialValues({'auth.user': '{not-json'});
    final controller = AuthController(
      BlogApiClient(dio: Dio(), baseUrl: 'http://auth.test/api/v1'),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isLoaded, isTrue);
    expect(controller.isAuthenticated, isFalse);
    expect(controller.user, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('auth.user'), isFalse);
  });

  test('an in-flight refresh cannot restore a logged-out session', () async {
    SharedPreferences.setMockInitialValues({});
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path == '/auth/refresh') {
            refreshStarted.complete();
            await releaseRefresh.future;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'accessToken': 'refreshed-token',
                    'expiresAt': '2027-01-01T00:00:00Z',
                    'user': _user.toJson(),
                  },
                },
              ),
            );
            return;
          }
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
    final controller = AuthController(
      BlogApiClient(dio: dio, baseUrl: 'http://auth.test/api/v1'),
    );
    addTearDown(controller.dispose);
    await controller.loginWithSession(
      _session('expired-token', DateTime.utc(2020)),
    );

    final refresh = controller.getValidAccessToken();
    await refreshStarted.future;
    await controller.logout();
    releaseRefresh.complete();

    expect(await refresh, isNull);
    expect(controller.isAuthenticated, isFalse);
    expect(controller.user, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('auth.accessToken'), isFalse);
    expect(preferences.containsKey('auth.user'), isFalse);
  });
}
