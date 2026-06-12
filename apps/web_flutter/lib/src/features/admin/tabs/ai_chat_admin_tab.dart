// 管理后台 - AI 聊天管理标签页
// 展示 AI 会话列表，支持查看详情和筛选
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../state/state.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';

/// 管理后台 - AI 聊天管理标签页
class AdminAiChatTab extends ConsumerStatefulWidget {
  const AdminAiChatTab({super.key});

  @override
  ConsumerState<AdminAiChatTab> createState() => AdminAiChatTabState();
}

class AdminAiChatTabState extends ConsumerState<AdminAiChatTab> {
  final _queryController = TextEditingController();
  final _userIdController = TextEditingController();
  AdminAiChatQuery _query = const AdminAiChatQuery();

  @override
  void dispose() {
    _queryController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(adminAiChatsProvider(_query));

    return chats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminAiChatsProvider(_query)),
      ),
      data: (page) => _AiChatList(
        page: page,
        query: _query,
        queryController: _queryController,
        userIdController: _userIdController,
        onApply: _applyFilters,
        onClear: _clearFilters,
        onOpen: (session) => _openChatDetail(context, session),
        onDelete: (session) => _deleteChat(context, session),
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminAiChatQuery(
        query: _queryController.text.trim(),
        userId: _userIdController.text.trim(),
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _userIdController.clear();
      _query = const AdminAiChatQuery();
    });
  }

  Future<void> _openChatDetail(
    BuildContext context,
    AdminAiChatSessionItem session,
  ) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final detail = await ref
          .read(apiClientProvider)
          .fetchAdminAiChatDetail(accessToken: token, id: session.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _AiChatDetailDialog(detail: detail),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      showAdminSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      showAdminSnack(context, error.toString());
    }
  }

  Future<void> _deleteChat(
    BuildContext context,
    AdminAiChatSessionItem session,
  ) async {
    final title = session.title.isEmpty ? '未命名会话' : session.title;
    if (!mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除 AI 会话',
      message: '确认删除「$title」及其消息记录？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminAiChat(accessToken: token, id: session.id);
      _refreshAiChatState();
      if (!context.mounted) return;
      showAdminSnack(context, 'AI 会话已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  void _refreshAiChatState() {
    ref.invalidate(adminAiChatsProvider(_query));
    ref.invalidate(adminDashboardProvider);
  }
}

/// AI 聊天列表组件
class _AiChatList extends StatelessWidget {
  const _AiChatList({
    required this.page,
    required this.query,
    required this.queryController,
    required this.userIdController,
    required this.onApply,
    required this.onClear,
    required this.onOpen,
    required this.onDelete,
  });

  final PageResult<AdminAiChatSessionItem> page;
  final AdminAiChatQuery query;
  final TextEditingController queryController;
  final TextEditingController userIdController;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<AdminAiChatSessionItem> onOpen;
  final ValueChanged<AdminAiChatSessionItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        final session = page.items[index - 1];
        return _AiChatAdminRow(
          session: session,
          onOpen: () => onOpen(session),
          onDelete: () => onDelete(session),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionToolbar(
          title: 'AI 聊天记录',
          actionLabel: '刷新',
          actionIcon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
          onAction: onApply,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        _AiChatFilters(
          queryController: queryController,
          userIdController: userIdController,
          onApply: onApply,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          '共 ${page.total} 个 AI 会话',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (page.items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无 AI 聊天记录'),
        ],
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    );
  }
}

/// AI 聊天筛选组件
class _AiChatFilters extends StatelessWidget {
  const _AiChatFilters({
    required this.queryController,
    required this.userIdController,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController queryController;
  final TextEditingController userIdController;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm + 4,
      runSpacing: AppSpacing.sm + 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: queryController,
            decoration: const InputDecoration(labelText: '标题 / 用户'),
          ),
        ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: userIdController,
            decoration: const InputDecoration(labelText: '用户 ID'),
          ),
        ),
        FilledButton.icon(
          onPressed: onApply,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedFilter),
          label: const Text('筛选'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
          label: const Text('清空'),
        ),
      ],
    );
  }
}

/// AI 聊天管理行组件
class _AiChatAdminRow extends StatelessWidget {
  const _AiChatAdminRow({
    required this.session,
    required this.onOpen,
    required this.onDelete,
  });

  final AdminAiChatSessionItem session;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = session.title.isEmpty ? '未命名会话' : session.title;
    final userLabel =
        session.userNickname.isEmpty ? session.userEmail : session.userNickname;
    final lastMessage =
        session.lastMessage.isEmpty ? '暂无消息' : session.lastMessage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图标 + 信息
            _buildHeader(context, title, lastMessage),
            const SizedBox(height: AppSpacing.sm + 4),

