import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._apiClient);

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _userKey = 'auth.user';

  final BlogApiClient _apiClient;

  bool _loaded = false;
  bool _busy = false;
  String? _accessToken;
  UserProfile? _user;

  bool get isLoaded => _loaded;
  bool get isBusy => _busy;
  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;
  UserProfile? get user => _user;

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
      } catch (_) {
        await logout();
      }
    }
  }

  Future<void> login({required String email, required String password}) {
    return _authenticate(
      () => _apiClient.login(email: email, password: password),
    );
  }

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

  Future<void> _saveUser(SharedPreferences preferences) async {
    final user = _user;
    if (user == null) {
      await preferences.remove(_userKey);
      return;
    }
    await preferences.setString(_userKey, jsonEncode(user.toJson()));
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}
