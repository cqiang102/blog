// 认证相关 API
// 包含登录、注册、刷新令牌、OAuth 等

import '../models.dart';
import 'api_client_base.dart';

/// 认证相关 API Mixin
mixin AuthApi on ApiClientBase {
  /// 获取 GitHub 绑定授权 URL（已登录用户绑定用）
  Future<String> fetchGithubBindUrl(String accessToken) async {
    final data = await get('/auth/github/bind', accessToken: accessToken);
    return (data as Map<String, dynamic>)['url'] as String;
  }

  /// 获取 OAuth 提供者信息
  Future<Map<String, dynamic>> fetchProviders() async {
    final data = await get('/auth/providers');
    return (data as Map).cast<String, dynamic>();
  }

  /// GitHub OAuth 回调：用授权码换取 JWT 令牌
  Future<AuthSession> githubOAuthCallback({
    required String code,
    String? state,
  }) async {
    final data = await send(
      'POST',
      '/auth/github/callback',
      queryParameters: {
        'code': code,
        if (state != null) 'state': state,
      },
    );
    return AuthSession.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 用户登录
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 用户注册
  Future<AuthSession> register({
    required String email,
    required String password,
    required String nickname,
    required String code,
  }) async {
    final data = await post(
      '/auth/register',
      body: {'email': email, 'password': password, 'nickname': nickname, 'code': code},
    );
    return AuthSession.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 发送邮箱验证码
  Future<void> sendVerificationCode(String email) async {
    await post('/auth/send-code', body: {'email': email});
  }

  /// 刷新访问令牌
  Future<AuthSession> refreshAccessToken(String refreshToken) async {
    final data = await post(
      '/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    return AuthSession.fromJson((data as Map).cast<String, dynamic>());
  }
}
