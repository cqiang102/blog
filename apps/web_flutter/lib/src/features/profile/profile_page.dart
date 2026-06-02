import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/models.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              AppBar(
                title: const Text('个人中心'),
                actions: [
                  IconButton(
                    tooltip: '退出登录',
                    onPressed:
                        auth.isBusy
                            ? null
                            : () => ref.read(authControllerProvider).logout(),
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.person), text: '资料'),
                  Tab(icon: Icon(Icons.comment), text: '评论'),
                  Tab(icon: Icon(Icons.favorite), text: '点赞'),
                  Tab(icon: Icon(Icons.history), text: '浏览'),
                ],
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProfileForm(),
            _RecordList(type: 'comments', label: '评论'),
            _RecordList(type: 'likes', label: '点赞'),
            _RecordList(type: 'views', label: '浏览'),
          ],
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _blogUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _seededUserId;
  bool _changingPassword = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _blogUrlController.dispose();
    _emailController.dispose();
    _avatarUrlController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    if (user != null && _seededUserId != user.id) {
      _seed(user);
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CircleAvatar(
          radius: 44,
          backgroundImage:
              user?.avatarUrl == null ? null : NetworkImage(user!.avatarUrl!),
          child:
              user?.avatarUrl == null
                  ? const Icon(Icons.person, size: 44)
                  : null,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nicknameController,
          decoration: const InputDecoration(labelText: '昵称'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioController,
          decoration: const InputDecoration(labelText: '简介'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _blogUrlController,
          decoration: const InputDecoration(labelText: '博客地址'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _avatarUrlController,
          decoration: const InputDecoration(labelText: '头像 URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: '邮箱'),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: auth.isBusy ? null : _save,
            icon:
                auth.isBusy
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          '修改密码',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _oldPasswordController,
          decoration: const InputDecoration(labelText: '当前密码'),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPasswordController,
          decoration: const InputDecoration(
            labelText: '新密码',
            hintText: '至少6个字符',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(labelText: '确认新密码'),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _changingPassword ? null : _changePassword,
            icon:
                _changingPassword
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.lock_outline),
            label: const Text('修改密码'),
          ),
        ),
      ],
    );
  }

  void _seed(UserProfile user) {
    _seededUserId = user.id;
    _nicknameController.text = user.nickname;
    _bioController.text = user.bio ?? '';
    _blogUrlController.text = user.blogUrl ?? '';
    _emailController.text = user.email;
    _avatarUrlController.text = user.avatarUrl ?? '';
  }

  Future<void> _save() async {
    try {
      await ref
          .read(authControllerProvider)
          .updateProfile(
            email: _emailController.text.trim(),
            nickname: _nicknameController.text.trim(),
            bio: _bioController.text.trim(),
            blogUrl: _blogUrlController.text.trim(),
            avatarUrl: _avatarUrlController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (oldPassword.isEmpty) {
      _showError('请输入当前密码');
      return;
    }
    if (newPassword.length < 6) {
      _showError('新密码至少6个字符');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('两次输入的密码不一致');
      return;
    }

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    setState(() => _changingPassword = true);
    try {
      await ref
          .read(apiClientProvider)
          .changePassword(
            accessToken: token,
            oldPassword: oldPassword,
            newPassword: newPassword,
          );
      if (!mounted) return;
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已修改')));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RecordList extends ConsumerWidget {
  const _RecordList({required this.type, required this.label});

  final String type;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(userActivityProvider(type));
    return records.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (page) {
        if (page.items.isEmpty) {
          return Center(child: Text('暂无$label记录'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: page.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = page.items[index];
            final date = DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(item.title),
                subtitle: Text(date),
                onTap: () => context.go('/contents/${item.contentId}'),
                trailing: IconButton(
                  tooltip: '删除',
                  onPressed: () => _delete(context, ref, item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    UserActivity item,
  ) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteMyActivity(accessToken: token, type: type, id: item.id);
      ref.invalidate(userActivityProvider(type));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
