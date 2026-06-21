import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../../state/state.dart';
import '../../widgets/widgets.dart';
import '../../core/constants.dart';
import '../../core/media_url.dart';
import '../../core/models.dart';
import '../../theme/app_spacing.dart';

part 'content_list/content_list_filters.dart';
part 'content_list/content_list_states.dart';
part 'content_list/content_list_timeline.dart';

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
            actions: [
              AppThemeToggle(),
              SizedBox(width: AppSpacing.sm),
            ],
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
                    onToggleFilters: () =>
                        setState(() => _showFilters = !_showFilters),
                  ),
                  AnimatedSize(
                    duration: AppAnimations.normal,
                    curve: AppAnimations.slideCurve,
                    alignment: Alignment.topCenter,
                    child: _showFilters
                        ? Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: _FilterPanel(
                              filter: filter,
                              onTypeChanged: (type) => _updateFilter(
                                () => ref
                                    .read(contentFilterProvider.notifier)
                                    .updateType(type),
                              ),
                              onTagChanged: (tag) => _updateFilter(
                                () => ref
                                    .read(contentFilterProvider.notifier)
                                    .updateTag(tag),
                              ),
                              onStartDateChanged: (date) => _updateFilter(
                                () => ref
                                    .read(contentFilterProvider.notifier)
                                    .updateStartDate(date),
                              ),
                              onEndDateChanged: (date) => _updateFilter(
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
                      onRemoveType: () => _updateFilter(
                        () => ref
                            .read(contentFilterProvider.notifier)
                            .updateType(null),
                      ),
                      onRemoveTag: () => _updateFilter(
                        () => ref
                            .read(contentFilterProvider.notifier)
                            .updateTag(null),
                      ),
                      onRemoveDates: () => _updateFilter(
                        () => ref
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
                AppSpacing.sm,
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
