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

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (constraints.crossAxisExtent < kDesktopBreakpoint) {
          return _buildCompactTimeline(context, flatItems);
        }

        final timeline = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.archiveWidth),
          child: _buildExpandedTimeline(context, flatItems, totalItems),
        );
        return SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: timeline),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: AppLayout.archiveAsideWidth,
                child: _ArchiveAside(grouped: grouped, items: items),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandedTimeline(
    BuildContext context,
    List<_TimelineItem> flatItems,
    int totalItems,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Timeline.tileBuilder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      theme: TimelineThemeData(
        nodePosition: 0.065,
        color: scheme.primary.withValues(alpha: 0.3),
        connectorTheme: ConnectorThemeData(
          thickness: 2,
          color: scheme.primary.withValues(alpha: 0.2),
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
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              );
            }
            if (item is _TimelineContent) {
              return Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 10),
                child: _ContentRow(content: item.content),
              );
            }
          }
          if (isLoading) return const _LoadingIndicator();
          if (!hasMore && items.isNotEmpty) return const _NoMoreContent();
          return const SizedBox.shrink();
        },
        oppositeContentsBuilder: (context, index) {
          if (index >= flatItems.length) return const SizedBox.shrink();
          final item = flatItems[index];
          if (item is! _TimelineDate) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.year,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  item.month,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
        indicatorBuilder: (context, index) {
          if (index >= flatItems.length) return const SizedBox.shrink();
          final item = flatItems[index];
          if (item is _TimelineDate) {
            return DotIndicator(
              size: 12,
              color: scheme.primary.withValues(alpha: 0.55),
            );
          }
          return OutlinedDotIndicator(
            size: 8,
            borderWidth: 2,
            color: scheme.primary.withValues(alpha: 0.4),
          );
        },
        connectorBuilder: (context, index, type) =>
            SolidLineConnector(color: scheme.primary.withValues(alpha: 0.15)),
      ),
    );
  }

  Widget _buildCompactTimeline(
    BuildContext context,
    List<_TimelineItem> flatItems,
  ) {
    final itemCount =
        flatItems.length +
        (isLoading ? 1 : 0) +
        (!hasMore && items.isNotEmpty ? 1 : 0);

    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < flatItems.length) {
          final item = flatItems[index];
          if (item is _TimelineDate) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.md,
                0,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    '${item.year} 年 ${item.month}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${item.count} 篇',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }
          if (item is _TimelineContent) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ContentRow(content: item.content),
            );
          }
        }
        if (isLoading) return const _LoadingIndicator();
        if (!hasMore && items.isNotEmpty) return const _NoMoreContent();
        return const SizedBox.shrink();
      },
    );
  }
}

class _ArchiveAside extends StatelessWidget {
  const _ArchiveAside({required this.grouped, required this.items});

  final Map<String, List<BlogContent>> grouped;
  final List<BlogContent> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);
    final months = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final tagCounts = <String, int>{};
    for (final item in items) {
      for (final tag in item.tags) {
        tagCounts.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final popularTags = tagCounts.entries.toList()
      ..sort((a, b) {
        final countOrder = b.value.compareTo(a.value);
        return countOrder == 0 ? a.key.compareTo(b.key) : countOrder;
      });

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.contentCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ARCHIVE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: design.lavender,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('时间归档', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '当前已加载 ${items.length} 篇记录',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final entry in months.take(6)) ...[
            _ArchiveMonthRow(monthKey: entry.key, count: entry.value.length),
            const SizedBox(height: AppSpacing.sm + 2),
          ],
          if (popularTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: AppSpacing.md),
            Text('常写主题', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in popularTags.take(7))
                  _MetaPill(label: '${entry.key} ${entry.value}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ArchiveMonthRow extends StatelessWidget {
  const _ArchiveMonthRow({required this.monthKey, required this.count});

  final String monthKey;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = monthKey.split('-');
    final label = parts.length == 2
        ? '${parts.first} · ${int.parse(parts.last).toString().padLeft(2, '0')}'
        : monthKey;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
      ],
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
      borderRadius: AppRadii.contentCard,
      onTap: () => context.go('/contents/${content.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: compact
            ? _CompactContentRow(content: content)
            : _ExpandedContentRow(content: content),
      ),
    );
  }
}

class _ExpandedContentRow extends StatelessWidget {
  const _ExpandedContentRow({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ContentThumb(content: content, width: 180, height: 124),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _ContentSummary(content: content, compact: false)),
      ],
    );
  }
}

class _CompactContentRow extends StatelessWidget {
  const _CompactContentRow({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateFormat('yyyy-MM-dd').format(content.publishedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ContentThumb(content: content, width: 88, height: 88),
            const SizedBox(width: 12),
            Expanded(child: _ContentSummary(content: content, compact: true)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              date,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            if (content.tags.isNotEmpty) _MetaPill(label: content.tags.first),
          ],
        ),
      ],
    );
  }
}

class _ContentThumb extends StatelessWidget {
  const _ContentThumb({
    required this.content,
    required this.width,
    required this.height,
  });

  final BlogContent content;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.contentMedia),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: Border.all(color: outline)),
        child: _Thumb(url: content.coverUrl, width: width, height: height),
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
    final visibleTags = content.tags.take(3);
    final isArchived = content.status == ContentStatus.archived;
    final isDraft = content.status == ContentStatus.draft;
    final date = DateFormat('yyyy-MM-dd').format(content.publishedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _MetaPill(label: content.type.label, highlighted: true),
            if (isArchived || isDraft) ...[
              const SizedBox(width: 6),
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
            ],
            if (!compact) ...[
              const Spacer(),
              const SizedBox(width: AppSpacing.sm),
              HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                date,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: compact ? 6 : AppSpacing.sm),
        Text(
          content.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            content.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (!compact && visibleTags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final tag in visibleTags) _MetaPill(label: tag)],
          ),
        ],
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
    final design = AppDesignTokens.of(context);
    final fallback = SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: design.mint,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedBook01,
          color: design.lavender,
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
