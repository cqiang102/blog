// 认证控制器
// 管理用户登录、注册、登出、令牌刷新和持久化

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/models.dart';

/// 认证状态控制器
/// 使用 ChangeNotifier 通知 UI 更新
class AuthController extends ChangeNotifier {
  AuthController(this._apiClient) {
    _apiClient.onUnauthorized = _handleUnauthorized; // 设置 401 回调
  }

  // SharedPreferences 存储键
  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _expiresAtKey = 'auth.expiresAt';
  static const _userKey = 'auth.user';

  /// token 过期前的缓冲时间，提前刷新避免请求时刚好过期
  static const _refreshBuffer = Duration(minutes: 2);

  final BlogApiClient _apiClient; // API 客户端

  bool _loaded = false; // 是否已加载
  bool _busy = false; // 是否忙碌中
  String? _accessToken; // 访问令牌
  DateTime? _expiresAt; // 访问令牌过期时间
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
    final expiresAtMs = preferences.getInt(_expiresAtKey);
    if (expiresAtMs != null) {
      _expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expiresAtMs,
        isUtc: true,
      );
    }
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
        _user = await _apiClient.fetchProfile(_accessToken!);
        await _saveUser(preferences);
        notifyListeners();
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          final newToken = await _handleUnauthorized();
          if (newToken != null) {
            try {
              _user = await _apiClient.fetchProfile(newToken);
              await _saveUser(preferences);
              notifyListeners();
            } on ApiException catch (retryError) {
              if (retryError.statusCode == 401) {
                await logout();
              }
            }
          }
        }
      } catch (_) {
        // 网络或服务短暂不可用时保留本地会话，避免误登出。
      }
    }
  }

  /// 获取有效的访问令牌
  /// 如果令牌已过期或即将过期，先刷新再返回
  /// 用于在发起请求前主动检查 token 有效性
  Future<String?> getValidAccessToken() async {
    if (_accessToken == null) return null;

    // 未记录过期时间，或尚未过期，直接返回
    if (_expiresAt == null ||
        DateTime.now().isBefore(_expiresAt!.subtract(_refreshBuffer))) {
      return _accessToken;
    }

    // token 已过期或即将过期，刷新
    return _handleUnauthorized();
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
  /// [code] 邮箱验证码
  Future<void> register({
    required String email,
    required String password,
    required String nickname,
    required String code,
  }) {
    return _authenticate(
      () => _apiClient.register(
        email: email,
        password: password,
        nickname: nickname,
        code: code,
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
      _user = await _apiClient.updateProfile(
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

  /// 重新加载用户信息
  /// 用于刷新用户资料（如设置密码后更新 hasPassword 状态）
  Future<void> loadUser() async {
    final token = _accessToken;
    if (token == null) return;

    try {
      _user = await _apiClient.fetchProfile(token);
      await _saveUser(await SharedPreferences.getInstance());
      notifyListeners();
    } catch (_) {
      // 静默失败，不影响当前状态
    }
  }

  /// 用户登出
  /// 清除本地存储的令牌和用户信息
  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    _accessToken = null;
    _expiresAt = null;
    _user = null;
    await preferences.remove(_accessTokenKey);
    await preferences.remove(_refreshTokenKey);
    await preferences.remove(_expiresAtKey);
    await preferences.remove(_userKey);
    _loaded = true;
    notifyListeners();
  }

  /// 使用已有的 AuthSession 登录（用于 OAuth 回调等场景）
  Future<void> loginWithSession(AuthSession session) async {
    _accessToken = session.accessToken;
    _expiresAt = session.expiresAt;
    _user = session.user;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_accessTokenKey, session.accessToken);
    await preferences.setString(_refreshTokenKey, session.refreshToken);
    await preferences.setInt(
      _expiresAtKey,
      session.expiresAt.millisecondsSinceEpoch,
    );
    await _saveUser(preferences);
    notifyListeners();
  }

  /// 执行认证请求（登录/注册）
  Future<void> _authenticate(Future<AuthSession> Function() request) async {
    _setBusy(true);
    try {
      final session = await request();
      _accessToken = session.accessToken;
      _expiresAt = session.expiresAt;
      _user = session.user;

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_accessTokenKey, session.accessToken);
      await preferences.setString(_refreshTokenKey, session.refreshToken);
      await preferences.setInt(
        _expiresAtKey,
        session.expiresAt.millisecondsSinceEpoch,
      );
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

  Completer<String?>? _refreshCompleter;

  /// 处理 401 未授权响应
  /// 尝试使用刷新令牌获取新的访问令牌
  /// 如果已有刷新正在进行，等待其完成并返回结果
  Future<String?> _handleUnauthorized() async {
    // 如果已有刷新在进行，等待其完成
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final preferences = await SharedPreferences.getInstance();
      final refreshToken = preferences.getString(_refreshTokenKey);
      if (refreshToken == null) {
        await logout();
        _refreshCompleter!.complete(null);
        return null;
      }

      final session = await _apiClient.refreshAccessToken(refreshToken);
      _accessToken = session.accessToken;
      _expiresAt = session.expiresAt;
      _user = session.user;

      await preferences.setString(_accessTokenKey, session.accessToken);
      await preferences.setString(_refreshTokenKey, session.refreshToken);
      await preferences.setInt(
        _expiresAtKey,
        session.expiresAt.millisecondsSinceEpoch,
      );
      await _saveUser(preferences);
      notifyListeners();

      _refreshCompleter!.complete(session.accessToken);
      return session.accessToken;
    } on ApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401) {
        await logout();
      }
      _refreshCompleter!.complete(null);
      return null;
    } catch (_) {
      // 临时网络故障不应销毁仍可恢复的本地会话。
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
