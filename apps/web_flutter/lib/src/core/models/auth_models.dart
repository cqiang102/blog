// 认证相关数据模型
// 包含用户资料、认证会话、OAuth 账户等

import 'package:json_annotation/json_annotation.dart';

import 'json_converters.dart';

part 'auth_models.g.dart';

/// role 字段专用转换器：空字符串 → 'USER'
class _RoleStringJsonConverter implements JsonConverter<String, Object?> {
  const _RoleStringJsonConverter();

  @override
  String fromJson(Object? json) {
    final text = json?.toString() ?? '';
    return text.isEmpty ? 'USER' : text;
  }

  @override
  Object? toJson(String object) => object;
}

/// 用户资料模型
@JsonSerializable()
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

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String email;
  @SafeStringJsonConverter()
  final String nickname;
  @_RoleStringJsonConverter()
  final String role;
  @NullableStringJsonConverter()
  final String? avatarUrl;
  @NullableStringJsonConverter()
  final String? bio;
  @NullableStringJsonConverter()
  final String? blogUrl;
  @JsonKey(defaultValue: false)
  final bool hasPassword;

  /// 是否为管理员角色
  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

/// 认证会话模型
@JsonSerializable()
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  @SafeStringJsonConverter()
  final String accessToken;
  @SafeStringJsonConverter()
  final String refreshToken;
  @SafeDateTimeJsonConverter()
  final DateTime expiresAt;
  final UserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);

  Map<String, dynamic> toJson() => _$AuthSessionToJson(this);
}

/// OAuth 账户绑定信息模型
@JsonSerializable()
class OAuthAccountInfo {
  const OAuthAccountInfo({
    required this.provider,
    required this.providerUsername,
    required this.createdAt,
  });

  @SafeStringJsonConverter()
  final String provider;
  @SafeStringJsonConverter()
  final String providerUsername;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;

  factory OAuthAccountInfo.fromJson(Map<String, dynamic> json) =>
      _$OAuthAccountInfoFromJson(json);

  Map<String, dynamic> toJson() => _$OAuthAccountInfoToJson(this);
}
