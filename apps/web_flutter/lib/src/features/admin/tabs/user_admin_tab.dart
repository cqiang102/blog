// 管理后台 - 用户管理标签页
// 展示用户列表，支持筛选和编辑
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_providers.dart';
import '../../../core/models.dart';
import '../admin_widgets.dart';
import '../user_editor_dialog.dart';

/// 管理后台 - 用户管理标签页
/// 展示用户列表，支持筛选和编辑
class AdminUserTab extends ConsumerStatefulWidget {
  const AdminUserTab({super.key});

  @override
  ConsumerState<AdminUserTab> createState() => AdminUserTabState();
}

/// 用户管理标签页状态管理
class AdminUserTabState extends ConsumerState<AdminUserTab> {
  final _queryController = TextEditingController(); // 搜索关键词输入框
  AdminUserRole? _role; // 角色筛选
  AdminUserStatus? _status; // 状态筛选
  AdminUserQuery _query = const AdminUserQuery(); // 当前查询条件

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
      error:
          (error, stackTrace) => AdminErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminUsersProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionToolbar(
                title: '用户管理',
                actionLabel: '刷新',
                actionIcon: Icons.refresh,
                onAction: () => ref.invalidate(adminUsersProvider(_query)),
              ),
              const SizedBox(height: 12),
              _UserFilters(
                queryController: _queryController,
                role: _role,
                status: _status,
                onRoleChanged: (value) => setState(() => _role = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 个用户',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const AdminEmptyPane(message: '暂无用户')
              else
                for (final user in page.items) ...[
                  _UserAdminRow(
                    user: user,
                    isCurrentUser: user.id == currentUserId,
                    onEdit: () => _openUserEditor(context, user),
                    onDisable:
                        user.id == currentUserId || user.disabled
                            ? null
                            : () => _disableUser(context, user),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
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

  final TextEditingController queryController; // 搜索关键词控制器
  final AdminUserRole? role; // 角色筛选
  final AdminUserStatus? status; // 状态筛选
  final ValueChanged<AdminUserRole?> onRoleChanged; // 角色变更回调
  final ValueChanged<AdminUserStatus?> onStatusChanged; // 状态变更回调
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

/// 用户管理行组件
/// 展示单条用户的头像、昵称、邮箱、角色、状态和操作按钮
class _UserAdminRow extends StatelessWidget {
  const _UserAdminRow({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
    required this.onDisable,
  });

  final AdminUserItem user; // 用户数据
  final bool isCurrentUser; // 是否为当前登录用户
  final VoidCallback onEdit; // 编辑回调
  final VoidCallback? onDisable; // 禁用回调（当前用户或已禁用时为 null）

  @override
  Widget build(BuildContext context) {
    final createdAt = formatAdminDate(user.createdAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminUserAvatar(user: user),
                const SizedBox(width: 12),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                      ),
                      if (user.bio.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          user.bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                AdminUserRoleChip(role: user.role),
                AdminUserStatusChip(status: user.status),
                if (user.blogUrl.isNotEmpty)
                  AdminMetaText(icon: Icons.link_outlined, text: user.blogUrl),
                AdminMetaText(icon: Icons.schedule_outlined, text: createdAt),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed: onDisable,
                  icon: const Icon(Icons.block),
                  label: const Text('禁用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 管理后台用户头像组件
/// 显示用户头像，无头像时显示昵称首字符
class _AdminUserAvatar extends StatelessWidget {
  const _AdminUserAvatar({required this.user});

  final AdminUserItem user; // 用户数据

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
