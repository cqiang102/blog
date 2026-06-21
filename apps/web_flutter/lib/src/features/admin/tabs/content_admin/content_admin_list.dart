part of '../content_admin_tab.dart';

class _ContentList extends StatelessWidget {
  const _ContentList({
    required this.page,
    required this.query,
    required this.searchController,
    required this.statusFilter,
    required this.typeFilter,
    required this.includeDeleted,
    required this.errorMessage,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
    required this.onToggleIncludeDeleted,
    required this.onApply,
    required this.onClear,
    required this.onRefresh,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
    required this.onRestore,
  });

  final PageResult<AdminContentItem> page;
  final AdminContentQuery query;
  final TextEditingController searchController;
  final ContentStatus? statusFilter;
  final ContentType? typeFilter;
  final bool includeDeleted;
  final String? errorMessage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ContentStatus?> onStatusFilterChanged;
  final ValueChanged<ContentType?> onTypeFilterChanged;
  final ValueChanged<bool> onToggleIncludeDeleted;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback onCreate;
  final ValueChanged<AdminContentItem> onEdit;
  final ValueChanged<AdminContentItem> onPreview;
  final ValueChanged<AdminContentItem> onDelete;
  final ValueChanged<AdminContentItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1040;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              constraints.maxWidth < 700 ? AppSpacing.md : AppSpacing.lg,
            ),
            children: [
              _ContentHeader(onCreate: onCreate),
              const SizedBox(height: AppSpacing.md),
              _ContentFilters(
                searchController: searchController,
                statusFilter: statusFilter,
                typeFilter: typeFilter,
                includeDeleted: includeDeleted,
                onSearchChanged: onSearchChanged,
                onStatusFilterChanged: onStatusFilterChanged,
                onTypeFilterChanged: onTypeFilterChanged,
                onToggleIncludeDeleted: onToggleIncludeDeleted,
                onApply: onApply,
                onClear: onClear,
              ),
              const SizedBox(height: AppSpacing.md),
              if (errorMessage != null) ...[
                _RefreshErrorBanner(message: errorMessage!, onRetry: onApply),
                const SizedBox(height: AppSpacing.md),
              ],
              _ResultSummary(
                page: page,
                pageSize: query.size,
                onPageSizeChanged: onPageSizeChanged,
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              if (page.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AdminEmptyPane(message: '没有符合条件的内容'),
                )
              else if (desktop)
                _DesktopContentTable(
                  items: page.items,
                  onEdit: onEdit,
                  onPreview: onPreview,
                  onDelete: onDelete,
                  onRestore: onRestore,
                )
              else
                ...page.items.map(
                  (content) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                    child: _MobileContentCard(
                      content: content,
                      onEdit: content.deleted ? null : () => onEdit(content),
                      onPreview:
                          content.deleted ||
                              content.status != ContentStatus.published
                          ? null
                          : () => onPreview(content),
                      onDelete: content.deleted
                          ? null
                          : () => onDelete(content),
                      onRestore: content.deleted
                          ? () => onRestore(content)
                          : null,
                    ),
                  ),
                ),
              if (page.total > 0) ...[
                const SizedBox(height: AppSpacing.md),
                _PaginationBar(
                  page: page.page,
                  pageSize: page.size,
                  total: page.total,
                  onChanged: onPageChanged,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '内容管理',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '统一维护文章、图片和视频内容',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        final action = FilledButton.icon(
          onPressed: onCreate,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
          label: const Text('新增内容'),
        );

        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 12), action],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            action,
          ],
        );
      },
    );
  }
}

class _ContentFilters extends StatelessWidget {
  const _ContentFilters({
    required this.searchController,
    required this.statusFilter,
    required this.typeFilter,
    required this.includeDeleted,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
    required this.onToggleIncludeDeleted,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController searchController;
  final ContentStatus? statusFilter;
  final ContentType? typeFilter;
  final bool includeDeleted;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ContentStatus?> onStatusFilterChanged;
  final ValueChanged<ContentType?> onTypeFilterChanged;
  final ValueChanged<bool> onToggleIncludeDeleted;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: '搜索标题或摘要',
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 20,
                  ),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          onPressed: () {
                            searchController.clear();
                            onApply();
                          },
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 18,
                          ),
                        ),
                ),
                textInputAction: TextInputAction.search,
                onChanged: onSearchChanged,
                onSubmitted: (_) => onApply(),
              ),
            ),
            SizedBox(
              width: 156,
              child: DropdownButtonFormField<ContentStatus?>(
                key: ValueKey(statusFilter),
                initialValue: statusFilter,
                decoration: const InputDecoration(labelText: '状态'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部状态')),
                  DropdownMenuItem(
                    value: ContentStatus.draft,
                    child: Text('草稿'),
                  ),
                  DropdownMenuItem(
                    value: ContentStatus.published,
                    child: Text('已发布'),
                  ),
                  DropdownMenuItem(
                    value: ContentStatus.archived,
                    child: Text('已归档'),
                  ),
                ],
                onChanged: onStatusFilterChanged,
              ),
            ),
            SizedBox(
              width: 156,
              child: DropdownButtonFormField<ContentType?>(
                key: ValueKey(typeFilter),
                initialValue: typeFilter,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部类型')),
                  DropdownMenuItem(
                    value: ContentType.markdown,
                    child: Text('文章'),
                  ),
                  DropdownMenuItem(value: ContentType.image, child: Text('图片')),
                  DropdownMenuItem(value: ContentType.video, child: Text('视频')),
                ],
                onChanged: onTypeFilterChanged,
              ),
            ),
            FilterChip(
              selected: includeDeleted,
              onSelected: onToggleIncludeDeleted,
              avatar: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete01,
                size: 18,
              ),
              label: const Text('显示已删除'),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 18,
              ),
              label: const Text('重置'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.page,
    required this.pageSize,
    required this.onPageSizeChanged,
  });

  final PageResult<AdminContentItem> page;
  final int pageSize;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final start = page.total == 0 ? 0 : page.page * page.size + 1;
    final end = (page.page * page.size + page.items.length).clamp(
      0,
      page.total,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            '共 ${page.total} 条，当前显示 $start–$end',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const Text('每页'),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: pageSize,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 20, child: Text('20')),
            DropdownMenuItem(value: 50, child: Text('50')),
          ],
          onChanged: (value) {
            if (value != null) onPageSizeChanged(value);
          },
        ),
      ],
    );
  }
}
