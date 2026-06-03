// 管理后台 - 评论管理标签页
// 展示评论列表，支持筛选和状态管理
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/api_providers.dart';
import '../../../core/models.dart';
import '../admin_widgets.dart';

/// 管理后台 - 评论管理标签页
/// 展示评论列表，支持筛选和状态管理
class AdminCommentTab extends ConsumerStatefulWidget {
  const AdminCommentTab({super.key});

  @override
  ConsumerState<AdminCommentTab> createState() => AdminCommentTabState();
}

/// 评论管理标签页状态管理
/// 管理评论筛选条件和 CRUD 操作
class AdminCommentTabState extends ConsumerState<AdminCommentTab> {
  final _contentIdController = TextEditingController(); // 内容 ID 筛选框
  final _userIdController = TextEditingController(); // 用户 ID 筛选框
  AdminCommentStatus? _status; // 评论状态筛选
  AdminCommentQuery _query = const AdminCommentQuery(); // 当前查询条件

  @override
  void dispose() {
    _contentIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(adminCommentsProvider(_query));

    return comments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => AdminErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminCommentsProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionToolbar(
                title: '评论管理',
                actionLabel: '刷新',
                actionIcon: Icons.refresh,
                onAction: () => ref.invalidate(adminCommentsProvider(_query)),
              ),
              const SizedBox(height: 12),
              _CommentFilters(
                status: _status,
                contentIdController: _contentIdController,
                userIdController: _userIdController,
                onStatusChanged: (value) => setState(() => _status = value),
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 条评论',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const AdminEmptyPane(message: '暂无评论')
              else
                for (final comment in page.items) ...[
                  _CommentAdminRow(
                    comment: comment,
                    onDelete:
                        comment.deleted
                            ? null
                            : () => _deleteComment(context, comment),
                    onRestore:
                        comment.deleted
                            ? () => _setStatus(
                              context,
                              comment,
                              AdminCommentStatus.visible,
                            )
                            : null,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminCommentQuery(
        status: _status,
        contentId: _contentIdController.text.trim(),
        userId: _userIdController.text.trim(),
      );
    });
  }

  void _clearFilters() {
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

/// 评论筛选组件
class _CommentFilters extends StatelessWidget {
  const _CommentFilters({
    required this.status,
    required this.contentIdController,
    required this.userIdController,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
  });

  final AdminCommentStatus? status; // 评论状态筛选
  final TextEditingController contentIdController; // 内容 ID 控制器
  final TextEditingController userIdController; // 用户 ID 控制器
  final ValueChanged<AdminCommentStatus?> onStatusChanged; // 状态变更回调
  final VoidCallback onApply; // 应用筛选回调
  final VoidCallback onClear; // 清空筛选回调

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<AdminCommentStatus?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: '状态'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部状态')),
              DropdownMenuItem(
                value: AdminCommentStatus.visible,
                child: Text('可见'),
              ),
              DropdownMenuItem(
                value: AdminCommentStatus.deleted,
                child: Text('已删除'),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: contentIdController,
            decoration: const InputDecoration(labelText: '内容 ID'),
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
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('筛选'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: const Text('清空'),
        ),
      ],
    );
  }
}

/// 评论管理行组件
/// 展示单条评论的内容标题、评论正文、用户信息和操作按钮
class _CommentAdminRow extends StatelessWidget {
  const _CommentAdminRow({
    required this.comment,
    required this.onDelete,
    required this.onRestore,
  });

  final AdminCommentItem comment; // 评论数据
  final VoidCallback? onDelete; // 删除回调（已删除时为 null）
  final VoidCallback? onRestore; // 恢复回调（未删除时为 null）

  @override
  Widget build(BuildContext context) {
    final createdAt = formatAdminDate(comment.createdAt);
    final userLabel =
        comment.userNickname.isEmpty ? comment.userEmail : comment.userNickname;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mode_comment_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap:
                            () => context.go('/contents/${comment.contentId}'),
                        child: Text(
                          comment.contentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comment.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AdminCommentStatusChip(status: comment.status),
                AdminMetaText(icon: Icons.person_outline, text: userLabel),
                if (comment.userEmail.isNotEmpty)
                  AdminMetaText(icon: Icons.mail_outline, text: comment.userEmail),
                AdminMetaText(icon: Icons.schedule_outlined, text: createdAt),
                OutlinedButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('恢复'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
