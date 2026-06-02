import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(false, '你好，我是这个博客的 AI 助手。登录后每天可以问我 10 个问题。'),
  ];
  String? _sessionId;
  int? _remaining;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final quota = auth.isAuthenticated ? ref.watch(aiQuotaProvider) : null;
    final quotaRemaining = quota?.maybeWhen(
      data: (value) => value.remaining,
      orElse: () => null,
    );
    final remaining = _remaining ?? quotaRemaining ?? 10;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('关于我')),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              Text(
                '写代码，也记录生活。',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text('这里会放个人介绍、项目经历、常用技术栈和联系方式。'),
              const SizedBox(height: 24),
              Card(
                child: SizedBox(
                  height: 520,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.smart_toy),
                        title: const Text('AI 助手'),
                        subtitle: Text(
                          auth.isAuthenticated
                              ? '今日剩余 $remaining 次'
                              : '登录后每天可以提问 10 次',
                        ),
                        trailing:
                            auth.isAuthenticated
                                ? IconButton(
                                  tooltip: '刷新额度',
                                  onPressed:
                                      () => ref.invalidate(aiQuotaProvider),
                                  icon: const Icon(Icons.refresh),
                                )
                                : null,
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder:
                              (context, index) =>
                                  _ChatBubble(message: _messages[index]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                enabled:
                                    auth.isAuthenticated &&
                                    !_sending &&
                                    remaining > 0,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText:
                                      auth.isAuthenticated
                                          ? '问问我的经历、文章或项目'
                                          : '登录后和 AI 助手对话',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: auth.isAuthenticated ? '发送' : '登录',
                              onPressed: _sending ? null : _send,
                              icon:
                                  _sending
                                      ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final auth = ref.read(authControllerProvider);
    final token = auth.accessToken;
    if (token == null) {
      context.go('/login?from=/about');
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty || (_remaining != null && _remaining! <= 0)) return;

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(true, text));
      _controller.clear();
    });

    try {
      final reply = await ref
          .read(apiClientProvider)
          .sendAiMessage(
            accessToken: token,
            sessionId: _sessionId,
            message: text,
          );
      if (!mounted) return;
      setState(() {
        _sessionId = reply.sessionId;
        _remaining = reply.remainingQuestions;
        _messages.add(_ChatMessage(false, reply.answer));
      });
      ref.invalidate(aiQuotaProvider);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              message.mine
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border:
              message.mine ? null : Border.all(color: const Color(0xFFE0E7E3)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color:
                message.mine
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage(this.mine, this.text);

  final bool mine;
  final String text;
}