            // 标签和操作
            _buildActions(context, userLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, String lastMessage) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: const AssetImage('assets/images/lacia.png'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                lastMessage,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, String userLabel) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 18), text: userLabel),
        if (session.userEmail.isNotEmpty)
          AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedMail01, size: 18), text: session.userEmail),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedMessage01, size: 18),
          text: '${session.messageCount} 条消息',
        ),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 18),
          text: formatAdminDate(session.updatedAt),
        ),
        OutlinedButton.icon(
          onPressed: onOpen,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedView, size: 18),
          label: const Text('查看'),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: 18),
          label: const Text('删除'),
        ),
      ],
    );
  }
}

/// AI 聊天详情对话框
class _AiChatDetailDialog extends StatelessWidget {
  const _AiChatDetailDialog({required this.detail});

  final AdminAiChatDetail detail;

  @override
  Widget build(BuildContext context) {
    final session = detail.session;
    final title = session.title.isEmpty ? '未命名会话' : session.title;
    final userLabel =
        session.userNickname.isEmpty ? session.userEmail : session.userNickname;

    return AlertDialog(
      title: const Text('AI 聊天详情'),
      content: SizedBox(
        width: 760,
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 元信息
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 18), text: userLabel),
                if (session.userEmail.isNotEmpty)
                  AdminMetaText(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedMail01, size: 18),
                    text: session.userEmail,
                  ),
                AdminMetaText(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedMessage01, size: 18),
                  text: '${session.messageCount} 条消息',
                ),
                AdminMetaText(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18),
                  text: formatAdminDate(session.createdAt),
                ),
              ],
            ),
            const Divider(height: 28),

            // 消息列表
            Expanded(
              child: detail.messages.isEmpty
                  ? const AdminEmptyPane(message: '暂无消息')
                  : ListView.separated(
                      itemCount: detail.messages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _AiChatMessageRow(message: detail.messages[index]),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedTick01),
          label: const Text('关闭'),
        ),
      ],
    );
  }
}

/// AI 聊天消息行组件
class _AiChatMessageRow extends StatelessWidget {
  const _AiChatMessageRow({required this.message});

  final AdminAiChatMessageItem message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (message.role) {
      AiChatMessageRole.user => scheme.secondaryContainer,
      AiChatMessageRole.assistant => scheme.primaryContainer,
      AiChatMessageRole.tool => scheme.tertiaryContainer,
      AiChatMessageRole.system => scheme.surfaceContainerHighest,
    };
    final tokenText = [
      if (message.promptTokens > 0) 'prompt ${message.promptTokens}',
      if (message.completionTokens > 0)
        'completion ${message.completionTokens}',
    ].join(' / ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 元信息
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _AiRoleChip(role: message.role),
                if (message.auditStatus == 'BLOCKED')
                  _AuditStatusChip(
                    label: '已屏蔽',
                    color: scheme.error,
                    reason: message.auditReason,
                  )
                else if (message.auditStatus == 'VISIBLE')
                  _AuditStatusChip(
                    label: '正常',
                    color: scheme.primary,
                  ),
                AdminMetaText(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18),
                  text: formatAdminDate(message.createdAt),
                ),
                if (message.toolName.isNotEmpty)
                  AdminMetaText(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedSettings01, size: 18),
                    text: message.toolName,
                  ),
                if (tokenText.isNotEmpty)
                  AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedDataRecovery, size: 18), text: tokenText),
              ],
            ),
            const SizedBox(height: 10),

            // 消息内容
            SelectableText(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 消息角色标签组件
class _AiRoleChip extends StatelessWidget {
  const _AiRoleChip({required this.role});

  final AiChatMessageRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      AiChatMessageRole.user => scheme.secondaryContainer,
      AiChatMessageRole.assistant => scheme.primaryContainer,
      AiChatMessageRole.tool => scheme.tertiaryContainer,
      AiChatMessageRole.system => scheme.surfaceContainerHighest,
    };
    return Chip(label: Text(role.label), backgroundColor: color);
  }
}

/// 审核状态标签组件
class _AuditStatusChip extends StatelessWidget {
  const _AuditStatusChip({
    required this.label,
    required this.color,
    this.reason,
  });

  final String label;
  final Color color;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reason ?? '',
      child: Chip(
        label: Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
        backgroundColor: color.withValues(alpha: 0.12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }
}
