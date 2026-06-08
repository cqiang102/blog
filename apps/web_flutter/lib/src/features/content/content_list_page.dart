// 内容列表页模块
// 支持无限滚动分页、关键词搜索、标签/类型/日期范围过滤
// 使用 Riverpod 管理状态，替代 setState
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_providers.dart';
import '../../core/constants.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

/// 内容列表页 Widget
/// 使用 Riverpod 管理筛选和分页状态
class ContentListPage extends ConsumerStatefulWidget {
  const ContentListPage({super.key});

  @override
  ConsumerState<ContentListPage> createState() => _ContentListPageState();
}

/// 内容列表页状态管理
/// 添加 AutomaticKeepAliveClientMixin 保持页面状态，避免切换标签时重建
class _ContentListPageState extends ConsumerState<ContentListPage>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 初始加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 监听滚动事件，加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - kScrollThreshold) {
      _loadMore();
    }
  }

  /// 加载初始数据
  void _loadInitialData() {
    final filter = ref.read(contentFilterProvider);
    ref
        .read(contentPaginationProvider(filter.toQuery()).notifier)
        .resetAndLoad();
  }

  /// 加载更多数据
  void _loadMore() {
    final filter = ref.read(contentFilterProvider);
    ref
        .read(contentPaginationProvider(filter.toQuery()).notifier)
        .loadMore();
  }

  /// 重置并重新加载
  void _resetAndLoad() {
    final filter = ref.read(contentFilterProvider);
    ref
        .read(contentPaginationProvider(filter.toQuery()).notifier)
        .resetAndLoad();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filter = ref.watch(contentFilterProvider);
    final pagination = ref.watch(contentPaginationProvider(filter.toQuery()));

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        const SliverAppBar(title: Text('全部内容')),

        // 搜索框和过滤器（固定区域）
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _SearchBar(
                  controller: _searchController,
                  onSearch: () {
                    ref
                        .read(contentFilterProvider.notifier)
                        .updateQuery(_searchController.text.trim());
                    _resetAndLoad();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _TypeFilter(
                  selectedType: filter.type,
                  onTypeChanged: (type) {
                    ref.read(contentFilterProvider.notifier).updateType(type);
                    _resetAndLoad();
                  },
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                _TagFilter(
                  selectedTag: filter.tag,
                  onTagChanged: (tag) {
                    ref.read(contentFilterProvider.notifier).updateTag(tag);
                    _resetAndLoad();
                  },
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                _DateFilter(
                  startDate: filter.startDate,
                  endDate: filter.endDate,
                  onStartDateChanged: (date) {
                    ref
                        .read(contentFilterProvider.notifier)
                        .updateStartDate(date);
                    _resetAndLoad();
                  },
                  onEndDateChanged: (date) {
                    ref.read(contentFilterProvider.notifier).updateEndDate(date);
                    _resetAndLoad();
                  },
                  onClear: () {
                    ref.read(contentFilterProvider.notifier).clearDates();
                    _resetAndLoad();
                  },
                ),
              ],
            ),
          ),
        ),

        // 内容列表（虚拟化渲染）
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
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverList.builder(
              itemCount: pagination.items.length +
                  (pagination.isLoading ? 1 : 0) +
                  (!pagination.hasMore && pagination.items.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < pagination.items.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                    child: _ContentRow(
                      key: ValueKey(pagination.items[index].id),
                      content: pagination.items[index],
                    ),
                  );
                } else if (pagination.isLoading) {
                  return const _LoadingIndicator();
                } else {
                  return const _NoMoreContent();
                }
              },
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 搜索栏组件
// ============================================================================

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSearch,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: '搜索标题、摘要、正文',
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            controller.clear();
            onSearch();
          },
        ),
      ),
    );
  }
}

// ============================================================================
// 类型过滤器组件
// ============================================================================

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({
    required this.selectedType,
    required this.onTypeChanged,
  });

  final ContentType? selectedType;
  final ValueChanged<ContentType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ChoiceChip(
          label: const Text('全部类型'),
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

// ============================================================================
// 标签过滤器组件
// ============================================================================

class _TagFilter extends ConsumerWidget {
  const _TagFilter({
    required this.selectedTag,
    required this.onTagChanged,
  });

  final String? selectedTag;
  final ValueChanged<String?> onTagChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return tagsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: const Text('全部标签'),
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

// ============================================================================
// 日期过滤器组件
// ============================================================================

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onClear,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final hasDateFilter = startDate != null || endDate != null;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 18),
          label: Text(startDate != null ? dateFormat.format(startDate!) : '开始日期'),
          onPressed: () => _selectDate(context, true),
        ),
        const Text('至'),
        ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 18),
          label: Text(endDate != null ? dateFormat.format(endDate!) : '结束日期'),
          onPressed: () => _selectDate(context, false),
        ),
        if (hasDateFilter)
          ActionChip(
            avatar: const Icon(Icons.clear, size: 18),
            label: const Text('清除日期'),
            onPressed: onClear,
          ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart ? startDate : endDate;
    final firstDate = DateTime(kDateRangeStartYear);
    final lastDate = DateTime(now.year, now.month, now.day);

    if (!context.mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
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
}

// ============================================================================
// 内容行组件
// ============================================================================

class _ContentRow extends StatelessWidget {
  const _ContentRow({super.key, required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/contents/${content.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _Thumb(url: content.coverUrl),
              ),
              const SizedBox(width: AppSpacing.md),

              // 内容信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),

                    // 摘要
                    Text(
                      content.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    // 标签
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          label: Text(content.type.label),
                          visualDensity: VisualDensity.compact,
                        ),
                        for (final tag in content.tags)
                          Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // 箭头图标
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 缩略图组件
// ============================================================================

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return SizedBox(
        width: kThumbWidth,
        height: kThumbHeight,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.article_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: kThumbWidth,
      height: kThumbHeight,
      fit: BoxFit.cover,
      memCacheWidth: kThumbWidth.toInt() * 2, // 限制内存缓存宽度
      errorWidget: (context, url, error) => SizedBox(
        width: kThumbWidth,
        height: kThumbHeight,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 状态组件
// ============================================================================

/// 加载状态组件
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 加载指示器组件
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

/// 空面板组件
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '没有找到内容',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 没有更多内容组件
class _NoMoreContent extends StatelessWidget {
  const _NoMoreContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(
          '没有更多内容了',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

/// 错误面板组件
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
