import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/oauth_state_storage.dart';
import '../../../core/api_client.dart';
import '../../../state/state.dart';

typedef OAuthUrlLauncher = Future<bool> Function(Uri uri);

final oauthUrlLauncherProvider = Provider<OAuthUrlLauncher>((ref) {
  return (uri) => launchUrl(uri, webOnlyWindowName: '_self');
});

final authFlowControllerProvider =
    NotifierProvider.autoDispose<AuthFlowController, AuthFlowState>(
      AuthFlowController.new,
    );

class AuthFlowState {
  const AuthFlowState({
    this.isRegister = false,
    this.rememberMe = false,
    this.obscurePassword = true,
    this.countdown = 0,
    this.formError,
  });

  final bool isRegister;
  final bool rememberMe;
  final bool obscurePassword;
  final int countdown;
  final String? formError;

  AuthFlowState copyWith({
    bool? isRegister,
    bool? rememberMe,
    bool? obscurePassword,
    int? countdown,
    String? formError,
    bool clearFormError = false,
  }) {
    return AuthFlowState(
      isRegister: isRegister ?? this.isRegister,
      rememberMe: rememberMe ?? this.rememberMe,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      countdown: countdown ?? this.countdown,
      formError: clearFormError ? null : (formError ?? this.formError),
    );
  }
}

class AuthFlowController extends Notifier<AuthFlowState> {
  static const _savedEmailKey = 'auth.savedEmail';
  static const _rememberMeKey = 'auth.rememberMe';

  Timer? _timer;
  bool _disposed = false;

  @override
  AuthFlowState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    return const AuthFlowState();
  }

  Future<String?> loadSavedEmail() async {
    final preferences = await SharedPreferences.getInstance();
    final rememberMe = preferences.getBool(_rememberMeKey) ?? false;
    if (_disposed || !rememberMe) return null;
    state = state.copyWith(rememberMe: true);
    return preferences.getString(_savedEmailKey);
  }

  void switchMode(bool register) {
    if (state.isRegister == register) return;
    state = state.copyWith(isRegister: register, clearFormError: true);
  }

  void setRememberMe(bool value) {
    state = state.copyWith(rememberMe: value);
  }

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void clearError() {
    state = state.copyWith(clearFormError: true);
  }

  Future<bool> sendCode(String rawEmail) async {
    final email = rawEmail.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setError('请先填写有效的邮箱地址');
      return false;
    }

    try {
      await ref.read(apiClientProvider).sendVerificationCode(email);
      if (_disposed) return false;
      state = state.copyWith(clearFormError: true);
      _startCountdown();
      return true;
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(userFacingErrorMessage(error));
    }
    return false;
  }

  Future<bool> submit({
    required String email,
    required String password,
    required String nickname,
    required String code,
  }) async {
    clearError();
    try {
      final auth = ref.read(authControllerProvider);
      if (state.isRegister) {
        await auth.register(
          email: email,
          password: password,
          nickname: nickname.isEmpty ? email.split('@').first : nickname,
          code: code,
        );
      } else {
        await auth.login(email: email, password: password);
      }
      await _saveCredentials(email);
      return !_disposed;
    } on ApiException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(userFacingErrorMessage(error));
    }
    return false;
  }

  Future<bool> openGithubLogin() async {
    try {
      final data = await ref.read(apiClientProvider).fetchProviders();
      if (_disposed) return false;
      final githubLoginUrl = data['githubLoginUrl'] as String;
      final uri = Uri.parse(githubLoginUrl);
      final oauthState = uri.queryParameters['state'];
      if (oauthState == null || oauthState.isEmpty) {
        throw const ApiException('GitHub 登录状态初始化失败');
      }
      storeOAuthState(oauthState);
      final launched = await ref.read(oauthUrlLauncherProvider)(uri);
      if (!launched) {
        clearOAuthState();
        throw const ApiException('无法打开 GitHub 登录页面');
      }
      return true;
    } catch (error) {
      _setError('获取 GitHub 登录地址失败：${userFacingErrorMessage(error)}');
      return false;
    }
  }

  Future<void> _saveCredentials(String email) async {
    final preferences = await SharedPreferences.getInstance();
    if (state.rememberMe) {
      await preferences.setBool(_rememberMeKey, true);
      await preferences.setString(_savedEmailKey, email.trim());
    } else {
      await preferences.remove(_rememberMeKey);
      await preferences.remove(_savedEmailKey);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    state = state.copyWith(countdown: 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final next = state.countdown - 1;
      state = state.copyWith(countdown: next);
      if (next <= 0) timer.cancel();
    });
  }

  void _setError(String message) {
    if (!_disposed) state = state.copyWith(formError: message);
  }
}
