// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  email: const SafeStringJsonConverter().fromJson(json['email']),
  nickname: const SafeStringJsonConverter().fromJson(json['nickname']),
  role: const _RoleStringJsonConverter().fromJson(json['role']),
  avatarUrl: const NullableStringJsonConverter().fromJson(json['avatarUrl']),
  bio: const NullableStringJsonConverter().fromJson(json['bio']),
  blogUrl: const NullableStringJsonConverter().fromJson(json['blogUrl']),
  hasPassword: json['hasPassword'] as bool? ?? false,
);

Map<String, dynamic> _$UserProfileToJson(
  UserProfile instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'email': const SafeStringJsonConverter().toJson(instance.email),
  'nickname': const SafeStringJsonConverter().toJson(instance.nickname),
  'role': const _RoleStringJsonConverter().toJson(instance.role),
  'avatarUrl': const NullableStringJsonConverter().toJson(instance.avatarUrl),
  'bio': const NullableStringJsonConverter().toJson(instance.bio),
  'blogUrl': const NullableStringJsonConverter().toJson(instance.blogUrl),
  'hasPassword': instance.hasPassword,
};

AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) => AuthSession(
  accessToken: const SafeStringJsonConverter().fromJson(json['accessToken']),
  refreshToken: const SafeStringJsonConverter().fromJson(json['refreshToken']),
  expiresAt: const SafeDateTimeJsonConverter().fromJson(json['expiresAt']),
  user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AuthSessionToJson(
  AuthSession instance,
) => <String, dynamic>{
  'accessToken': const SafeStringJsonConverter().toJson(instance.accessToken),
  'refreshToken': const SafeStringJsonConverter().toJson(instance.refreshToken),
  'expiresAt': const SafeDateTimeJsonConverter().toJson(instance.expiresAt),
  'user': instance.user,
};

OAuthAccountInfo _$OAuthAccountInfoFromJson(Map<String, dynamic> json) =>
    OAuthAccountInfo(
      provider: const SafeStringJsonConverter().fromJson(json['provider']),
      providerUsername: const SafeStringJsonConverter().fromJson(
        json['providerUsername'],
      ),
      createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
    );

Map<String, dynamic> _$OAuthAccountInfoToJson(OAuthAccountInfo instance) =>
    <String, dynamic>{
      'provider': const SafeStringJsonConverter().toJson(instance.provider),
      'providerUsername': const SafeStringJsonConverter().toJson(
        instance.providerUsername,
      ),
      'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
    };
