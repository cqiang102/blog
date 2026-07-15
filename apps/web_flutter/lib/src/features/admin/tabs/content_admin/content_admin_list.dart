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
              const SizedBox(height: AppSpacing.sm + 4),
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
    return AdminListActions(
      actions: [
        FilledButton.icon(
          onPressed: onCreate,
          style: adminCompactButtonStyle(),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
          label: const Text('新增内容'),
        ),
      ],
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
    final hasFilters =
        searchController.text.trim().isNotEmpty ||
        statusFilter != null ||
        typeFilter != null ||
        includeDeleted;

    return AdminFilterBar(
      onReset: onClear,
      resetEnabled: hasFilters,
      items: [
        AdminFilterItem(
          flex: 2,
          child: TextField(
            controller: searchController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '搜索标题或摘要',
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 20,
              ),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
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
        AdminFilterItem(
          width: 152,
          child: DropdownButtonFormField<ContentStatus?>(
            key: ValueKey(statusFilter),
            initialValue: statusFilter,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '状态 · 全部',
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('状态 · 全部')),
              DropdownMenuItem(
                value: ContentStatus.draft,
                child: Text('状态 · 草稿'),
              ),
              DropdownMenuItem(
                value: ContentStatus.published,
                child: Text('状态 · 已发布'),
              ),
              DropdownMenuItem(
                value: ContentStatus.archived,
                child: Text('状态 · 已归档'),
              ),
            ],
            onChanged: onStatusFilterChanged,
          ),
        ),
        AdminFilterItem(
          width: 152,
          child: DropdownButtonFormField<ContentType?>(
            key: ValueKey(typeFilter),
            initialValue: typeFilter,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '类型 · 全部',
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('类型 · 全部')),
              DropdownMenuItem(
                value: ContentType.markdown,
                child: Text('类型 · 文章'),
              ),
              DropdownMenuItem(
                value: ContentType.image,
                child: Text('类型 · 图片'),
              ),
              DropdownMenuItem(
                value: ContentType.video,
                child: Text('类型 · 视频'),
              ),
            ],
            onChanged: onTypeFilterChanged,
          ),
        ),
        AdminFilterItem(
          width: 140,
          child: AdminFilterToggle(
            selected: includeDeleted,
            onChanged: onToggleIncludeDeleted,
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedView, size: 18),
            selectedIcon: const HugeIcon(
              icon: HugeIcons.strokeRoundedTick01,
              size: 18,
            ),
            label: '包含已删除',
          ),
        ),
      ],
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
