// 标签编辑器对话框
// 支持新增和编辑标签，包含名称和 Slug
import 'package:flutter/material.dart';

import '../../core/models.dart';
import 'admin_widgets.dart';

/// 标签编辑器对话框
/// 支持新增和编辑标签，包含名称、Slug 和描述
class TagEditorDialog extends StatefulWidget {
  const TagEditorDialog({super.key, required this.tag});

  final TagItem? tag; // 待编辑标签（null 表示新增）

  @override
  State<TagEditorDialog> createState() => TagEditorDialogState();
}

/// 标签编辑器对话框状态管理
class TagEditorDialogState extends State<TagEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tag = widget.tag;
    if (tag != null) {
      _nameController.text = tag.name;
      _slugController.text = tag.slug;
      _descriptionController.text = tag.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEditorDialog(
      title: widget.tag == null ? '新增标签' : '编辑标签',
      subtitle: '用于内容分类和筛选，Slug 留空时可由后端生成',
      maxWidth: 620,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存标签')),
      ],
      child: Form(
        key: _formKey,
        child: AdminFormSection(
          title: '标签信息',
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
                maxLength: 60,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(labelText: 'Slug'),
                maxLength: 80,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '描述'),
                maxLines: 3,
                maxLength: 1000,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      TagDraft(
        name: _nameController.text,
        slug: _slugController.text,
        description: _descriptionController.text,
      ),
    );
  }
}
