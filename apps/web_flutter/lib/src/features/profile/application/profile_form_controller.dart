import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/oauth_state_storage.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../core/models.dart';
import '../../../state/state.dart';

typedef ProfileOAuthLauncher = Future<bool> Function(Uri uri);

final profileOAuthLauncherProvider = Provider<ProfileOAuthLauncher>((ref) {
  return (uri) => launchUrl(uri, webOnlyWindowName: '_self');
});

final profileFormControllerProvider =
    NotifierProvider.autoDispose<ProfileFormController, ProfileFormState>(
      ProfileFormController.new,
    );

class ProfileFormState {
  const ProfileFormState({
    this.oauthAccounts = const [],
    this.isLoadingOAuth = false,
    this.isUploadingAvatar = false,
    this.isChangingPassword = false,
    this.avatarUrl,
  });

  final List<OAuthAccountInfo> oauthAccounts;
  final bool isLoadingOAuth;
  final bool isUploadingAvatar;
  final bool isChangingPassword;
  final String? avatarUrl;

  bool get hasGithub =>
      oauthAccounts.any((account) => account.provider == 'GITHUB');

  ProfileFormState copyWith({
    List<OAuthAccountInfo>? oauthAccounts,
    bool? isLoadingOAuth,
    bool? isUploadingAvatar,
    bool? isChangingPassword,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) {
    return ProfileFormState(
      oauthAccounts: oauthAccounts ?? this.oauthAccounts,
      isLoadingOAuth: isLoadingOAuth ?? this.isLoadingOAuth,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      isChangingPassword: isChangingPassword ?? this.isChangingPassword,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    );
  }
}

class ProfileActionResult {
  const ProfileActionResult.success(this.message)
    : isSuccess = true,
      loginRequired = false;
  const ProfileActionResult.failure(this.message)
    : isSuccess = false,
      loginRequired = false;
  const ProfileActionResult.loginRequired()
    : message = '请先登录',
      isSuccess = false,
      loginRequired = true;

  final String message;
  final bool isSuccess;
  final bool loginRequired;
}

class ProfileFormController extends Notifier<ProfileFormState> {
  bool _disposed = false;

  @override
  ProfileFormState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const ProfileFormState();
  }

  void seedAvatar(String? avatarUrl) {
    state = avatarUrl == null
        ? state.copyWith(clearAvatarUrl: true)
        : state.copyWith(avatarUrl: avatarUrl);
  }

  Future<void> loadOAuthAccounts() async {
    if (state.isLoadingOAuth) return;
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    state = state.copyWith(isLoadingOAuth: true);
    try {
      final accounts = await ref
          .read(apiClientProvider)
          .fetchOAuthAccounts(accessToken: token);
      if (!_disposed) state = state.copyWith(oauthAccounts: accounts);
    } finally {
      if (!_disposed) state = state.copyWith(isLoadingOAuth: false);
    }
  }

  Future<String?> bindGithub() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return '请先登录';
    try {
      final githubUrl = await ref
          .read(apiClientProvider)
          .fetchGithubBindUrl(token);
      if (_disposed) return null;
      final uri = Uri.parse(githubUrl);
      final oauthState = uri.queryParameters['state'];
      if (oauthState == null || oauthState.isEmpty) {
        throw const ApiException('GitHub 绑定状态初始化失败');
      }
      storeOAuthState(oauthState);
      final launched = await ref.read(profileOAuthLauncherProvider)(uri);
      if (!launched) {
        clearOAuthState();
        throw const ApiException('无法打开 GitHub 绑定页面');
      }
      return null;
    } catch (error) {
      return '获取绑定地址失败: $error';
    }
  }

  Future<String?> unbindOAuth(String provider) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return '请先登录';
    try {
      await ref
          .read(apiClientProvider)
          .unbindOAuthAccount(accessToken: token, provider: provider);
      await loadOAuthAccounts();
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      return error.toString();
    }
  }

  Future<ProfileActionResult> uploadAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    state = state.copyWith(isUploadingAvatar: true);
    try {
      final token = await ref
          .read(authControllerProvider)
          .getValidAccessToken();
      if (token == null) return const ProfileActionResult.loginRequired();
      final avatarUrl = await ref
          .read(apiClientProvider)
          .uploadAvatar(accessToken: token, bytes: bytes, filename: filename);
      if (!_disposed) state = state.copyWith(avatarUrl: avatarUrl);
      return const ProfileActionResult.success('头像已更新');
    } on ApiException catch (error) {
      return ProfileActionResult.failure(error.message);
    } catch (error) {
      return ProfileActionResult.failure(error.toString());
    } finally {
      if (!_disposed) state = state.copyWith(isUploadingAvatar: false);
    }
  }

  Future<ProfileActionResult> saveProfile({
    required String email,
    required String nickname,
    required String bio,
    required String blogUrl,
  }) async {
    try {
      await ref
          .read(authControllerProvider)
          .updateProfile(
            email: email.trim(),
            nickname: nickname.trim(),
            bio: bio.trim(),
            blogUrl: blogUrl.trim(),
            avatarUrl: state.avatarUrl,
          );
      return const ProfileActionResult.success('已保存');
    } on ApiException catch (error) {
      return ProfileActionResult.failure(error.message);
    } catch (error) {
      return ProfileActionResult.failure(error.toString());
    }
  }

  Future<ProfileActionResult> updatePassword({
    required bool hasPassword,
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (hasPassword && oldPassword.isEmpty) {
      return const ProfileActionResult.failure('请输入当前密码');
    }
    if (newPassword.length < kMinPasswordLength) {
      return const ProfileActionResult.failure('新密码至少$kMinPasswordLength个字符');
    }
    if (newPassword != confirmPassword) {
      return const ProfileActionResult.failure('两次输入的密码不一致');
    }

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return const ProfileActionResult.loginRequired();
    state = state.copyWith(isChangingPassword: true);
    try {
      if (hasPassword) {
        await ref
            .read(apiClientProvider)
            .changePassword(
              accessToken: token,
              oldPassword: oldPassword,
              newPassword: newPassword,
            );
        return const ProfileActionResult.success('密码已修改');
      }
      await ref
          .read(apiClientProvider)
          .setPassword(accessToken: token, newPassword: newPassword);
      await ref.read(authControllerProvider).loadUser();
      return const ProfileActionResult.success('密码已设置');
    } on ApiException catch (error) {
      return ProfileActionResult.failure(error.message);
    } catch (error) {
      return ProfileActionResult.failure(error.toString());
    } finally {
      if (!_disposed) state = state.copyWith(isChangingPassword: false);
    }
  }
}
