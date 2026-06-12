import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../../state/state.dart';
import '../../widgets/widgets.dart';
import '../../core/constants.dart';
import '../../state/content_filter_state.dart';
import '../../core/media_url.dart';
import '../../core/models.dart';
import '../../theme/app_spacing.dart';

class ContentListPage extends ConsumerStatefulWidget {
  const ContentListPage({super.key});

  @override
  ConsumerState<ContentListPage> createState() => _ContentListPageState();
}

class _ContentListPageState extends ConsumerState<ContentListPage>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showFilters = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - kScrollThreshold) {
      _loadMore();
    }
  }

  void _loadInitialData() {
    final filter = ref.read(contentFilterProvider);
    _searchController.text = filter.query;
    final query = filter.toQuery();
    final pagination = ref.read(contentPaginationProvider(query));
    if (pagination.items.isEmpty &&
        !pagination.isLoading &&
        pagination.error == null) {
      ref.read(contentPaginationProvider(query).notifier).resetAndLoad();
    }
  }

  void _loadMore() {
    final filter = ref.read(contentFilterProvider);
    ref.read(contentPaginationProvider(filter.toQuery()).notifier).loadMore();
  }

  void _resetAndLoad() {
    final filter = ref.read(contentFilterProvider);
    ref
        .read(contentPaginationProvider(filter.toQuery()).notifier)
        .resetAndLoad();
  }

  void _updateFilter(VoidCallback update) {
    update();
    _resetAndLoad();
  }

  void _search() {
    _updateFilter(
      () => ref
          .read(contentFilterProvider.notifier)
          .updateQuery(_searchController.text.trim()),
    );
  }

  void _clearAll() {
    _searchController.clear();
    ref.read(contentFilterProvider.notifier).clearAll();
    _resetAndLoad();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filter = ref.watch(contentFilterProvider);
    final pagination = ref.watch(contentPaginationProvider(filter.toQuery()));
    final hasFilters = _hasActiveFilters(filter);

    return AppPageFrame(
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverAppBar(
            toolbarHeight: 72,
            title: Text('全部内容'),
            actions: [AppThemeToggle(), SizedBox(width: AppSpacing.sm)],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Text(
                  //   '从文章、照片和视频中，找到你感兴趣的记录。',
                  //   style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  //     color: Theme.of(context).colorScheme.onSurfaceVariant,
                  //   ),
                  // ),
                  // const SizedBox(height: AppSpacing.lg),
                  _SearchAndFilterBar(
                    controller: _searchController,
                    filterCount: _activeFilterCount(filter),
                    filtersExpanded: _showFilters,
                    onSearch: _search,
                    onToggleFilters:
                        () => setState(() => _showFilters = !_showFilters),
                  ),
                  AnimatedSize(
                    duration: AppAnimations.normal,
                    curve: AppAnimations.slideCurve,
                    alignment: Alignment.topCenter,
                    child:
                        _showFilters
                            ? Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                              ),
                              child: _FilterPanel(
                                filter: filter,
                                onTypeChanged:
                                    (type) => _updateFilter(
                                      () => ref
                                          .read(contentFilterProvider.notifier)
                                          .updateType(type),
                                    ),
                                onTagChanged:
                                    (tag) => _updateFilter(
                                      () => ref
                                          .read(contentFilterProvider.notifier)
                                          .updateTag(tag),
                                    ),
                                onStartDateChanged:
                                    (date) => _updateFilter(
                                      () => ref
                                          .read(contentFilterProvider.notifier)
                                          .updateStartDate(date),
                                    ),
                                onEndDateChanged:
                                    (date) => _updateFilter(
                                      () => ref
                                          .read(contentFilterProvider.notifier)
                                          .updateEndDate(date),
                                    ),
                              ),
                            )
                            : const SizedBox.shrink(),
                  ),
                  if (hasFilters) ...[
                    const SizedBox(height: AppSpacing.sm + 4),
                    _ActiveFilters(
                      filter: filter,
                      onRemoveQuery: () {
                        _searchController.clear();
                        _updateFilter(
                          () => ref
                              .read(contentFilterProvider.notifier)
                              .updateQuery(''),
                        );
                      },
                      onRemoveType:
                          () => _updateFilter(
                            () => ref
                                .read(contentFilterProvider.notifier)
                                .updateType(null),
                          ),
                      onRemoveTag:
                          () => _updateFilter(
                            () => ref
                                .read(contentFilterProvider.notifier)
                                .updateTag(null),
                          ),
                      onRemoveDates:
                          () => _updateFilter(
                            () =>
                                ref
                                    .read(contentFilterProvider.notifier)
                                    .clearDates(),
                          ),
                      onClearAll: _clearAll,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm + 4,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  // Text(
                  //   pagination.items.isEmpty
                  //       ? '内容列表'
                  //       : '已加载 ${pagination.items.length} 篇',
                  //   style: Theme.of(context).textTheme.titleMedium,
                  // ),
                  const Spacer(),
                  if (pagination.isLoading && pagination.items.isNotEmpty)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
          if (pagination.items.isEmpty && pagination.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _LoadingState(),
            )
          else if (pagination.error != null && pagination.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(
                message: pagination.error!,
                onRetry: _resetAndLoad,
              ),
            )
          else if (pagination.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(onClear: hasFilters ? _clearAll : null),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              sliver: _TimelineContentList(
                items: pagination.items,
                isLoading: pagination.isLoading,
                hasMore: pagination.hasMore,
              ),
            ),
        ],
      ),
    );
  }
}

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
    final hasText = widget.controller.text.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedSearch01, color: scheme.onSurfaceVariant, size: 20),
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
                  GestureDetector(
                    onTap: () {
                      widget.controller.clear();
                      widget.onSearch();
                    },
                    child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Badge(
          isLabelVisible: widget.filterCount > 0,
          label: Text('${widget.filterCount}'),
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
      ],
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FilterLabel(label: '内容类型'),
          const SizedBox(height: AppSpacing.sm),
          _TypeFilter(selectedType: filter.type, onTypeChanged: onTypeChanged),
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
      error:
          (error, stackTrace) => Text(
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
                onSelected: (_) => onTagChanged(tag.slug),
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
          avatar: const HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 17),
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
          avatar: const HugeIcon(icon: HugeIcons.strokeRoundedCalendar02, size: 17),
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
      if (endDate != null && endDate!.isBefore(picked)) {
        onEndDateChanged(null);
      }
    } else {
      onEndDateChanged(picked);
      if (startDate != null && startDate!.isAfter(picked)) {
        onStartDateChanged(null);
      }
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

class _TimelineContentList extends StatelessWidget {
  const _TimelineContentList({
    required this.items,
    required this.isLoading,
    required this.hasMore,
  });

  final List<BlogContent> items;
  final bool isLoading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    // 按月分组
    final grouped = groupBy(items, (item) => DateFormat('yyyy-MM').format(item.publishedAt));
    final sortedMonths = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // 构建扁平化的列表项
    final List<_TimelineItem> flatItems = [];
    for (final monthKey in sortedMonths) {
      final parts = monthKey.split('-');
      final year = parts[0];
      final month = '${int.parse(parts[1])} 月';
      flatItems.add(_TimelineDate(year: year, month: month, count: grouped[monthKey]!.length));
      final monthItems = grouped[monthKey]!;
      for (int i = 0; i < monthItems.length; i++) {
        flatItems.add(_TimelineContent(
          content: monthItems[i],
          isLastInMonth: i == monthItems.length - 1,
          isLastMonth: monthKey == sortedMonths.last,
        ));
      }
    }

    final totalItems = flatItems.length + (isLoading ? 1 : 0) + (!hasMore && items.isNotEmpty ? 1 : 0);

    return SliverToBoxAdapter(
      child: Timeline.tileBuilder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        theme: TimelineThemeData(
          nodePosition: 0.08,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          connectorTheme: ConnectorThemeData(
            thickness: 2,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
          indicatorTheme: const IndicatorThemeData(size: 12),
        ),
        builder: TimelineTileBuilder.connected(
          itemCount: totalItems,
          contentsBuilder: (context, index) {
            if (index < flatItems.length) {
              final item = flatItems[index];
              if (item is _TimelineDate) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    '${item.count} 篇',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              } else if (item is _TimelineContent) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: _ContentRow(content: item.content),
                );
              }
            }
            if (isLoading) return const _LoadingIndicator();
            if (!hasMore && items.isNotEmpty) return const _NoMoreContent();
            return const SizedBox.shrink();
          },
          oppositeContentsBuilder: (context, index) {
            if (index < flatItems.length) {
              final item = flatItems[index];
              if (item is _TimelineDate) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.year, style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
                      const SizedBox(height: 2),
                      Text(item.month, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      )),
                    ],
                  ),
                );
              }
            }
            return const SizedBox.shrink();
          },
          indicatorBuilder: (context, index) {
            if (index < flatItems.length) {
              final item = flatItems[index];
              if (item is _TimelineDate) {
                return DotIndicator(
                  size: 12,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                );
              } else if (item is _TimelineContent) {
                return OutlinedDotIndicator(
                  size: 8,
                  borderWidth: 2,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                );
              }
            }
            return const SizedBox.shrink();
          },
          connectorBuilder: (context, index, type) {
            return SolidLineConnector(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            );
          },
        ),
      ),
    );
  }
}

