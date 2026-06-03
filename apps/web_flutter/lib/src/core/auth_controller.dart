/// 认证控制器
/// 管理用户登录、注册、登出、令牌刷新和持久化
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

/// 认证状态控制器
/// 使用 ChangeNotifier 通知 UI 更新
class AuthController extends ChangeNotifier {
  AuthController(this._apiClient) {
    _apiClient.onUnauthorized = _handleUnauthorized; // 设置 401 回调
  }

  // SharedPreferences 存储键
  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _userKey = 'auth.user';

  final BlogApiClient _apiClient; // API 客户端

  bool _loaded = false; // 是否已加载
  bool _busy = false; // 是否忙碌中
  bool _refreshing = false; // 是否正在刷新令牌
  String? _accessToken; // 访问令牌
  UserProfile? _user; // 用户信息

  /// 是否已加载完成
  bool get isLoaded => _loaded;
  /// 是否忙碌中
  bool get isBusy => _busy;
  /// 是否已认证
  bool get isAuthenticated => _accessToken != null;
  /// 获取访问令牌
  String? get accessToken => _accessToken;
  /// 获取用户信息
  UserProfile? get user => _user;

  /// 加载认证状态
  /// 从 SharedPreferences 读取令牌和用户信息
  Future<void> load() async {
    if (_loaded) return;

    final preferences = await SharedPreferences.getInstance();
    _accessToken = preferences.getString(_accessTokenKey);
    final rawUser = preferences.getString(_userKey);
    if (rawUser != null) {
      _user = UserProfile.fromJson(
        (jsonDecode(rawUser) as Map).cast<String, dynamic>(),
      );
    }

    _loaded = true;
    notifyListeners();

    if (_accessToken != null) {
      try {
        _user = await _apiClient.me(_accessToken!);
        await _saveUser(preferences);
        notifyListeners();
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          final newToken = await _handleUnauthorized();
          if (newToken != null) {
            try {
              _user = await _apiClient.me(newToken);
              await _saveUser(preferences);
              notifyListeners();
            } catch (_) {
              await logout();
            }
          }
        } else {
          await logout();
        }
      } catch (_) {
        await logout();
      }
    }
  }

  /// 用户登录
  /// [email] 邮箱
  /// [password] 密码
  Future<void> login({required String email, required String password}) {
    return _authenticate(
      () => _apiClient.login(email: email, password: password),
    );
  }

  /// 用户注册
  /// [email] 邮箱
  /// [password] 密码
  /// [nickname] 昵称
  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) {
    return _authenticate(
      () => _apiClient.register(
        email: email,
        password: password,
        nickname: nickname,
      ),
    );
  }

  /// 更新用户资料
  /// [email] 邮箱
  /// [nickname] 昵称
  /// [avatarUrl] 头像 URL
  /// [bio] 个人简介
  /// [blogUrl] 博客链接
  Future<void> updateProfile({
    required String email,
    required String nickname,
    String? avatarUrl,
    String? bio,
    String? blogUrl,
  }) async {
    final token = _accessToken;
    if (token == null) {
      throw const ApiException('请先登录');
    }

    _setBusy(true);
    try {
      _user = await _apiClient.updateMe(
        accessToken: token,
        email: email,
        nickname: nickname,
        avatarUrl: avatarUrl,
        bio: bio,
        blogUrl: blogUrl,
      );
      await _saveUser(await SharedPreferences.getInstance());
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// 用户登出
  /// 清除本地存储的令牌和用户信息
  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    _accessToken = null;
    _user = null;
    await preferences.remove(_accessTokenKey);
    await preferences.remove(_refreshTokenKey);
    await preferences.remove(_userKey);
    _loaded = true;
    notifyListeners();
  }

  /// 执行认证请求（登录/注册）
  Future<void> _authenticate(Future<AuthSession> Function() request) async {
    _setBusy(true);
    try {
      final session = await request();
      _accessToken = session.accessToken;
      _user = session.user;

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_accessTokenKey, session.accessToken);
      await preferences.setString(_refreshTokenKey, session.refreshToken);
      await _saveUser(preferences);
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// 保存用户信息到 SharedPreferences
  Future<void> _saveUser(SharedPreferences preferences) async {
    final user = _user;
    if (user == null) {
      await preferences.remove(_userKey);
      return;
    }
    await preferences.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// 设置忙碌状态
  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  /// 处理 401 未授权响应
  /// 尝试使用刷新令牌获取新的访问令牌
  Future<String?> _handleUnauthorized() async {
    if (_refreshing) return null;
    _refreshing = true;

    try {
      final preferences = await SharedPreferences.getInstance();
      final refreshToken = preferences.getString(_refreshTokenKey);
      if (refreshToken == null) {
        await logout();
        return null;
      }

      final session = await _apiClient.refreshAccessToken(refreshToken);
      _accessToken = session.accessToken;
      _user = session.user;

      await preferences.setString(_accessTokenKey, session.accessToken);
      await preferences.setString(_refreshTokenKey, session.refreshToken);
      await _saveUser(preferences);
      notifyListeners();

      return session.accessToken;
    } catch (_) {
      await logout();
      return null;
    } finally {
      _refreshing = false;
    }
  }
}
