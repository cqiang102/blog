// 管理后台 - 评论管理标签页
// 展示评论列表，支持筛选和状态管理
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../state/state.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';

/// 管理后台 - 评论管理标签页
class AdminCommentTab extends ConsumerStatefulWidget {
  const AdminCommentTab({super.key});

  @override
  ConsumerState<AdminCommentTab> createState() => AdminCommentTabState();
}

class AdminCommentTabState extends ConsumerState<AdminCommentTab> {
  final _contentIdController = TextEditingController();
  final _userIdController = TextEditingController();
  Timer? _filterDebounce;
  AdminCommentStatus? _status;
  AdminCommentQuery _query = const AdminCommentQuery();

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _contentIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(adminCommentsProvider(_query));

    return comments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminCommentsProvider(_query)),
      ),
      data: (page) => _CommentList(
        page: page,
        status: _status,
        contentIdController: _contentIdController,
        userIdController: _userIdController,
        onStatusChanged: _changeStatus,
        onFilterTextChanged: _scheduleFilters,
        onApply: _applyFilters,
        onClear: _clearFilters,
        onDelete: (comment) => _deleteComment(context, comment),
        onRestore: (comment) =>
            _setStatus(context, comment, AdminCommentStatus.visible),
      ),
    );
  }

  void _scheduleFilters(String _) {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _applyFilters();
    });
  }

  void _changeStatus(AdminCommentStatus? value) {
    _filterDebounce?.cancel();
    setState(() {
      _status = value;
      _query = _currentQuery();
    });
  }

  AdminCommentQuery _currentQuery() {
    return AdminCommentQuery(
      status: _status,
      contentId: _contentIdController.text.trim(),
      userId: _userIdController.text.trim(),
    );
  }

  void _applyFilters() {
    _filterDebounce?.cancel();
    final next = _currentQuery();
    if (next == _query) return;
    setState(() => _query = next);
  }

  void _clearFilters() {
    _filterDebounce?.cancel();
    setState(() {
      _status = null;
      _contentIdController.clear();
      _userIdController.clear();
      _query = const AdminCommentQuery();
    });
  }

  Future<void> _deleteComment(
    BuildContext context,
    AdminCommentItem comment,
  ) async {
    if (!mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除评论',
      message: '确认删除这条评论？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminComment(accessToken: token, id: comment.id);
      _refreshCommentState(comment.contentId);
      if (!context.mounted) return;
      showAdminSnack(context, '评论已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    AdminCommentItem comment,
    AdminCommentStatus status,
  ) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .updateAdminCommentStatus(
            accessToken: token,
            id: comment.id,
            status: status,
          );
      _refreshCommentState(comment.contentId);
      if (!context.mounted) return;
      showAdminSnack(
        context,
        status == AdminCommentStatus.visible ? '评论已恢复' : '评论已删除',
      );
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  void _refreshCommentState(String contentId) {
    ref.invalidate(adminCommentsProvider(_query));
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(contentDetailProvider(contentId));
    ref.invalidate(commentsProvider(contentId));
  }
}

/// 评论列表组件
class _CommentList extends StatelessWidget {
  const _CommentList({
    required this.page,
    required this.status,
    required this.contentIdController,
    required this.userIdController,
    required this.onStatusChanged,
    required this.onFilterTextChanged,
    required this.onApply,
    required this.onClear,
    required this.onDelete,
    required this.onRestore,
  });

  final PageResult<AdminCommentItem> page;
  final AdminCommentStatus? status;
  final TextEditingController contentIdController;
  final TextEditingController userIdController;
  final ValueChanged<AdminCommentStatus?> onStatusChanged;
  final ValueChanged<String> onFilterTextChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<AdminCommentItem> onDelete;
  final ValueChanged<AdminCommentItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        final comment = page.items[index - 1];
        return _CommentAdminRow(
          comment: comment,
          onDelete: comment.deleted ? null : () => onDelete(comment),
          onRestore: comment.deleted ? () => onRestore(comment) : null,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentFilters(
          status: status,
          contentIdController: contentIdController,
          userIdController: userIdController,
          onStatusChanged: onStatusChanged,
          onFilterTextChanged: onFilterTextChanged,
          onApply: onApply,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          '共 ${page.total} 条评论',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (page.items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无评论'),
        ],
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    );
  }
}

/// 评论筛选组件
class _CommentFilters extends StatelessWidget {
  const _CommentFilters({
    required this.status,
    required this.contentIdController,
    required this.userIdController,
    required this.onStatusChanged,
    required this.onFilterTextChanged,
    required this.onApply,
    required this.onClear,
  });

  final AdminCommentStatus? status;
  final TextEditingController contentIdController;
  final TextEditingController userIdController;
  final ValueChanged<AdminCommentStatus?> onStatusChanged;
  final ValueChanged<String> onFilterTextChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        status != null ||
        contentIdController.text.trim().isNotEmpty ||
        userIdController.text.trim().isNotEmpty;

    return AdminFilterBar(
      onReset: onClear,
      resetEnabled: hasFilters,
      items: [
        AdminFilterItem(
          width: 152,
          child: DropdownButtonFormField<AdminCommentStatus?>(
            key: ValueKey(status),
            initialValue: status,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '状态 · 全部',
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('状态 · 全部')),
              DropdownMenuItem(
                value: AdminCommentStatus.visible,
                child: Text('状态 · 可见'),
              ),
              DropdownMenuItem(
                value: AdminCommentStatus.deleted,
                child: Text('状态 · 已删除'),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        AdminFilterItem(
          child: TextField(
            controller: contentIdController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '按内容 ID 筛选',
            ),
            textInputAction: TextInputAction.search,
            onChanged: onFilterTextChanged,
            onSubmitted: (_) => onApply(),
          ),
        ),
        AdminFilterItem(
          child: TextField(
            controller: userIdController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '按用户 ID 筛选',
            ),
            textInputAction: TextInputAction.search,
            onChanged: onFilterTextChanged,
            onSubmitted: (_) => onApply(),
          ),
        ),
      ],
    );
  }
}

