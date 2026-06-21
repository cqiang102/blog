part of '../content_list_page.dart';

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
    final grouped = groupBy(
      items,
      (item) => DateFormat('yyyy-MM').format(item.publishedAt),
    );
    final sortedMonths = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final flatItems = <_TimelineItem>[];
    for (final monthKey in sortedMonths) {
      final parts = monthKey.split('-');
      final year = parts[0];
      final month = '${int.parse(parts[1])} 月';
      final monthItems = grouped[monthKey]!;
      flatItems.add(
        _TimelineDate(year: year, month: month, count: monthItems.length),
      );
      for (var index = 0; index < monthItems.length; index++) {
        flatItems.add(
          _TimelineContent(
            content: monthItems[index],
            isLastInMonth: index == monthItems.length - 1,
            isLastMonth: monthKey == sortedMonths.last,
          ),
        );
      }
    }

    final totalItems =
        flatItems.length +
        (isLoading ? 1 : 0) +
        (!hasMore && items.isNotEmpty ? 1 : 0);

    return SliverToBoxAdapter(
      child: Timeline.tileBuilder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        theme: TimelineThemeData(
          nodePosition: 0.05,
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
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    '${item.count} 篇',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              } else if (item is _TimelineContent) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
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
                      Text(
                        item.year,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          item.month,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.5),
                );
              } else if (item is _TimelineContent) {
                return OutlinedDotIndicator(
                  size: 8,
                  borderWidth: 2,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.4),
                );
              }
            }
            return const SizedBox.shrink();
          },
          connectorBuilder: (context, index, type) {
            return SolidLineConnector(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
            );
          },
        ),
      ),
    );
  }
}

abstract class _TimelineItem {}

class _TimelineDate extends _TimelineItem {
  _TimelineDate({required this.year, required this.month, required this.count});

  final String year;
  final String month;
  final int count;
}

class _TimelineContent extends _TimelineItem {
  _TimelineContent({
    required this.content,
    required this.isLastInMonth,
    required this.isLastMonth,
  });

  final BlogContent content;
  final bool isLastInMonth;
  final bool isLastMonth;
}

class _ContentRow extends StatelessWidget {
  const _ContentRow({required this.content});

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
    final date = DateFormat('yyyy-MM-dd').format(content.publishedAt);
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
            const SizedBox(width: AppSpacing.sm),
            HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              date,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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
          color: highlighted
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
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
