// 认证页模块
// 支持登录/注册切换、邮箱验证码、GitHub OAuth 登录和记住密码
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';

/// 认证页 Widget
/// 提供邮箱密码登录/注册、邮箱验证码、GitHub OAuth 登录和记住密码功能
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

/// 认证页状态管理
/// 管理登录/注册表单、验证码倒计时、OAuth 跳转和记住密码
class _AuthPageState extends ConsumerState<AuthPage> {
  // SharedPreferences 存储键
  static const _savedEmailKey = 'auth.savedEmail';
  static const _rememberMeKey = 'auth.rememberMe';

  final _emailController = TextEditingController(); // 邮箱输入框
  final _passwordController = TextEditingController(); // 密码输入框
  final _nicknameController = TextEditingController(); // 昵称输入框（注册时使用）
  final _codeController = TextEditingController(); // 验证码输入框
  bool _register = false; // 是否为注册模式
  bool _rememberMe = false; // 是否记住密码
  int _countdown = 0; // 验证码倒计时（秒）
  Timer? _timer; // 倒计时定时器

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// 从本地存储加载保存的邮箱
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

    if (rememberMe && mounted) {
      final email = prefs.getString(_savedEmailKey) ?? '';

      setState(() {
        _rememberMe = true;
        _emailController.text = email;
      });
    }
  }

  /// 保存或清除邮箱（不存储密码，安全起见）
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, _emailController.text.trim());
    } else {
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_savedEmailKey);
    }
  }

  /// 发送验证码
  /// 校验邮箱后调用 API 发送验证码，启动 60 秒倒计时
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('请输入邮箱');
      return;
    }
    if (!email.contains('@')) {
      _showError('请输入有效的邮箱地址');
      return;
    }

    try {
      await ref.read(apiClientProvider).sendVerificationCode(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已发送')));
      _startCountdown();
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  /// 启动 60 秒倒计时
  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _register ? '注册账号' : '登录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '邮箱'),
                ),
                if (_register) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(labelText: '昵称'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '验证码'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: _countdown > 0 ? null : _sendCode,
                        child: Text(
                          _countdown > 0 ? '${_countdown}s' : '获取验证码',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                  onSubmitted: (_) => _submit(),
                ),
                if (!_register) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('记住密码'),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: auth.isBusy ? null : _submit,
                  icon:
                      auth.isBusy
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(_register ? Icons.person_add : Icons.login),
                  label: Text(_register ? '注册' : '登录'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openGithubLogin,
                  icon: const Icon(Icons.code),
                  label: const Text('使用 GitHub 登录'),
                ),
                TextButton(
                  onPressed:
                      auth.isBusy
                          ? null
                          : () => setState(() => _register = !_register),
                  child: Text(_register ? '已有账号，去登录' : '没有账号，去注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 提交登录/注册表单
  /// 根据当前模式调用登录或注册 API，成功后跳转到来源页或个人中心
  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final nickname = _nicknameController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty) {
      _showError('请输入邮箱');
      return;
    }
    if (password.isEmpty) {
      _showError('请输入密码');
      return;
    }

    try {
      if (_register) {
        if (code.isEmpty) {
          _showError('请输入验证码');
          return;
        }
        await ref
            .read(authControllerProvider)
            .register(
              email: email,
              password: password,
              nickname: nickname.isEmpty ? email.split('@').first : nickname,
              code: code,
            );
      } else {
        await ref
            .read(authControllerProvider)
            .login(email: email, password: password);

        // 登录成功后保存或清除凭据
        await _saveCredentials();
      }
      if (!mounted) return;
      final from = GoRouterState.of(context).uri.queryParameters['from'];
      context.go(from == null || from.isEmpty ? '/profile' : from);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  /// 打开 GitHub OAuth 登录
  /// 调后端接口获取 GitHub 授权 URL，跳转到 GitHub 授权页面
  Future<void> _openGithubLogin() async {
    try {
      final data = await ref.read(apiClientProvider).fetchProviders();
      final githubLoginUrl = data['githubLoginUrl'] as String;
      await launchUrl(Uri.parse(githubLoginUrl), webOnlyWindowName: '_self');
    } catch (e) {
      _showError('获取 GitHub 登录地址失败: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
