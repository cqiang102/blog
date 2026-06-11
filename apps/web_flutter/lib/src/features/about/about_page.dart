// AI 聊天页模块
// 支持 SSE 流式响应、会话管理、配额显示和 40 条消息限制
// 使用 Riverpod 管理状态，替代 setState
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ai_chat_state.dart';
import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/app_ui.dart';
import '../../core/auth_controller.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

/// AI 聊天页 Widget
/// 提供与 AI 助手的对话界面，支持流式响应和会话切换
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

/// AI 聊天页状态管理
class _AboutPageState extends ConsumerState<AboutPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadingHistory = false;

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
        duration: AppAnimations.fast,
        curve: AppAnimations.defaultCurve,
      );
    }
  }

  /// 加载最近的会话
  Future<void> _loadLatestSession() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final sessions = await ref.read(apiClientProvider).fetchAiSessions(token);
      if (!mounted || sessions.isEmpty) return;

      final latest = sessions.first;
      await _loadHistory(latest.id);
    } on ApiException {
      // No sessions yet, that's fine
    }
  }

  /// 加载会话历史消息
  Future<void> _loadHistory(String sessionId) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    setState(() => _loadingHistory = true);
    try {
      final page = await ref
          .read(apiClientProvider)
          .fetchAiSessionMessages(
            accessToken: token,
            sessionId: sessionId,
            size: 50,
          );
      if (!mounted) return;

      final messages =
          page.items
              .map(
                (msg) =>
                    ChatMessage(isMine: msg.role == 'USER', text: msg.content),
              )
              .toList();

      ref.read(aiChatProvider.notifier).loadHistory(messages, sessionId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException {
      // Session might not exist yet
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  /// 创建新会话
  Future<void> _createNewSession() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref.read(apiClientProvider).createAiSession(accessToken: token);
      if (!mounted) return;
      ref.read(aiChatProvider.notifier).reset();
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
    final chatState = ref.watch(aiChatProvider);
    final remaining = chatState.remainingQuestions ?? quotaRemaining;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('关于我'),
          actions: [AppThemeToggle(), SizedBox(width: AppSpacing.sm)],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.list(
            children: [
              // 介绍文字
              // _buildIntro(context),
              // const SizedBox(height: AppSpacing.lg),

              // AI 聊天卡片
              _buildChatCard(auth, remaining, chatState),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建介绍区域
  // Widget _buildIntro(BuildContext context) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         '写代码，也记录生活。',
  //         style: Theme.of(
  //           context,
  //         ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
  //       ),
  //       const SizedBox(height: AppSpacing.sm),
  //       Text(
  //         '这里会放个人介绍、项目经历、常用技术栈和联系方式。',
  //         style: Theme.of(context).textTheme.bodyMedium,
  //       ),
  //     ],
  //   );
  // }

  /// 构建聊天卡片
  Widget _buildChatCard(
    AuthController auth,
    int? remaining,
    AiChatState chatState,
  ) {
    return Card(
      child: SizedBox(
        height: 560,
        child: Column(
          children: [
            // 头部
            _ChatHeader(
              auth: auth,
              remaining: remaining,
              remainingMessages: chatState.remainingMessages,
              onShowHistory: _showSessionList,
              onCreateNew: _createNewSession,
            ),
            const Divider(height: 1),

            // 消息列表
            Expanded(child: _buildMessageList(chatState)),

            // 会话限制提示
            if (chatState.isSessionLimitReached)
              _SessionLimitBanner(onCreateNew: _createNewSession),

            // 输入栏
            _ChatInputBar(
              controller: _controller,
              auth: auth,
              remaining: remaining,
              sending: chatState.isSending,
              sessionLimitReached: chatState.isSessionLimitReached,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList(AiChatState chatState) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatState.messages.isEmpty) {
      return Center(
        child: Text(
          '有什么想问的？试试问我关于博客文章、技术栈或个人经历的问题',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: chatState.messages.length,
      itemBuilder:
          (context, index) => _ChatBubble(
            message: chatState.messages[index],
            isStreaming:
                chatState.isSending &&
                index == chatState.messages.length - 1 &&
                !chatState.messages[index].isMine,
          ),
    );
  }

  /// 显示会话列表
  Future<void> _showSessionList() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final sessions = await ref.read(apiClientProvider).fetchAiSessions(token);
      if (!mounted) return;

      final chatState = ref.read(aiChatProvider);
      showDialog(
        context: context,
        builder:
            (context) => _SessionListDialog(
              sessions: sessions,
              currentSessionId: chatState.sessionId,
              onSelect: (session) {
                Navigator.of(context).pop();
                _loadHistory(session.id);
              },
              onCreateNew: () {
                Navigator.of(context).pop();
                _createNewSession();
              },
              onDelete: (session) async {
                try {
                  await ref
                      .read(apiClientProvider)
                      .deleteAiSession(
                        accessToken: token,
                        sessionId: session.id,
                      );
                  if (!mounted) return;
                  // 如果删除的是当前会话，重置聊天状态
                  if (chatState.sessionId == session.id) {
                    ref.read(aiChatProvider.notifier).reset();
                  }
                } on ApiException catch (error) {
                  _showError(error.message);
                }
              },
            ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  /// 发送消息
  Future<void> _send() async {
    final auth = ref.read(authControllerProvider);
    final token = await auth.getValidAccessToken();
    if (!mounted) return;
    if (token == null) {
      context.go('/login?from=/about');
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final chatState = ref.read(aiChatProvider);
    if (chatState.remainingQuestions != null &&
        chatState.remainingQuestions! <= 0) {
      return;
    }

    _controller.clear();
    ref.read(aiChatProvider.notifier).addUserMessage(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final stream = ref
          .read(apiClientProvider)
          .sendAiMessageStream(
            accessToken: token,
            sessionId: chatState.sessionId,
            message: text,
          );

      await for (final event in stream) {
        if (!mounted) return;
        if (event.type == 'token') {
          ref.read(aiChatProvider.notifier).appendAiToken(event.data);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        } else if (event.type == 'done') {
          final reply = AiChatReply.fromJson(
            (jsonDecode(event.data) as Map).cast<String, dynamic>(),
          );
          ref
              .read(aiChatProvider.notifier)
              .completeAiReply(
                sessionId: reply.sessionId,
                remainingQuestions: reply.remainingQuestions,
                remainingMessages: reply.remainingMessages,
              );
          ref.invalidate(aiQuotaProvider);
        } else if (event.type == 'error') {
          final errorMsg = event.data;
          if (errorMsg.contains('提问次数') || errorMsg.contains('配额')) {
            ref.read(aiChatProvider.notifier).setError('今日提问次数已用完');
          } else {
            ref.read(aiChatProvider.notifier).setError(errorMsg);
          }
        }
      }
    } on ApiException catch (error) {
      if (error.message.contains('会话消息数已达上限')) {
        ref.read(aiChatProvider.notifier).setSessionLimitReached();
      }
      ref.read(aiChatProvider.notifier).removeAiPlaceholder();
      _showError(error.message);
    } catch (error) {
      ref.read(aiChatProvider.notifier).removeAiPlaceholder();
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ============================================================================
// 聊天头部组件
// ============================================================================

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.auth,
    required this.remaining,
    required this.remainingMessages,
    required this.onShowHistory,
    required this.onCreateNew,
  });

  final AuthController auth;
  final int? remaining;
  final int remainingMessages;
  final VoidCallback onShowHistory;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.smart_toy,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('AI 助手'),
      subtitle: Text(
        auth.isAuthenticated
            ? remaining != null
                ? '今日剩余 $remaining 次 · 会话剩余 $remainingMessages 条'
                : '正在加载配额...'
            : '登录后每天可以提问 10 次',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing:
          auth.isAuthenticated
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '历史会话',
                    onPressed: onShowHistory,
                    icon: const Icon(Icons.history),
                  ),
                  IconButton(
                    tooltip: '新建会话',
                    onPressed: onCreateNew,
                    icon: const Icon(Icons.add_comment),
                  ),
                ],
              )
              : null,
    );
  }
}

// ============================================================================
// 会话限制提示组件
// ============================================================================

class _SessionLimitBanner extends StatelessWidget {
  const _SessionLimitBanner({required this.onCreateNew});

  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 4,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '当前会话消息数已达上限',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onCreateNew,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建会话'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 聊天输入栏组件
// ============================================================================

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.auth,
    required this.remaining,
    required this.sending,
    required this.sessionLimitReached,
    required this.onSend,
  });

  final TextEditingController controller;
  final AuthController auth;
  final int? remaining;
  final bool sending;
  final bool sessionLimitReached;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend =
        auth.isAuthenticated &&
        !sending &&
        (remaining == null || remaining! > 0) &&
        !sessionLimitReached;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: canSend,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(hintText: _getHintText()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            tooltip: auth.isAuthenticated ? '发送' : '登录',
            onPressed: canSend ? onSend : null,
            icon:
                sending
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

  String _getHintText() {
    if (!auth.isAuthenticated) return '登录后和 AI 助手对话';
    if (remaining != null && remaining! <= 0) return '今日提问次数已用完';
    if (sessionLimitReached) return '请新建会话后继续';
    return '问问我的经历、文章或项目';
  }
}

// ============================================================================
// 会话列表弹窗组件
// ============================================================================

class _SessionListDialog extends StatefulWidget {
  const _SessionListDialog({
    required this.sessions,
    required this.currentSessionId,
    required this.onSelect,
    required this.onCreateNew,
    required this.onDelete,
  });

  final List<AiSessionItem> sessions;
  final String? currentSessionId;
  final ValueChanged<AiSessionItem> onSelect;
  final VoidCallback onCreateNew;
  final Future<void> Function(AiSessionItem) onDelete;

  @override
  State<_SessionListDialog> createState() => _SessionListDialogState();
}

class _SessionListDialogState extends State<_SessionListDialog> {
  late List<AiSessionItem> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List.of(widget.sessions);
  }

  Future<void> _deleteSession(AiSessionItem session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除会话'),
            content: Text('确定删除会话"${session.title}"吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    await widget.onDelete(session);
    if (mounted) {
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth < 480 ? screenWidth * 0.9 : 400.0;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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
                    onPressed: widget.onCreateNew,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建会话'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 会话列表
            if (_sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  '暂无历史会话',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final isCurrent = session.id == widget.currentSessionId;
                    final date = DateFormat(
                      'MM-dd HH:mm',
                    ).format(session.updatedAt);

                    return ListTile(
                      leading: Icon(
                        isCurrent
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color:
                            isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : null,
                      ),
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${session.messageCount} 条消息 · $date'),
                      selected: isCurrent,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _deleteSession(session),
                      ),
                      onTap: () => widget.onSelect(session),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 聊天气泡组件
// ============================================================================

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.isStreaming = false});

  final ChatMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              message.isMine
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border:
              message.isMine
                  ? null
                  : Border.all(color: colorScheme.outlineVariant),
        ),
        child:
            message.text.isEmpty && isStreaming
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '思考中...',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
                : message.isMine
                ? Text(
                  message.text,
                  style: TextStyle(color: colorScheme.onPrimary),
                )
                : MarkdownBody(
                  data: '${message.text}${isStreaming ? '▍' : ''}',
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: colorScheme.onSurface),
                    code: TextStyle(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
      ),
    );
  }
}
