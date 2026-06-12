// 管理后台 - 用户管理标签页
// 展示用户列表，支持筛选和编辑
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../state/state.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';
import '../user_editor_dialog.dart';

/// 管理后台 - 用户管理标签页
class AdminUserTab extends ConsumerStatefulWidget {
  const AdminUserTab({super.key});

  @override
  ConsumerState<AdminUserTab> createState() => AdminUserTabState();
}

class AdminUserTabState extends ConsumerState<AdminUserTab> {
  final _queryController = TextEditingController();
  AdminUserRole? _role;
  AdminUserStatus? _status;
  AdminUserQuery _query = const AdminUserQuery();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(_query));
    final currentUserId = ref.watch(authControllerProvider).user?.id;

    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminUsersProvider(_query)),
      ),
      data: (page) => _UserList(
        page: page,
        currentUserId: currentUserId,
        query: _query,
        queryController: _queryController,
        role: _role,
        status: _status,
        onRoleChanged: (value) => setState(() => _role = value),
        onStatusChanged: (value) => setState(() => _status = value),
        onApply: _applyFilters,
        onClear: _clearFilters,
        onEdit: (user) => _openUserEditor(context, user),
        onDisable: (user) => _disableUser(context, user),
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminUserQuery(
        query: _queryController.text.trim(),
        role: _role,
        status: _status,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _role = null;
      _status = null;
      _query = const AdminUserQuery();
    });
  }

  Future<void> _openUserEditor(BuildContext context, AdminUserItem user) async {
    final draft = await showDialog<AdminUserDraft>(
      context: context,
      builder: (context) => UserEditorDialog(user: user),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .updateAdminUser(accessToken: token, id: user.id, draft: draft);
      _refreshUserState();
      if (!context.mounted) return;
      showAdminSnack(context, '用户已保存');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  Future<void> _disableUser(BuildContext context, AdminUserItem user) async {
    if (!mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '禁用用户',
      message: '确认禁用「${user.nickname}」？',
      action: '禁用',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminUser(accessToken: token, id: user.id);
      _refreshUserState();
      if (!context.mounted) return;
      showAdminSnack(context, '用户已禁用');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  void _refreshUserState() {
    ref.invalidate(adminUsersProvider(_query));
    ref.invalidate(adminDashboardProvider);
  }
}

/// 用户列表组件
class _UserList extends StatelessWidget {
  const _UserList({
    required this.page,
    required this.currentUserId,
    required this.query,
    required this.queryController,
    required this.role,
    required this.status,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
    required this.onEdit,
    required this.onDisable,
  });

  final PageResult<AdminUserItem> page;
  final String? currentUserId;
  final AdminUserQuery query;
  final TextEditingController queryController;
  final AdminUserRole? role;
  final AdminUserStatus? status;
  final ValueChanged<AdminUserRole?> onRoleChanged;
  final ValueChanged<AdminUserStatus?> onStatusChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<AdminUserItem> onEdit;
  final ValueChanged<AdminUserItem> onDisable;

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
        final user = page.items[index - 1];
        return _UserAdminRow(
          user: user,
          isCurrentUser: user.id == currentUserId,
          onEdit: () => onEdit(user),
          onDisable: user.id == currentUserId || user.disabled
              ? null
              : () => onDisable(user),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionToolbar(
          title: '用户管理',
          actionLabel: '刷新',
          actionIcon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
          onAction: onApply,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        _UserFilters(
          queryController: queryController,
          role: role,
          status: status,
          onRoleChanged: onRoleChanged,
          onStatusChanged: onStatusChanged,
          onApply: onApply,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          '共 ${page.total} 个用户',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (page.items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无用户'),
        ],
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    );
  }
}

/// 用户筛选组件
class _UserFilters extends StatelessWidget {
  const _UserFilters({
    required this.queryController,
    required this.role,
    required this.status,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController queryController;
  final AdminUserRole? role;
  final AdminUserStatus? status;
  final ValueChanged<AdminUserRole?> onRoleChanged;
  final ValueChanged<AdminUserStatus?> onStatusChanged;
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
            decoration: const InputDecoration(labelText: '邮箱 / 昵称'),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<AdminUserRole?>(
            initialValue: role,
            decoration: const InputDecoration(labelText: '角色'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部角色')),
              DropdownMenuItem(value: AdminUserRole.user, child: Text('普通用户')),
              DropdownMenuItem(value: AdminUserRole.admin, child: Text('管理员')),
            ],
            onChanged: onRoleChanged,
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<AdminUserStatus?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: '状态'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部状态')),
              DropdownMenuItem(
                value: AdminUserStatus.active,
                child: Text('启用'),
              ),
              DropdownMenuItem(
                value: AdminUserStatus.disabled,
                child: Text('禁用'),
              ),
            ],
            onChanged: onStatusChanged,
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

/// 用户管理行组件
class _UserAdminRow extends StatelessWidget {
  const _UserAdminRow({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
    required this.onDisable,
  });

  final AdminUserItem user;
  final bool isCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback? onDisable;

  @override
  Widget build(BuildContext context) {
    final createdAt = formatAdminDate(user.createdAt);

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
            _buildActions(context, createdAt),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminUserAvatar(user: user),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (isCurrentUser) const Chip(label: Text('当前账号')),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  user.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, String createdAt) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AdminUserRoleChip(role: user.role),
        AdminUserStatusChip(status: user.status),
        if (user.blogUrl.isNotEmpty)
          AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 18), text: user.blogUrl),
        AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18), text: createdAt),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit01, size: 18),
          label: const Text('编辑'),
        ),
        OutlinedButton.icon(
          onPressed: onDisable,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedBlocked, size: 18),
          label: const Text('禁用'),
        ),
      ],
    );
  }
}

/// 管理后台用户头像组件
class _AdminUserAvatar extends StatelessWidget {
  const _AdminUserAvatar({required this.user});

  final AdminUserItem user;

  @override
  Widget build(BuildContext context) {
    final fallback =
        user.nickname.isEmpty ? '?' : user.nickname.substring(0, 1);
    if (user.avatarUrl.isEmpty) {
      return CircleAvatar(radius: 24, child: Text(fallback));
    }
    return CircleAvatar(
      radius: 24,
      backgroundImage: NetworkImage(user.avatarUrl),
      onBackgroundImageError: (_, _) {},
      child: null,
    );
  }
}
