import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/features/auth/application/auth_flow_controller.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores remembered email and owns form display state', () async {
    SharedPreferences.setMockInitialValues({
      'auth.rememberMe': true,
      'auth.savedEmail': 'reader@example.com',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      authFlowControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(authFlowControllerProvider.notifier);

    expect(await controller.loadSavedEmail(), 'reader@example.com');
    expect(container.read(authFlowControllerProvider).rememberMe, isTrue);

    controller.switchMode(true);
    controller.setRememberMe(false);
    controller.togglePasswordVisibility();

    final state = container.read(authFlowControllerProvider);
    expect(state.isRegister, isTrue);
    expect(state.rememberMe, isFalse);
    expect(state.obscurePassword, isFalse);
  });

  test('validates email before requesting a verification code', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      authFlowControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final sent = await container
        .read(authFlowControllerProvider.notifier)
        .sendCode('not-an-email');

    expect(sent, isFalse);
    expect(container.read(authFlowControllerProvider).formError, '请先填写有效的邮箱地址');
  });

  test('starts countdown after verification code is accepted', () async {
    SharedPreferences.setMockInitialValues({});
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
    final subscription = container.listen(
      authFlowControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final sent = await container
        .read(authFlowControllerProvider.notifier)
        .sendCode('reader@example.com');

    expect(sent, isTrue);
    expect(requestedPath, '/auth/send-code');
    expect(container.read(authFlowControllerProvider).countdown, 60);
    expect(container.read(authFlowControllerProvider).formError, isNull);
  });
}
