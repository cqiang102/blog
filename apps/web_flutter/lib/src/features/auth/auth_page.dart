// 认证页模块
// 支持登录/注册切换和 GitHub OAuth 登录
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';

/// 认证页 Widget
/// 提供邮箱密码登录/注册和 GitHub OAuth 登录功能
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

/// 认证页状态管理
/// 管理登录/注册表单、模式切换和 OAuth 跳转
class _AuthPageState extends ConsumerState<AuthPage> {
  final _emailController = TextEditingController(); // 邮箱输入框
  final _passwordController = TextEditingController(); // 密码输入框
  final _nicknameController = TextEditingController(); // 昵称输入框（注册时使用）
  bool _register = false; // 是否为注册模式

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
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
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                  onSubmitted: (_) => _submit(),
                ),
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

    try {
      if (_register) {
        await ref
            .read(authControllerProvider)
            .register(
              email: email,
              password: password,
              nickname: nickname.isEmpty ? email.split('@').first : nickname,
            );
      } else {
        await ref
            .read(authControllerProvider)
            .login(email: email, password: password);
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
  /// 在当前窗口跳转到 GitHub 授权页面
  Future<void> _openGithubLogin() async {
    final url = Uri.parse(ref.read(apiClientProvider).githubAuthorizationUrl);
    await launchUrl(url, webOnlyWindowName: '_self');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
