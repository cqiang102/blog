part of '../knowledge_admin_tab.dart';

/// 知识库编辑器对话框
class KnowledgeEditorDialog extends StatefulWidget {
  const KnowledgeEditorDialog({super.key, required this.doc});

  final AdminKnowledgeDocItem? doc;

  @override
  State<KnowledgeEditorDialog> createState() => KnowledgeEditorDialogState();
}

class KnowledgeEditorDialogState extends State<KnowledgeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceRefController = TextEditingController();
  final _bodyController = TextEditingController();
  late KnowledgeSourceType _sourceType;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    final draft = doc == null
        ? const AdminKnowledgeDocDraft(
            title: '',
            sourceType: KnowledgeSourceType.manual,
            sourceRef: '',
            body: '',
            enabled: true,
          )
        : AdminKnowledgeDocDraft.fromItem(doc);
    _titleController.text = draft.title;
    _sourceType = draft.sourceType;
    _sourceRefController.text = draft.sourceRef;
    _bodyController.text = draft.body;
    _enabled = draft.enabled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceRefController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEditorDialog(
      title: widget.doc == null ? '新增知识库文档' : '编辑知识库文档',
      subtitle: '整理来源信息和可用于 AI 检索的正文内容',
      maxWidth: 900,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存文档')),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminFormSection(
              title: '文档信息',
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: '标题'),
                    maxLength: 180,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '请输入标题' : null,
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  DropdownButtonFormField<KnowledgeSourceType>(
                    initialValue: _sourceType,
                    decoration: const InputDecoration(labelText: '来源类型'),
                    items: [
                      for (final sourceType in KnowledgeSourceType.values)
                        DropdownMenuItem(
                          value: sourceType,
                          child: Text(sourceType.label),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _sourceType = value ?? KnowledgeSourceType.manual,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  TextFormField(
                    controller: _sourceRefController,
                    decoration: const InputDecoration(labelText: '来源引用'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminFormSection(
              title: '知识正文',
              subtitle: '建议使用结构清晰、语义完整的文本',
              child: Column(
                children: [
                  TextFormField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      hintText: '输入可供检索和回答使用的正文内容',
                      alignLabelWithHint: true,
                    ),
                    minLines: 10,
                    maxLines: 20,
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用'),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminKnowledgeDocDraft(
        title: _titleController.text,
        sourceType: _sourceType,
        sourceRef: _sourceRefController.text,
        body: _bodyController.text,
        enabled: _enabled,
      ),
    );
  }
}
