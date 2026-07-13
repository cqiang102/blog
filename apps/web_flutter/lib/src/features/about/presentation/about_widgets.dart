part of '../about_page.dart';

class _AboutIdentityPanel extends StatelessWidget {
  const _AboutIdentityPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.88),
              scheme.secondaryContainer.withValues(alpha: 0.76),
              scheme.surfaceContainerLow,
            ],
            stops: const [0, 0.44, 1],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ABOUT · DIGITAL GARDEN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: design.lavender,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Semantics(
                  image: true,
                  label: '沐凉的头像',
                  excludeSemantics: true,
                  child: Container(
                    width: compact ? 88 : 104,
                    height: compact ? 88 : 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 4),
                      boxShadow: [design.cardShadow],
                      image: const DecorationImage(
                        image: AssetImage('assets/images/lacia.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  '你好，我是沐凉。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '这里记录 Flutter、后端与 AI 的工程实践，也收藏照片、阅读和普通生活。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  Chip(label: Text('Flutter')),
                  Chip(label: Text('Java')),
                  Chip(label: Text('AI')),
                  Chip(label: Text('生活记录')),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedQuoteDown,
                      size: 20,
                      color: design.rose,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '写代码，也记录生活。',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.go('/contents'),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedBookOpen01,
                    size: 18,
                  ),
                  label: const Text('看看最近写了什么'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: const AssetImage('assets/images/lacia.png'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      title: const Text('问问沐凉'),
      subtitle: Text(
        auth.isAuthenticated
            ? remaining != null
                  ? '今日剩余 $remaining 次 · 会话剩余 $remainingMessages 条'
                  : '正在加载...'
            : '登录后每天可以提问 10 次',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: auth.isAuthenticated
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '历史会话',
                  onPressed: onShowHistory,
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01),
                ),
                IconButton(
                  tooltip: '新建会话',
                  onPressed: onCreateNew,
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
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
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
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
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 18),
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
            icon: sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const HugeIcon(icon: HugeIcons.strokeRoundedSent),
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
      builder: (context) => AlertDialog(
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
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      size: 18,
                    ),
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
                      leading: HugeIcon(
                        icon: isCurrent
                            ? HugeIcons.strokeRoundedMessage01
                            : HugeIcons.strokeRoundedMessage01,
                        color: isCurrent
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
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete01,
                          size: 20,
                        ),
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
          alignment: message.isMine
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: message.isMine
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: message.isMine
                  ? null
                  : Border.all(color: colorScheme.outlineVariant),
            ),
            child: message.text.isEmpty && isStreaming
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
                      AppMotion.reduce(context)
                          ? Text(
                              '思考中...',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            )
                          : AnimatedTextKit(
                              isRepeatingAnimation: true,
                              repeatForever: true,
                              animatedTexts: [
                                WavyAnimatedText(
                                  '思考中...',
                                  textStyle: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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
        )
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
        .slideX(
          begin: message.isMine ? 0.08 : -0.08,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
