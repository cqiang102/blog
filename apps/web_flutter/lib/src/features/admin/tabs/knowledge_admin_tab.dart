// 管理后台 - 知识库管理标签页
// 展示知识文档列表，支持编辑和筛选
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../core/api_providers.dart';
import '../../../core/models.dart';
import '../../../core/theme.dart';
import '../admin_widgets.dart';

/// 知识库管理标签页
class AdminKnowledgeTab extends ConsumerStatefulWidget {
  const AdminKnowledgeTab({super.key});

  @override
  ConsumerState<AdminKnowledgeTab> createState() => AdminKnowledgeTabState();
}

class AdminKnowledgeTabState extends ConsumerState<AdminKnowledgeTab> {
  final _queryController = TextEditingController();
  bool? _enabled;
  AdminKnowledgeDocQuery _query = const AdminKnowledgeDocQuery();

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
          (page) => _KnowledgeList(
            page: page,
            query: _query,
            queryController: _queryController,
            enabled: _enabled,
            onEnabledChanged: (value) => setState(() => _enabled = value),
            onApply: _applyFilters,
            onClear: _clearFilters,
            onOpenEditor: (doc) => _openKnowledgeEditor(context, doc: doc),
            onDelete: (doc) => _deleteKnowledgeDoc(context, doc),
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
    if (!mounted) return;
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

/// 知识库列表组件
class _KnowledgeList extends StatelessWidget {
  const _KnowledgeList({
    required this.page,
    required this.query,
    required this.queryController,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onApply,
    required this.onClear,
    required this.onOpenEditor,
    required this.onDelete,
  });

  final PageResult<AdminKnowledgeDocItem> page;
  final AdminKnowledgeDocQuery query;
  final TextEditingController queryController;
  final bool? enabled;
  final ValueChanged<bool?> onEnabledChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<AdminKnowledgeDocItem?> onOpenEditor;
  final ValueChanged<AdminKnowledgeDocItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        final doc = page.items[index - 1];
        return _KnowledgeDocRow(
          doc: doc,
          onEdit: () => onOpenEditor(doc),
          onDelete: () => onDelete(doc),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionToolbar(
          title: '个人知识库',
          actionLabel: '新增',
          actionIcon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
          onAction: () => onOpenEditor(null),
          secondaryLabel: '刷新',
          secondaryIcon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
          onSecondaryAction: onApply,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        _KnowledgeFilters(
          queryController: queryController,
          enabled: enabled,
          onEnabledChanged: onEnabledChanged,
          onApply: onApply,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          '共 ${page.total} 篇知识库文档',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (page.items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无知识库文档'),
        ],
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    );
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

  final TextEditingController queryController;
  final bool? enabled;
  final ValueChanged<bool?> onEnabledChanged;
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

/// 知识库文档行组件
class _KnowledgeDocRow extends StatelessWidget {
  const _KnowledgeDocRow({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminKnowledgeDocItem doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = doc.body.isEmpty ? '暂无正文' : doc.body;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图标 + 信息
            _buildHeader(context, preview),
            const SizedBox(height: AppSpacing.sm + 4),

            // 标签和操作
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String preview) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedBook01,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
        _KnowledgeSourceChip(sourceType: doc.sourceType),
        _KnowledgeEnabledChip(enabled: doc.enabled),
        if (doc.sourceRef.isNotEmpty)
          AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 18), text: doc.sourceRef),
        AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 18), text: formatAdminDate(doc.updatedAt)),
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
                    validator:
                        (value) =>
                            value == null || value.trim().isEmpty
                                ? '请输入标题'
                                : null,
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
                    onChanged:
                        (value) => setState(
                          () =>
                              _sourceType = value ?? KnowledgeSourceType.manual,
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

/// 知识库来源类型标签组件
class _KnowledgeSourceChip extends StatelessWidget {
  const _KnowledgeSourceChip({required this.sourceType});

  final KnowledgeSourceType sourceType;

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

  final bool enabled;

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
