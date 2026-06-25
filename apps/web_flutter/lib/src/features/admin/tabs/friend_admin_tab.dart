// 管理后台 - 友链管理标签页
// 展示友链列表，支持新增、编辑和删除
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../core/media_url.dart';
import '../../../state/state.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';
import '../friend_editor_dialog.dart';

/// 友链管理标签页
class AdminFriendTab extends ConsumerWidget {
  const AdminFriendTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(adminFriendsProvider);

    return friends.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminFriendsProvider),
      ),
      data: (items) => _FriendList(
        items: items,
        onOpenEditor: (friend) =>
            _openFriendEditor(context, ref, friend: friend),
        onDelete: (friend) => _deleteFriend(context, ref, friend),
      ),
    );
  }

  Future<void> _openFriendEditor(
    BuildContext context,
    WidgetRef ref, {
    FriendLink? friend,
  }) async {
    final draft = await showDialog<FriendDraft>(
      context: context,
      builder: (context) => FriendEditorDialog(friend: friend),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (friend == null) {
        await api.createAdminFriend(accessToken: token, draft: draft);
      } else {
        await api.updateAdminFriend(
          accessToken: token,
          id: friend.id,
          draft: draft,
        );
      }
      _refreshFriendState(ref);
      if (!context.mounted) return;
      showAdminSnack(context, friend == null ? '朋友已创建' : '朋友已保存');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  Future<void> _deleteFriend(
    BuildContext context,
    WidgetRef ref,
    FriendLink friend,
  ) async {
    if (!context.mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除朋友',
      message: '确认删除「${friend.name}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminFriend(accessToken: token, id: friend.id);
      _refreshFriendState(ref);
      if (!context.mounted) return;
      showAdminSnack(context, '朋友已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  void _refreshFriendState(WidgetRef ref) {
    ref.invalidate(adminFriendsProvider);
    ref.invalidate(friendsProvider);
    ref.invalidate(adminDashboardProvider);
  }
}

/// 友链列表组件
class _FriendList extends StatelessWidget {
  const _FriendList({
    required this.items,
    required this.onOpenEditor,
    required this.onDelete,
  });

  final List<FriendLink> items;
  final ValueChanged<FriendLink?> onOpenEditor;
  final ValueChanged<FriendLink> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        final friend = items[index - 1];
        return _FriendAdminRow(
          friend: friend,
          onEdit: () => onOpenEditor(friend),
          onDelete: () => onDelete(friend),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionToolbar(
          title: '朋友管理',
          actionLabel: '新增朋友',
          actionIcon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
          onAction: () => onOpenEditor(null),
        ),
        if (items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无朋友'),
        ],
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    );
  }
}

/// 友链管理行组件
class _FriendAdminRow extends StatelessWidget {
  const _FriendAdminRow({
    required this.friend,
    required this.onEdit,
    required this.onDelete,
  });

  final FriendLink friend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：头像 + 信息
            _buildHeader(context),
            const SizedBox(height: AppSpacing.sm + 4),

            // 标签和操作
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FriendAvatar(friend: friend),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                friend.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                friend.intro.isEmpty ? friend.siteUrl : friend.intro,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                friend.siteUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (friend.updatedAt case final updatedAt?) ...[
                const SizedBox(height: 6),
                Text(
                  '更新于 ${formatAdminDate(updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          avatar: HugeIcon(
            icon: friend.visible
                ? HugeIcons.strokeRoundedView
                : HugeIcons.strokeRoundedViewOff,
            size: 18,
          ),
          label: Text(friend.visible ? '公开' : '隐藏'),
        ),
        Chip(label: Text('排序 ${friend.sortOrder}')),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit01, size: 18),
          label: const Text('编辑'),
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

/// 友链头像组件
class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friend});

  final FriendLink friend;

  @override
  Widget build(BuildContext context) {
    final fallback = friend.name.isEmpty ? '?' : friend.name.substring(0, 1);
    if (friend.avatarUrl.isEmpty) {
      return CircleAvatar(radius: 24, child: Text(fallback));
    }
    return CircleAvatar(
      radius: 24,
      backgroundImage: NetworkImage(resolveMediaUrl(friend.avatarUrl)),
      onBackgroundImageError: (_, _) {},
      child: null,
    );
  }
}
