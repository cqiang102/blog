// GitHub OAuth 回调页面
// 处理 GitHub 授权后的回调，完成登录或绑定

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../state/state.dart';

/// GitHub OAuth 回调页面
/// GitHub 授权后会跳转到 /login/oauth2/code/github?code=...&state=...
/// 本页面提取 code 和 state，调用后端 API 完成登录/绑定
class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({
    super.key,
    this.code,
    this.state,
    this.token,
    this.refresh,
    this.expires,
  });

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
  static String? _handledKey;

  /// 生成去重 key：优先用 token，其次用 code
  String? get _callbackKey {
    if (widget.token != null) return 'token:${widget.token}';
    if (widget.code != null) return 'code:${widget.code}';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  @override
  void dispose() {
    // 如果当前正在处理且 widget 被销毁，重置全局状态
    // 允许后续重建的 widget 重新尝试
    if (_isProcessing && _handledKey == _callbackKey) {
      _isProcessing = false;
      _handledKey = null;
    }
    super.dispose();
  }

  Future<void> _handleCallback() async {
    final key = _callbackKey;

    // 防止重复请求：如果正在处理中，或已用相同 key 处理过，直接跳过
    if (_isProcessing || (key != null && _handledKey == key)) {
      return;
    }
    _isProcessing = true;
    _handledKey = key;

    try {
      // 情况 1：Spring Security 登录重定向，直接携带 token
      if (widget.token != null && widget.refresh != null) {
        if (!mounted) return;
        final authController = ref.read(authControllerProvider);
        await authController.loginWithTokens(
          accessToken: widget.token!,
          refreshToken: widget.refresh!,
          expiresAtMs:
              widget.expires != null ? int.tryParse(widget.expires!) : null,
        );
        _navigateHome();
        return;
      }

      // 情况 2：前端 GitHub 回调，携带 code
      if (widget.code != null) {
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

      if (mounted) setState(() => _error = '无效的回调参数');
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
    } finally {
      _isProcessing = false;
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
