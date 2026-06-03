// 内容编辑器对话框
// 支持新增和编辑内容，包含标题、Slug、类型、状态、置顶、摘要、正文和标签
import 'package:flutter/material.dart';

import '../../core/models.dart';

/// 内容编辑器对话框
/// 支持新增和编辑内容，包含标题、Slug、类型、状态、置顶、摘要、正文和标签
class ContentEditorDialog extends StatefulWidget {
  const ContentEditorDialog({super.key, required this.content, required this.tags});

  final AdminContentItem? content; // 待编辑内容（null 表示新增）
  final List<TagItem> tags; // 可选标签列表

  @override
  State<ContentEditorDialog> createState() => ContentEditorDialogState();
}

/// 内容编辑器对话框状态管理
class ContentEditorDialogState extends State<ContentEditorDialog> {
  final _formKey = GlobalKey<FormState>(); // 表单 Key
  final _titleController = TextEditingController(); // 标题输入框
  final _slugController = TextEditingController(); // Slug 输入框
  final _summaryController = TextEditingController(); // 摘要输入框
  final _bodyController = TextEditingController(); // Markdown 正文输入框
  late ContentType _type; // 内容类型
  late ContentStatus _status; // 内容状态
  late bool _pinned; // 是否置顶
  late Set<String> _tagSlugs; // 已选标签 Slug 集合

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    final draft =
        content == null
            ? const AdminContentDraft(
              title: '',
              slug: '',
              type: ContentType.article,
              status: ContentStatus.draft,
              summary: '',
              bodyMarkdown: '',
              pinned: false,
              tagSlugs: [],
            )
            : AdminContentDraft.fromItem(content);
    _titleController.text = draft.title;
    _slugController.text = draft.slug;
    _summaryController.text = draft.summary;
    _bodyController.text = draft.bodyMarkdown;
    _type = draft.type;
    _status = draft.status;
    _pinned = draft.pinned;
    _tagSlugs = draft.tagSlugs.toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.content == null ? '新增内容' : '编辑内容'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '标题'),
                  maxLength: 180,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入标题'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(labelText: 'Slug'),
                  maxLength: 220,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<ContentType>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: '类型'),
                        items: [
                          for (final type in ContentType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _type = value ?? ContentType.article,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<ContentStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: '状态'),
                        items: [
                          for (final status in ContentStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _status = value ?? ContentStatus.draft,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('置顶'),
                  value: _pinned,
                  onChanged: (value) => setState(() => _pinned = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryController,
                  decoration: const InputDecoration(labelText: '摘要'),
                  maxLines: 3,
                  maxLength: 2000,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: 'Markdown 内容'),
                  minLines: 6,
                  maxLines: 12,
                ),
                if (widget.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in widget.tags)
                        FilterChip(
                          label: Text(tag.name),
                          selected: _tagSlugs.contains(tag.slug),
                          onSelected:
                              (selected) => setState(() {
                                if (selected) {
                                  _tagSlugs.add(tag.slug);
                                } else {
                                  _tagSlugs.remove(tag.slug);
                                }
                              }),
                        ),
                    ],
                  ),
                ],
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminContentDraft(
        title: _titleController.text,
        slug: _slugController.text,
        type: _type,
        status: _status,
        summary: _summaryController.text,
        bodyMarkdown: _bodyController.text,
        pinned: _pinned,
        tagSlugs: _tagSlugs.toList()..sort(),
      ),
    );
  }
}
