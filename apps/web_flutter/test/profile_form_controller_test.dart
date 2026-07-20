import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/auth_controller.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/features/profile/application/profile_form_controller.dart';
import 'package:personal_blog_web/src/state/state.dart';

class _AuthenticatedController extends AuthController {
  _AuthenticatedController(super.apiClient);

  @override
  String? get accessToken => 'test-token';
}

void main() {
  test(
    'loads OAuth accounts through the profile application controller',
    () async {
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
                data: {
                  'success': true,
                  'data': [
                    {
                      'provider': 'GITHUB',
                      'providerUsername': 'reader',
                      'createdAt': '2026-07-13T10:00:00Z',
                    },
                  ],
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
        profileFormControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(profileFormControllerProvider.notifier)
          .loadOAuthAccounts();

      final state = container.read(profileFormControllerProvider);
      expect(requestedPath, '/me/oauth-accounts');
      expect(state.hasGithub, isTrue);
      expect(state.oauthAccounts.single.providerUsername, 'reader');
      expect(state.isLoadingOAuth, isFalse);
    },
  );

  test('validates password changes before calling the API', () async {
    final dio = Dio();
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
      profileFormControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(profileFormControllerProvider.notifier);

    final missingOldPassword = await controller.updatePassword(
      hasPassword: true,
      oldPassword: '',
      newPassword: 'long-enough-password',
      confirmPassword: 'long-enough-password',
    );
    final mismatchedPassword = await controller.updatePassword(
      hasPassword: false,
      oldPassword: '',
      newPassword: 'long-enough-password',
      confirmPassword: 'different-password',
    );

    expect(missingOldPassword.isSuccess, isFalse);
    expect(missingOldPassword.message, '请输入当前密码');
    expect(mismatchedPassword.isSuccess, isFalse);
    expect(mismatchedPassword.message, '两次输入的密码不一致');
    expect(
      container.read(profileFormControllerProvider).isChangingPassword,
      isFalse,
    );
  });
}
