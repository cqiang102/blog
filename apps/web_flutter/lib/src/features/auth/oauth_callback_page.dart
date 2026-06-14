// GitHub OAuth 回调页面
// 处理 GitHub 授权后的回调，完成登录或绑定

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../auth/oauth_state_storage.dart';
import '../../core/api_client.dart';
import '../../state/state.dart';

/// GitHub OAuth 回调页面
/// GitHub 授权后会跳转到 /login/oauth2/code/github?code=...&state=...
/// 本页面提取 code 和 state，调用后端 API 完成登录/绑定
class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({super.key, this.code, this.state, this.loginCode});

  final String? code;
  final String? state;
  final String? loginCode;

  @override
  ConsumerState<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends ConsumerState<OAuthCallbackPage> {
  String? _error;
  bool _processing = true;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    if (_started) return;
    _started = true;

    try {
      // 情况 1：Spring Security 登录重定向，携带一次性兑换码
      if (widget.loginCode != null) {
        if (!mounted) return;
        final apiClient = ref.read(apiClientProvider);
        final authController = ref.read(authControllerProvider);
        final session = await apiClient.exchangeOAuthLoginCode(
          widget.loginCode!,
        );
        await authController.loginWithSession(session);
        _navigateHome();
        return;
      }

      // 情况 2：前端 GitHub 回调，携带 code 和 state
      if (widget.code != null) {
        final state = widget.state;
        if (state == null || !consumeOAuthState(state)) {
          if (mounted) {
            setState(() {
              _error = 'OAuth state 无效或已过期，请重新登录';
              _processing = false;
            });
          }
          return;
        }
        if (!mounted) return;
        final apiClient = ref.read(apiClientProvider);
        final authController = ref.read(authControllerProvider);
        final session = await apiClient.githubOAuthCallback(
          code: widget.code!,
          state: widget.state,
        );
        await authController.loginWithSession(session);
        _navigateHome();
        return;
      }

      if (mounted) {
        setState(() {
          _error = '无效的回调参数';
          _processing = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _processing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '处理回调失败: $e';
          _processing = false;
        });
      }
    }
  }

  void _navigateHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _processing
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在处理 GitHub 授权...'),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert01,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? '未知错误',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('返回首页'),
                  ),
                ],
              ),
      ),
    );
  }
}
