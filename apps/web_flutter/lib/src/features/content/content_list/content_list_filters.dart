part of '../content_list_page.dart';

bool _hasActiveFilters(ContentFilterState filter) {
  return filter.query.isNotEmpty ||
      filter.type != null ||
      filter.tag != null ||
      filter.startDate != null ||
      filter.endDate != null;
}

int _activeFilterCount(ContentFilterState filter) {
  var count = 0;
  if (filter.type != null) count++;
  if (filter.tag != null) count++;
  if (filter.startDate != null || filter.endDate != null) count++;
  return count;
}

class _SearchAndFilterBar extends StatefulWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.filterCount,
    required this.filtersExpanded,
    required this.onSearch,
    required this.onToggleFilters,
  });

  final TextEditingController controller;
  final int filterCount;
  final bool filtersExpanded;
  final VoidCallback onSearch;
  final VoidCallback onToggleFilters;

  @override
  State<_SearchAndFilterBar> createState() => _SearchAndFilterBarState();
}

class _SearchAndFilterBarState extends State<_SearchAndFilterBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);
    final hasText = widget.controller.text.isNotEmpty;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: design.cardBorder),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: scheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: '搜索标题、摘要或正文',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => widget.onSearch(),
            ),
          ),
          if (hasText)
            IconButton(
              tooltip: '清除搜索',
              onPressed: () {
                widget.controller.clear();
                widget.onSearch();
              },
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          SizedBox(
            height: 24,
            child: VerticalDivider(color: scheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Badge(
              isLabelVisible: widget.filterCount > 0,
              label: Text(
                '${widget.filterCount}',
                style: const TextStyle(
                  fontFeatures: [ui.FontFeature.tabularFigures()],
                ),
              ),
              child: IconButton(
                tooltip: widget.filtersExpanded ? '收起筛选' : '展开筛选',
                onPressed: widget.onToggleFilters,
                icon: HugeIcon(
                  icon: widget.filtersExpanded
                      ? HugeIcons.strokeRoundedFilterRemove
                      : HugeIcons.strokeRoundedFilter,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.filter,
    required this.onTypeChanged,
    required this.onTagChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  final ContentFilterState filter;
  final ValueChanged<ContentType?> onTypeChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FilterLabel(label: '内容类型'),
            const SizedBox(height: AppSpacing.sm),
            _TypeFilter(
              selectedType: filter.type,
              onTypeChanged: onTypeChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            const _FilterLabel(label: '内容标签'),
            const SizedBox(height: AppSpacing.sm),
            _TagFilter(selectedTag: filter.tag, onTagChanged: onTagChanged),
            const SizedBox(height: AppSpacing.md),
            const _FilterLabel(label: '发布时间'),
            const SizedBox(height: AppSpacing.sm),
            _DateFilter(
              startDate: filter.startDate,
              endDate: filter.endDate,
              onStartDateChanged: onStartDateChanged,
              onEndDateChanged: onEndDateChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.labelLarge);
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selectedType, required this.onTypeChanged});

  final ContentType? selectedType;
  final ValueChanged<ContentType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ChoiceChip(
          label: const Text('全部'),
          selected: selectedType == null,
          onSelected: (_) => onTypeChanged(null),
        ),
        for (final type in ContentType.values)
          ChoiceChip(
            label: Text(type.label),
            selected: selectedType == type,
            onSelected: (_) => onTypeChanged(type),
          ),
      ],
    );
  }
}

class _TagFilter extends ConsumerWidget {
  const _TagFilter({required this.selectedTag, required this.onTagChanged});

  final String? selectedTag;
  final ValueChanged<String?> onTagChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    return tagsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text(
        '标签暂时加载失败',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (tags) {
        if (tags.isEmpty) return const Text('暂无标签');
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: const Text('全部'),
              selected: selectedTag == null,
              onSelected: (_) => onTagChanged(null),
            ),
            for (final tag in tags)
              FilterChip(
                label: Text(tag.name),
                selected: selectedTag == tag.slug,
                onSelected: (selected) =>
                    onTagChanged(selected ? tag.slug : null),
              ),
          ],
        );
      },
    );
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('yyyy-MM-dd');
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          avatar: const HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            size: 17,
          ),
          label: Text(startDate == null ? '开始日期' : format.format(startDate!)),
          onPressed: () => _selectDate(context, isStart: true),
        ),
        Text(
          '至',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        ActionChip(
          avatar: const HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar02,
            size: 17,
          ),
          label: Text(endDate == null ? '结束日期' : format.format(endDate!)),
          onPressed: () => _selectDate(context, isStart: false),
        ),
      ],
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? startDate : endDate) ?? now,
      firstDate: DateTime(kDateRangeStartYear),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null || !context.mounted) return;

    if (isStart) {
      onStartDateChanged(picked);
    } else {
      onEndDateChanged(picked);
    }
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filter,
    required this.onRemoveQuery,
    required this.onRemoveType,
    required this.onRemoveTag,
    required this.onRemoveDates,
    required this.onClearAll,
  });

  final ContentFilterState filter;
  final VoidCallback onRemoveQuery;
  final VoidCallback onRemoveType;
  final VoidCallback onRemoveTag;
  final VoidCallback onRemoveDates;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('yyyy-MM-dd');
    final dateLabel = [
      if (filter.startDate != null) format.format(filter.startDate!),
      if (filter.endDate != null) format.format(filter.endDate!),
    ].join(' - ');

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (filter.query.isNotEmpty)
          InputChip(
            label: Text('搜索：${filter.query}'),
            onDeleted: onRemoveQuery,
          ),
        if (filter.type != null)
          InputChip(label: Text(filter.type!.label), onDeleted: onRemoveType),
        if (filter.tag != null)
          InputChip(label: Text('#${filter.tag}'), onDeleted: onRemoveTag),
        if (dateLabel.isNotEmpty)
          InputChip(label: Text(dateLabel), onDeleted: onRemoveDates),
        TextButton(onPressed: onClearAll, child: const Text('清空筛选')),
      ],
    );
  }
}
