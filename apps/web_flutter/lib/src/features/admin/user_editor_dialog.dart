// 用户编辑器对话框
// 管理员编辑用户信息：昵称、邮箱、角色、状态、简介
import 'package:flutter/material.dart';

import '../../core/models.dart';

/// 用户编辑器对话框
/// 编辑用户信息，包含邮箱、昵称、头像、简介、博客地址、角色和状态
class UserEditorDialog extends StatefulWidget {
  const UserEditorDialog({super.key, required this.user});

  final AdminUserItem user; // 待编辑用户

  @override
  State<UserEditorDialog> createState() => UserEditorDialogState();
}

/// 用户编辑器对话框状态管理
class UserEditorDialogState extends State<UserEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _avatarController = TextEditingController();
  final _bioController = TextEditingController();
  final _blogUrlController = TextEditingController();
  late AdminUserRole _role;
  late AdminUserStatus _status;

  @override
  void initState() {
    super.initState();
    final draft = AdminUserDraft.fromItem(widget.user);
    _emailController.text = draft.email;
    _nicknameController.text = draft.nickname;
    _avatarController.text = draft.avatarUrl;
    _bioController.text = draft.bio;
    _blogUrlController.text = draft.blogUrl;
    _role = draft.role;
    _status = draft.status;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _avatarController.dispose();
    _bioController.dispose();
    _blogUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑用户'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '邮箱'),
                  maxLength: 320,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(labelText: '昵称'),
                  maxLength: 80,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入昵称'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _avatarController,
                  decoration: const InputDecoration(labelText: '头像 URL'),
                  validator: _validateOptionalUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _blogUrlController,
                  decoration: const InputDecoration(labelText: '博客地址'),
                  validator: _validateOptionalUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: '简介'),
                  maxLines: 3,
                  maxLength: 2000,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<AdminUserRole>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: '角色'),
                        items: [
                          for (final role in AdminUserRole.values)
                            DropdownMenuItem(
                              value: role,
                              child: Text(role.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _role = value ?? AdminUserRole.user,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<AdminUserStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: '状态'),
                        items: [
                          for (final status in AdminUserStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _status = value ?? AdminUserStatus.active,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入邮箱';
    if (!text.contains('@')) return '请输入有效邮箱';
    return null;
  }

  String? _validateOptionalUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return '请输入完整 URL';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminUserDraft(
        email: _emailController.text,
        nickname: _nicknameController.text,
        avatarUrl: _avatarController.text,
        bio: _bioController.text,
        blogUrl: _blogUrlController.text,
        role: _role,
        status: _status,
      ),
    );
  }
}
