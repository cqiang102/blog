// 友链编辑器对话框
// 支持新增和编辑友链，包含名称、URL、头像和简介
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../theme/app_spacing.dart';
import 'admin_widgets.dart';

/// 友链编辑器对话框
/// 支持新增和编辑友链，包含名称、站点 URL、头像、简介、排序和可见性
class FriendEditorDialog extends StatefulWidget {
  const FriendEditorDialog({super.key, required this.friend});

  final FriendLink? friend; // 待编辑友链（null 表示新增）

  @override
  State<FriendEditorDialog> createState() => FriendEditorDialogState();
}

/// 友链编辑器对话框状态管理
class FriendEditorDialogState extends State<FriendEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _introController = TextEditingController();
  final _avatarController = TextEditingController();
  final _siteController = TextEditingController();
  final _sortController = TextEditingController();
  late bool _visible;

  @override
  void initState() {
    super.initState();
    final friend = widget.friend;
    final draft = friend == null
        ? const FriendDraft(
            name: '',
            intro: '',
            avatarUrl: '',
            siteUrl: '',
            visible: true,
            sortOrder: 0,
          )
        : FriendDraft.fromItem(friend);
    _nameController.text = draft.name;
    _introController.text = draft.intro;
    _avatarController.text = draft.avatarUrl;
    _siteController.text = draft.siteUrl;
    _sortController.text = draft.sortOrder.toString();
    _visible = draft.visible;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    _avatarController.dispose();
    _siteController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEditorDialog(
      title: widget.friend == null ? '新增朋友' : '编辑朋友',
      subtitle: '维护站点信息、展示内容和排序',
      maxWidth: 760,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存朋友')),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminFormSection(
              title: '站点信息',
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '名称'),
                    maxLength: 80,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '请输入名称' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _siteController,
                    decoration: const InputDecoration(labelText: '站点 URL'),
                    validator: _validateRequiredUrl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminFormSection(
              title: '展示设置',
              child: Column(
                children: [
                  TextFormField(
                    controller: _avatarController,
                    decoration: const InputDecoration(labelText: '头像 URL'),
                    validator: _validateOptionalUrl,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _introController,
                    decoration: const InputDecoration(labelText: '简介'),
                    maxLines: 3,
                    maxLength: 1000,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sortController,
                    decoration: const InputDecoration(labelText: '排序值'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        int.tryParse(value?.trim() ?? '') == null
                        ? '请输入数字'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('公开展示'),
                    value: _visible,
                    onChanged: (value) => setState(() => _visible = value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateRequiredUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入站点 URL';
    return _validateUrlText(text);
  }

  String? _validateOptionalUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _validateUrlText(text);
  }

  String? _validateUrlText(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return '请输入完整 URL';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      FriendDraft(
        name: _nameController.text,
        intro: _introController.text,
        avatarUrl: _avatarController.text,
        siteUrl: _siteController.text,
        visible: _visible,
        sortOrder: int.parse(_sortController.text.trim()),
      ),
    );
  }
}
