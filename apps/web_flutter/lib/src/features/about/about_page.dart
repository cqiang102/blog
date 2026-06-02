import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/auth_controller.dart';
import '../../core/models.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];
  String? _sessionId;
  int? _remaining;
  int _remainingMessages = 40;
  bool _sending = false;
  bool _loadingHistory = false;
  bool _sessionLimitReached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatestSession());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLatestSession() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final sessions = await ref.read(apiClientProvider).fetchAiSessions(token);
      if (!mounted || sessions.isEmpty) return;

      final latest = sessions.first;
      setState(() => _sessionId = latest.id);
      await _loadHistory(latest.id);
    } on ApiException {
      // No sessions yet, that's fine
    }
  }

  Future<void> _loadHistory(String sessionId) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    setState(() => _loadingHistory = true);
    try {
      final page = await ref.read(apiClientProvider).fetchAiSessionMessages(
            accessToken: token,
            sessionId: sessionId,
            size: 50,
          );
      if (!mounted) return;
      setState(() {
        _messages.clear();
        for (final msg in page.items) {
          _messages.add(_ChatMessage(msg.role == 'USER', msg.content));
        }
        _remainingMessages = 40 - page.total;
        _sessionLimitReached = _remainingMessages <= 0;
      });
    } on ApiException {
      // Session might not exist yet
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _createNewSession() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final session = await ref.read(apiClientProvider).createAiSession(
            accessToken: token,
          );
      if (!mounted) return;
      setState(() {
        _sessionId = session.id;
        _messages.clear();
        _remainingMessages = 40;
        _sessionLimitReached = false;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    }
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
                  height: 560,
                  child: Column(
                    children: [
                      _buildHeader(auth, remaining),
                      const Divider(height: 1),
                      Expanded(
                        child: _loadingHistory
                            ? const Center(child: CircularProgressIndicator())
                            : _messages.isEmpty
                                ? const Center(
                                    child: Text(
                                      '有什么想问的？试试问我关于博客文章、技术栈或个人经历的问题',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) =>
                                        _ChatBubble(message: _messages[index]),
                                  ),
                      ),
                      if (_sessionLimitReached)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '当前会话消息数已达上限',
                                  style: TextStyle(color: Colors.orange, fontSize: 13),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _createNewSession,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('新建会话'),
                              ),
                            ],
                          ),
                        ),
                      _buildInputBar(auth, remaining),
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

  Widget _buildHeader(AuthController auth, int remaining) {
    return ListTile(
      leading: const Icon(Icons.smart_toy),
      title: const Text('AI 助手'),
      subtitle: Text(
        auth.isAuthenticated
            ? '今日剩余 $remaining 次 · 会话剩余 $_remainingMessages 条'
            : '登录后每天可以提问 10 次',
      ),
      trailing: auth.isAuthenticated
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '历史会话',
                  onPressed: _showSessionList,
                  icon: const Icon(Icons.history),
                ),
                IconButton(
                  tooltip: '新建会话',
                  onPressed: _createNewSession,
                  icon: const Icon(Icons.add_comment),
                ),
                IconButton(
                  tooltip: '刷新额度',
                  onPressed: () => ref.invalidate(aiQuotaProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildInputBar(AuthController auth, int remaining) {
    final canSend = auth.isAuthenticated &&
        !_sending &&
        remaining > 0 &&
        !_sessionLimitReached;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: canSend,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: !auth.isAuthenticated
                    ? '登录后和 AI 助手对话'
                    : _sessionLimitReached
                        ? '请新建会话后继续'
                        : '问问我的经历、文章或项目',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: auth.isAuthenticated ? '发送' : '登录',
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
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
        _remainingMessages = reply.remainingMessages;
        _sessionLimitReached = _remainingMessages <= 0;
        _messages.add(_ChatMessage(false, reply.answer));
      });
      ref.invalidate(aiQuotaProvider);
    } on ApiException catch (error) {
      if (error.message.contains('会话消息数已达上限')) {
        setState(() => _sessionLimitReached = true);
      }
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showSessionList() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final sessions = await ref.read(apiClientProvider).fetchAiSessions(token);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) => _SessionListSheet(
          sessions: sessions,
          currentSessionId: _sessionId,
          onSelect: (session) {
            Navigator.of(context).pop();
            setState(() => _sessionId = session.id);
            _loadHistory(session.id);
          },
          onCreateNew: () {
            Navigator.of(context).pop();
            _createNewSession();
          },
        ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SessionListSheet extends StatelessWidget {
  const _SessionListSheet({
    required this.sessions,
    required this.currentSessionId,
    required this.onSelect,
    required this.onCreateNew,
  });

  final List<AiSessionItem> sessions;
  final String? currentSessionId;
  final ValueChanged<AiSessionItem> onSelect;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '历史会话',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onCreateNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建会话'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('暂无历史会话', style: TextStyle(color: Colors.grey)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isCurrent = session.id == currentSessionId;
                  final date = DateFormat('MM-dd HH:mm').format(session.updatedAt);
                  return ListTile(
                    leading: Icon(
                      isCurrent ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${session.messageCount} 条消息 · $date'),
                    selected: isCurrent,
                    onTap: () => onSelect(session),
                  );
                },
              ),
            ),
        ],
      ),
    );
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
          color: message.mine
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border:
              message.mine ? null : Border.all(color: const Color(0xFFE0E7E3)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.mine
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