/// 评论管理行组件
class _CommentAdminRow extends StatelessWidget {
  const _CommentAdminRow({
    required this.comment,
    required this.onDelete,
    required this.onRestore,
  });

  final AdminCommentItem comment;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final createdAt = formatAdminDate(comment.createdAt);
    final userLabel = comment.userNickname.isEmpty
        ? comment.userEmail
        : comment.userNickname;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 评论内容
            _buildContent(context),
            const SizedBox(height: AppSpacing.sm + 4),

            // 元信息和当前可执行操作
            _buildFooter(context, userLabel, createdAt),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedMessage01,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.go('/contents/${comment.contentId}'),
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  comment.contentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                comment.body,
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

  Widget _buildFooter(
    BuildContext context,
    String userLabel,
    String createdAt,
  ) {
    return AdminRowFooter(
      metadata: [
        AdminCommentStatusChip(status: comment.status),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 18),
          text: userLabel,
        ),
        if (comment.userEmail.isNotEmpty)
          AdminMetaText(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMail01, size: 18),
            text: comment.userEmail,
          ),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18),
          text: createdAt,
        ),
      ],
      actions: [_buildStateAction(context)],
    );
  }

  Widget _buildStateAction(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (comment.deleted) {
      return FilledButton.icon(
        onPressed: onRestore,
        style: adminCompactButtonStyle(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
        ),
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedArchiveRestore,
          size: 18,
        ),
        label: const Text('恢复'),
      );
    }

    return TextButton.icon(
      onPressed: onDelete,
      style: adminCompactButtonStyle(foregroundColor: scheme.error),
      icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: 18),
      label: const Text('删除'),
    );
  }
}
