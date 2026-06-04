/// GitHub OAuth 回调页面
/// 处理 GitHub 授权后的回调，完成登录或绑定
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';

/// GitHub OAuth 回调页面
/// GitHub 授权后会跳转到 /login/oauth2/code/github?code=...&state=...
/// 本页面提取 code 和 state，调用后端 API 完成登录/绑定
class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({super.key, this.code, this.state, this.token, this.refresh, this.expires});

  final String? code;
  final String? state;
  final String? token;
  final String? refresh;
  final String? expires;

  @override
  ConsumerState<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends ConsumerState<OAuthCallbackPage> {
  String? _error;
  bool _processing = true;

  /// 全局标志位，防止 GoRouter 重建导致重复请求
  static bool _isProcessing = false;
  static String? _lastCode;

  @override
  void initState() {
    super.initState();
    debugPrint('OAuthCallbackPage.initState: code=${widget.code}, state=${widget.state}');
    // 检查是否有待处理的导航
    if (_pendingNavigation) {
      _pendingNavigation = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return;
    }
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    // 防止重复请求：如果正在处理中，或已用相同 code 处理过，直接跳过
    if (_isProcessing) {
      debugPrint('OAuthCallbackPage._handleCallback: already processing, skip');
      return;
    }
    if (_lastCode != null && _lastCode == widget.code) {
      debugPrint('OAuthCallbackPage._handleCallback: code already handled, skip');
      return;
    }
    _isProcessing = true;
    _lastCode = widget.code;
    debugPrint('OAuthCallbackPage._handleCallback: start');
    try {
      // 情况 1：Spring Security 登录重定向，直接携带 token
      if (widget.token != null && widget.refresh != null) {
        debugPrint('OAuthCallbackPage: loginWithTokens');
        if (!mounted) return;
        final authController = ref.read(authControllerProvider);
        await authController.loginWithTokens(
              accessToken: widget.token!,
              refreshToken: widget.refresh!,
              expiresAtMs: widget.expires != null ? int.tryParse(widget.expires!) : null,
            );
        _navigateHome();
        return;
      }

      // 情况 2：前端 GitHub 回调，携带 code
      if (widget.code != null) {
        debugPrint('OAuthCallbackPage: calling githubOAuthCallback with code=${widget.code}');
        if (!mounted) return;
        final apiClient = ref.read(apiClientProvider);
        final authController = ref.read(authControllerProvider);
        final session = await apiClient.githubOAuthCallback(
          code: widget.code!,
          state: widget.state,
        );
        debugPrint('OAuthCallbackPage: got session, loginWithSession');
        await authController.loginWithSession(session);
        _navigateHome();
        return;
      }

      debugPrint('OAuthCallbackPage: no code or token');
      if (mounted) setState(() => _error = '无效的回调参数');
    } on ApiException catch (e) {
      debugPrint('OAuthCallbackPage ApiException: ${e.message}');
      if (mounted) {
        setState(() {
          _error = e.message;
          _processing = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('OAuthCallbackPage error: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = '处理回调失败: $e';
          _processing = false;
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  void _navigateHome() {
    debugPrint('OAuthCallbackPage: navigating to home, mounted=$mounted');
    // 使用 WidgetsBinding 确保在下一帧执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('OAuthCallbackPage: context.go(/)');
        context.go('/');
      } else {
        debugPrint('OAuthCallbackPage: not mounted, using static navigation');
        // widget 已销毁，通过静态 navigator key 导航
        _pendingNavigation = true;
      }
    });
  }

  /// 待导航标志
  static bool _pendingNavigation = false;

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
                  Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(_error ?? '未知错误', style: Theme.of(context).textTheme.bodyLarge),
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
