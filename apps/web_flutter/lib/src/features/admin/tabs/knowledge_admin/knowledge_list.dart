part of '../knowledge_admin_tab.dart';

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
    required this.onPageChanged,
    required this.onOpenEditor,
    required this.onDelete,
    required this.indexStatus,
    required this.reindexState,
    required this.onReindex,
    required this.onResetReindex,
  });

  final PageResult<AdminKnowledgeDocItem> page;
  final AdminKnowledgeDocQuery query;
  final TextEditingController queryController;
  final bool? enabled;
  final ValueChanged<bool?> onEnabledChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AdminKnowledgeDocItem?> onOpenEditor;
  final ValueChanged<AdminKnowledgeDocItem> onDelete;
  final AsyncValue<IndexStatus> indexStatus;
  final AsyncValue<ReindexResult?> reindexState;
  final VoidCallback onReindex;
  final VoidCallback onResetReindex;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.items.length + 1 + (page.total > page.size ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm + 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        if (index > page.items.length) {
          return AdminPaginationBar(
            page: page.page,
            pageSize: page.size,
            total: page.total,
            onChanged: onPageChanged,
          );
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
        AdminListActions(
          actions: [
            FilledButton.icon(
              onPressed: () => onOpenEditor(null),
              style: adminCompactButtonStyle(),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 18,
              ),
              label: const Text('新增'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        _KnowledgeIndexStatus(
          indexStatus: indexStatus,
          reindexState: reindexState,
          onReindex: onReindex,
          onReset: onResetReindex,
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
    return AdminFilterBar(
      items: [
        AdminFilterItem(
          child: TextField(
            controller: queryController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '标题 / 来源 / 正文',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onApply(),
          ),
        ),
        AdminFilterItem(
          width: 152,
          child: DropdownButtonFormField<bool?>(
            key: ValueKey(enabled),
            initialValue: enabled,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '状态 · 全部',
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('状态 · 全部')),
              DropdownMenuItem(value: true, child: Text('状态 · 启用')),
              DropdownMenuItem(value: false, child: Text('状态 · 停用')),
            ],
            onChanged: onEnabledChanged,
          ),
        ),
      ],
      actions: [
        AdminFilterApplyButton(onPressed: onApply),
        AdminFilterClearButton(onPressed: onClear),
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
    return AdminRowFooter(
      metadata: [
        _KnowledgeSourceChip(sourceType: doc.sourceType),
        _KnowledgeEnabledChip(enabled: doc.enabled),
        if (doc.sourceRef.isNotEmpty)
          AdminMetaText(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 18),
            text: doc.sourceRef,
          ),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 18),
          text: formatAdminDate(doc.updatedAt),
        ),
      ],
      actions: [
        OutlinedButton.icon(
          onPressed: onEdit,
          style: adminCompactButtonStyle(),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit01, size: 18),
          label: const Text('编辑'),
        ),
        TextButton.icon(
          onPressed: onDelete,
          style: adminCompactButtonStyle(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: 18),
          label: const Text('删除'),
        ),
      ],
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
      backgroundColor: enabled
          ? scheme.primaryContainer
          : scheme.errorContainer,
    );
  }
}
