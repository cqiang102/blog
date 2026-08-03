// AI 聊天页模块
// 支持 SSE 流式响应、会话管理、配额显示和 40 条消息限制
// 使用 Riverpod 管理状态，替代 setState
import 'dart:math' as math;
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../state/state.dart';
import '../../widgets/widgets.dart';
import '../../auth/auth_controller.dart';
import '../../core/constants.dart';
import '../../core/models.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_motion.dart';
import 'application/ai_chat_controller.dart';

part 'presentation/about_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(aiChatControllerProvider.notifier).loadLatestSession();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // 仅当用户已经接近底部时才自动跟随滚动；如果用户向上滚动超过 150px，
    // 说明其正在回看历史消息，流式更新不应强行把视图拉回底部。
    final nearBottom = position.pixels >= position.maxScrollExtent - 150;
    if (!nearBottom) return;
    _scrollController.animateTo(
      position.maxScrollExtent,
      duration: AppAnimations.fast,
      curve: AppAnimations.defaultCurve,
    );
  }

  /// 创建新会话
  Future<void> _createNewSession() async {
    await ref.read(aiChatControllerProvider.notifier).createNewSession();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(aiChatControllerProvider, (previous, next) {
      if (previous?.messages != next.messages) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      if (next.error != null && previous?.error != next.error) {
        final message = next.error!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showError(message);
        });
      }
    });
    final auth = ref.watch(authControllerProvider);
    final quota = auth.isAuthenticated ? ref.watch(aiQuotaProvider) : null;
    final quotaRemaining = quota?.maybeWhen(
      data: (value) => value.remaining,
      orElse: () => null,
    );
    final chatState = ref.watch(aiChatControllerProvider);
    final remaining = chatState.remainingQuestions ?? quotaRemaining;

    return AppPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final chatHeight = math.max(
            360.0,
            viewportHeight - kToolbarHeight - AppSpacing.lg * 2,
          );
          final wide = constraints.maxWidth >= kWideBreakpoint;

          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                title: Text('关于与问答'),
                actions: [
                  AppThemeToggle(),
                  SizedBox(width: AppSpacing.sm),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    child: wide
                        ? SizedBox(
                            height: chatHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(
                                  width: 320,
                                  child: _AboutIdentityPanel(),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: _buildChatCard(
                                    auth,
                                    remaining,
                                    chatState,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _AboutIdentityPanel(compact: true),
                              const SizedBox(height: AppSpacing.lg),
                              SizedBox(
                                height: chatHeight,
                                child: _buildChatCard(
                                  auth,
                                  remaining,
                                  chatState,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建聊天卡片
  Widget _buildChatCard(
    AuthController auth,
    int? remaining,
    AiChatState chatState,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
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
    );
  }

  /// 构建消息列表
  Widget _buildMessageList(AiChatState chatState) {
    if (chatState.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatState.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            '有什么想问的？试试问我关于博客文章、技术栈或个人经历的问题',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) => _ChatBubble(
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
    final controller = ref.read(aiChatControllerProvider.notifier);
    final sessions = await controller.fetchSessions();
    if (!mounted) return;

    final chatState = ref.read(aiChatControllerProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SessionListDialog(
        sessions: sessions,
        currentSessionId: chatState.sessionId,
        onSelect: (session) {
          Navigator.of(dialogContext).pop();
          controller.loadHistory(session.id);
        },
        onCreateNew: () {
          Navigator.of(dialogContext).pop();
          controller.createNewSession();
        },
        onDelete: (session) => controller.deleteSession(session.id),
      ),
    );
  }

  /// 发送消息
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final outcome = await ref
        .read(aiChatControllerProvider.notifier)
        .send(text);
    if (!mounted) return;
    switch (outcome) {
      case AiChatSendOutcome.started:
        _controller.clear();
      case AiChatSendOutcome.loginRequired:
        context.go('/login?from=/about');
      case AiChatSendOutcome.ignored:
        break;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