// 辅助类用于扁平化列表
abstract class _TimelineItem {}

class _TimelineDate extends _TimelineItem {
  final String year;
  final String month;
  final int count;
  _TimelineDate({required this.year, required this.month, required this.count});
}

class _TimelineContent extends _TimelineItem {
  final BlogContent content;
  final bool isLastInMonth;
  final bool isLastMonth;
  _TimelineContent({required this.content, required this.isLastInMonth, required this.isLastMonth});
}

class _ContentRow extends StatelessWidget {
  const _ContentRow({super.key, required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return AppInteractiveCard(
      onTap: () => context.go('/contents/${content.id}'),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _Thumb(
                url: content.coverUrl,
                width: compact ? 112 : 180,
                height: compact ? 126 : 118,
              ),
            ),
            SizedBox(width: compact ? 12 : AppSpacing.md),
            Expanded(
              child: _ContentSummary(content: content, compact: compact),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentSummary extends StatelessWidget {
  const _ContentSummary({required this.content, required this.compact});

  final BlogContent content;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleTags = content.tags.take(compact ? 1 : 3);
    final isArchived = content.status == ContentStatus.archived;
    final isDraft = content.status == ContentStatus.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isArchived || isDraft) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isArchived
                      ? scheme.errorContainer
                      : scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  content.status.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isArchived
                        ? scheme.onErrorContainer
                        : scheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                content.title,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          DateFormat('yyyy-MM-dd').format(content.publishedAt),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MetaPill(label: content.type.label, highlighted: true),
            for (final tag in visibleTags) _MetaPill(label: tag),
          ],
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color:
              highlighted ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.width, required this.height});

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedBook01,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
    if (url.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: resolveMediaUrl(url),
      width: width,
      height: height,
      fit: BoxFit.cover,
      memCacheWidth: (width * 2).round(),
      errorWidget: (context, url, error) => fallback,
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          AnimatedTextKit(
            isRepeatingAnimation: true,
            repeatForever: true,
            pause: const Duration(milliseconds: 1500),
            animatedTexts: [
              RotateAnimatedText(
                '正在整理内容',
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              RotateAnimatedText(
                '马上就好',
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              RotateAnimatedText(
                '稍等一下',
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('没有找到匹配的内容', style: Theme.of(context).textTheme.titleMedium),
          if (onClear != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onClear, child: const Text('清空筛选')),
          ],
        ],
      ),
    );
  }
}

class _NoMoreContent extends StatelessWidget {
  const _NoMoreContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(
          '已经到底了',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCloudOff,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
