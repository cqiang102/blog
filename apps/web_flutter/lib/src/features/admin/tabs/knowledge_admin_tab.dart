// 管理后台 - 知识库管理标签页
// 展示知识文档列表，支持编辑和筛选
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_providers.dart';
import '../../../core/models.dart';
import '../admin_widgets.dart';

/// 知识库管理标签页
/// 展示知识文档列表，支持编辑和筛选
class AdminKnowledgeTab extends ConsumerStatefulWidget {
  const AdminKnowledgeTab({super.key});

  @override
  ConsumerState<AdminKnowledgeTab> createState() => AdminKnowledgeTabState();
}

/// 知识库管理标签页状态管理
class AdminKnowledgeTabState extends ConsumerState<AdminKnowledgeTab> {
  final _queryController = TextEditingController(); // 搜索关键词输入框
  bool? _enabled; // 启用状态筛选
  AdminKnowledgeDocQuery _query = const AdminKnowledgeDocQuery(); // 当前查询条件

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(adminKnowledgeDocsProvider(_query));

    return docs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => AdminErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminKnowledgeDocsProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionToolbar(
                title: '个人知识库',
                actionLabel: '新增',
                actionIcon: Icons.add,
                onAction: () => _openKnowledgeEditor(context),
                secondaryLabel: '刷新',
                secondaryIcon: Icons.refresh,
                onSecondaryAction:
                    () => ref.invalidate(adminKnowledgeDocsProvider(_query)),
              ),
              const SizedBox(height: 12),
              _KnowledgeFilters(
                queryController: _queryController,
                enabled: _enabled,
                onEnabledChanged: (value) => setState(() => _enabled = value),
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 篇知识库文档',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const AdminEmptyPane(message: '暂无知识库文档')
              else
                for (final doc in page.items) ...[
                  _KnowledgeDocRow(
                    doc: doc,
                    onEdit: () => _openKnowledgeEditor(context, doc: doc),
                    onDelete: () => _deleteKnowledgeDoc(context, doc),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminKnowledgeDocQuery(
        query: _queryController.text.trim(),
        enabled: _enabled,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _enabled = null;
      _query = const AdminKnowledgeDocQuery();
    });
  }

  Future<void> _openKnowledgeEditor(
    BuildContext context, {
    AdminKnowledgeDocItem? doc,
  }) async {
    final draft = await showDialog<AdminKnowledgeDocDraft>(
      context: context,
      builder: (context) => KnowledgeEditorDialog(doc: doc),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      if (doc == null) {
        await ref
            .read(apiClientProvider)
            .createAdminKnowledgeDoc(accessToken: token, draft: draft);
      } else {
        await ref
            .read(apiClientProvider)
            .updateAdminKnowledgeDoc(
              accessToken: token,
              id: doc.id,
              draft: draft,
            );
      }
      _refreshKnowledgeState();
      if (!context.mounted) return;
      showAdminSnack(context, doc == null ? '知识库文档已创建' : '知识库文档已保存');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      showAdminSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      showAdminSnack(context, error.toString());
    }
  }

  Future<void> _deleteKnowledgeDoc(
    BuildContext context,
    AdminKnowledgeDocItem doc,
  ) async {
    final confirmed = await adminConfirm(
      context,
      title: '删除知识库文档',
      message: '确认删除「${doc.title}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminKnowledgeDoc(accessToken: token, id: doc.id);
      _refreshKnowledgeState();
      if (!context.mounted) return;
      showAdminSnack(context, '知识库文档已删除');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      showAdminSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      showAdminSnack(context, error.toString());
    }
  }

  void _refreshKnowledgeState() {
    ref.invalidate(adminKnowledgeDocsProvider(_query));
    ref.invalidate(adminDashboardProvider);
  }
}

/// 知识库筛选组件
class _KnowledgeFilters extends StatelessWidget {
  const _KnowledgeFilters({
    required this.queryController,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController queryController; // 搜索关键词控制器
  final bool? enabled; // 启用状态
  final ValueChanged<bool?> onEnabledChanged; // 状态变更回调
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
          width: 280,
          child: TextField(
            controller: queryController,
            decoration: const InputDecoration(labelText: '标题 / 来源 / 正文'),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<bool?>(
            initialValue: enabled,
            decoration: const InputDecoration(labelText: '状态'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部状态')),
              DropdownMenuItem(value: true, child: Text('启用')),
              DropdownMenuItem(value: false, child: Text('停用')),
            ],
            onChanged: onEnabledChanged,
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

/// 知识库文档行组件
/// 展示单条知识库文档的标题、正文预览、来源类型和操作按钮
class _KnowledgeDocRow extends StatelessWidget {
  const _KnowledgeDocRow({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminKnowledgeDocItem doc; // 文档数据
  final VoidCallback onEdit; // 编辑回调
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final preview = doc.body.isEmpty ? '暂无正文' : doc.body;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.library_books_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preview,
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
                _KnowledgeSourceChip(sourceType: doc.sourceType),
                _KnowledgeEnabledChip(enabled: doc.enabled),
                if (doc.sourceRef.isNotEmpty)
                  AdminMetaText(icon: Icons.link_outlined, text: doc.sourceRef),
                AdminMetaText(icon: Icons.update, text: formatAdminDate(doc.updatedAt)),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
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

/// 知识库编辑器对话框
/// 支持新增和编辑知识库文档，包含标题、来源类型、来源引用、正文和启用状态
class KnowledgeEditorDialog extends StatefulWidget {
  const KnowledgeEditorDialog({super.key, required this.doc});

  final AdminKnowledgeDocItem? doc; // 待编辑文档（null 表示新增）

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
    final draft =
        doc == null
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
    return AlertDialog(
      title: Text(widget.doc == null ? '新增知识库文档' : '编辑知识库文档'),
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
                  onChanged:
                      (value) => setState(
                        () => _sourceType = value ?? KnowledgeSourceType.manual,
                      ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sourceRefController,
                  decoration: const InputDecoration(labelText: '来源引用'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: '知识正文'),
                  minLines: 8,
                  maxLines: 16,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用'),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
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

/// 知识库来源类型标签组件
class _KnowledgeSourceChip extends StatelessWidget {
  const _KnowledgeSourceChip({required this.sourceType});

  final KnowledgeSourceType sourceType; // 来源类型

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (sourceType) {
      KnowledgeSourceType.manual => scheme.secondaryContainer,
      KnowledgeSourceType.url => scheme.primaryContainer,
      KnowledgeSourceType.file => scheme.tertiaryContainer,
      KnowledgeSourceType.content => scheme.surfaceContainerHighest,
    };
    return Chip(label: Text(sourceType.label), backgroundColor: color);
  }
}

/// 知识库启用状态标签组件
class _KnowledgeEnabledChip extends StatelessWidget {
  const _KnowledgeEnabledChip({required this.enabled});

  final bool enabled; // 是否启用

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(enabled ? '启用' : '停用'),
      backgroundColor:
          enabled ? scheme.primaryContainer : scheme.errorContainer,
    );
  }
}
