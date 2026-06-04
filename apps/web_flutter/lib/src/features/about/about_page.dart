// AI 聊天页模块
// 支持 SSE 流式响应、会话管理、配额显示和 40 条消息限制
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/auth_controller.dart';
import '../../core/models.dart';

/// AI 聊天页 Widget
/// 提供与 AI 助手的对话界面，支持流式响应和会话切换
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

/// AI 聊天页状态管理
/// 管理聊天消息、会话 ID、配额和 SSE 流式响应
class _AboutPageState extends ConsumerState<AboutPage> {
  final _controller = TextEditingController(); // 输入框控制器
  final _messages = <_ChatMessage>[]; // 聊天消息列表
  final _scrollController = ScrollController(); // 滚动控制器
  String? _sessionId; // 当前会话 ID
  int? _remaining; // 今日剩余提问次数
  int _remainingMessages = 40; // 当前会话剩余消息数（上限 40 条）
  bool _sending = false; // 是否正在发送消息
  bool _loadingHistory = false; // 是否正在加载历史消息
  bool _sessionLimitReached = false; // 当前会话是否达到消息上限

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatestSession());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  /// 加载最近的会话
  /// 获取用户的会话列表，自动加载最新会话的历史消息
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

  /// 加载会话历史消息
  /// 清空当前消息列表，从 API 获取指定会话的历史消息
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException {
      // Session might not exist yet
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  /// 创建新会话
  /// 调用 API 创建新的 AI 会话，重置消息列表和配额
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
    final remaining = _remaining ?? quotaRemaining;

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
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) =>
                                        _ChatBubble(
                                          message: _messages[index],
                                          isStreaming: _sending && index == _messages.length - 1 && !_messages[index].mine,
                                        ),
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

  /// 构建头部区域
  /// 显示 AI 助手标题、配额信息和操作按钮（历史会话/新建）
  Widget _buildHeader(AuthController auth, int? remaining) {
    return ListTile(
      leading: const Icon(Icons.smart_toy),
      title: const Text('AI 助手'),
      subtitle: Text(
        auth.isAuthenticated
            ? remaining != null
                ? '今日剩余 $remaining 次 · 会话剩余 $_remainingMessages 条'
                : '正在加载配额...'
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
              ],
            )
          : null,
    );
  }

  /// 构建输入栏
  /// 包含文本输入框和发送按钮，根据登录状态和配额控制可用性
  Widget _buildInputBar(AuthController auth, int? remaining) {
    final canSend = auth.isAuthenticated &&
        !_sending &&
        (remaining == null || remaining > 0) &&
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
                    : remaining != null && remaining <= 0
                        ? '今日提问次数已用完'
                        : _sessionLimitReached
                            ? '请新建会话后继续'
                            : '问问我的经历、文章或项目',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: auth.isAuthenticated ? '发送' : '登录',
            onPressed: canSend ? _send : null,
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

  /// 发送消息
  /// 通过 SSE 流式发送消息，实时更新 AI 回复内容
  /// 处理 token（逐字输出）、done（完成）和 error（错误）事件
  Future<void> _send() async {
    final auth = ref.read(authControllerProvider);
    final token = await auth.getValidAccessToken();
    if (!mounted) return;
    if (token == null) {
      context.go('/login?from=/about');
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty || (_remaining != null && _remaining! <= 0)) return;

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(true, text));
      _messages.add(_ChatMessage(false, ''));
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final stream = ref.read(apiClientProvider).sendAiMessageStream(
            accessToken: token,
            sessionId: _sessionId,
            message: text,
          );

      await for (final event in stream) {
        if (!mounted) return;
        if (event.type == 'token') {
          setState(() {
            final last = _messages.last;
            _messages[_messages.length - 1] = _ChatMessage(false, last.text + event.data);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        } else if (event.type == 'done') {
          final reply = AiChatReply.fromJson(
            (jsonDecode(event.data) as Map).cast<String, dynamic>(),
          );
          setState(() {
            _sessionId = reply.sessionId;
            _remaining = reply.remainingQuestions;
            _remainingMessages = reply.remainingMessages;
            _sessionLimitReached = _remainingMessages <= 0;
          });
          ref.invalidate(aiQuotaProvider);
        } else if (event.type == 'error') {
          final errorMsg = event.data;
          if (errorMsg.contains('提问次数') || errorMsg.contains('配额')) {
            setState(() => _remaining = 0);
          }
          setState(() {
            _messages[_messages.length - 1] = _ChatMessage(false, '错误：$errorMsg');
          });
        }
      }
    } on ApiException catch (error) {
      if (error.message.contains('会话消息数已达上限')) {
        setState(() => _sessionLimitReached = true);
      }
      setState(() {
        if (_messages.isNotEmpty && !_messages.last.mine && _messages.last.text.isEmpty) {
          _messages.removeLast();
        }
      });
      _showError(error.message);
    } catch (error) {
      setState(() {
        if (_messages.isNotEmpty && !_messages.last.mine && _messages.last.text.isEmpty) {
          _messages.removeLast();
        }
      });
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 显示会话列表
  /// 以底部弹出面板展示历史会话列表，支持切换和新建
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

/// 会话列表弹出面板
/// 展示历史会话列表，支持选择会话和创建新会话
class _SessionListSheet extends StatelessWidget {
  const _SessionListSheet({
    required this.sessions,
    required this.currentSessionId,
    required this.onSelect,
    required this.onCreateNew,
  });

  final List<AiSessionItem> sessions; // 会话列表
  final String? currentSessionId; // 当前会话 ID
  final ValueChanged<AiSessionItem> onSelect; // 选择会话回调
  final VoidCallback onCreateNew; // 创建新会话回调

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

/// 聊天气泡组件
/// 区分用户消息（右侧蓝色）和 AI 消息（左侧白色），支持流式输出动画
/// AI 消息支持 Markdown 渲染
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.isStreaming = false});

  final _ChatMessage message; // 消息数据
  final bool isStreaming; // 是否正在流式输出

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
        child: message.text.isEmpty && isStreaming
            ? const SizedBox(
                width: 24,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : message.mine
                ? Text(
                    message.text,
                    style: const TextStyle(color: Colors.white),
                  )
                : MarkdownBody(
                    data: '${message.text}${isStreaming ? '▍' : ''}',
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      code: TextStyle(
                        backgroundColor: Colors.grey.shade100,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
      ),
    );
  }
}

/// 聊天消息数据模型
/// [mine] 标识是否为用户消息，[text] 为消息内容
class _ChatMessage {
  const _ChatMessage(this.mine, this.text);

  final bool mine; // 是否为用户发送的消息
  final String text; // 消息文本内容
}
