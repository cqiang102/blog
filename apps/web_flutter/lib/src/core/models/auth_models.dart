// 认证相关数据模型
// 包含用户资料、认证会话、OAuth 账户等

import 'helpers.dart';

/// 用户资料模型
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    required this.role,
    this.avatarUrl,
    this.bio,
    this.blogUrl,
    this.hasPassword = false,
  });

  final String id;
  final String email;
  final String nickname;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final String? blogUrl;
  final bool hasPassword;

  /// 是否为管理员角色
  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  /// 从 JSON 创建实例
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: jsonString(json['id']),
      email: jsonString(json['email']),
      nickname: jsonString(json['nickname']),
      role: jsonString(json['role']).isEmpty ? 'USER' : jsonString(json['role']),
      avatarUrl: jsonNullableString(json['avatarUrl']),
      bio: jsonNullableString(json['bio']),
      blogUrl: jsonNullableString(json['blogUrl']),
      hasPassword: json['hasPassword'] == true,
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'role': role,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'blogUrl': blogUrl,
    };
  }
}

/// 认证会话模型
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final UserProfile user;

  /// 从 JSON 创建实例
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: jsonString(json['accessToken']),
      refreshToken: jsonString(json['refreshToken']),
      expiresAt: jsonDate(json['expiresAt']),
      user: UserProfile.fromJson((json['user'] as Map).cast<String, dynamic>()),
    );
  }
}

/// OAuth 账户绑定信息模型
class OAuthAccountInfo {
  const OAuthAccountInfo({
    required this.provider,
    required this.providerUsername,
    required this.createdAt,
  });

  final String provider;
  final String providerUsername;
  final DateTime createdAt;

  factory OAuthAccountInfo.fromJson(Map<String, dynamic> json) {
    return OAuthAccountInfo(
      provider: jsonString(json['provider']),
      providerUsername: jsonString(json['providerUsername']),
      createdAt: jsonDate(json['createdAt']),
    );
  }
}
