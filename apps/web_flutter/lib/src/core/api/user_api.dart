// 用户相关 API
// 包含用户资料、活动记录、密码管理等

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models.dart';
import 'api_client_base.dart';

/// 用户相关 API Mixin
mixin UserApi on ApiClientBase {
  /// 获取当前用户信息
  Future<UserProfile> me(String accessToken) async {
    final data = await get('/me', accessToken: accessToken);
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新当前用户信息
  Future<UserProfile> updateMe({
    required String accessToken,
    required String email,
    required String nickname,
    String? avatarUrl,
    String? bio,
    String? blogUrl,
  }) async {
    final data = await put(
      '/me',
      accessToken: accessToken,
      body: {
        'email': email,
        'nickname': nickname,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'blogUrl': blogUrl,
      },
    );
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 上传用户头像
  Future<String> uploadAvatar({
    required String accessToken,
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final data = await send(
      'POST',
      '/me/avatar',
      accessToken: accessToken,
      formData: formData,
    );
    final userProfile = UserProfile.fromJson((data as Map).cast<String, dynamic>());
    return userProfile.avatarUrl ?? '';
  }

  /// 获取当前用户绑定的 OAuth 账户列表
  Future<List<OAuthAccountInfo>> fetchOAuthAccounts({
    required String accessToken,
  }) async {
    final data = await get('/me/oauth-accounts', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => OAuthAccountInfo.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 解绑指定的 OAuth 账户
  Future<void> unbindOAuthAccount({
    required String accessToken,
    required String provider,
  }) async {
    await delete('/me/oauth-accounts/$provider', accessToken: accessToken);
  }

  /// 获取我的活动记录
  Future<PageResult<UserActivity>> fetchMyActivity({
    required String accessToken,
    required String type,
    int page = 0,
    int size = 20,
  }) async {
    final data = await get(
      '/me/$type',
      accessToken: accessToken,
      queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      },
    );
    return pageResult(data, UserActivity.fromJson);
  }

  /// 删除我的活动记录
  Future<void> deleteMyActivity({
    required String accessToken,
    required String type,
    required String id,
  }) async {
    await delete('/me/$type/$id', accessToken: accessToken);
  }

  /// 修改密码
  Future<void> changePassword({
    required String accessToken,
    required String oldPassword,
    required String newPassword,
  }) async {
    await put(
      '/me/password',
      accessToken: accessToken,
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  /// 设置密码（用于 OAuth 用户首次设置密码）
  Future<void> setPassword({
    required String accessToken,
    required String newPassword,
  }) async {
    await post(
      '/me/password',
      accessToken: accessToken,
      body: {'newPassword': newPassword},
    );
  }
}
