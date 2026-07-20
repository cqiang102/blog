part of 'home_view.dart';

class _LatestContent extends StatelessWidget {
  const _LatestContent({required this.contents});

  final List<BlogContent> contents;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        if (constraints.crossAxisExtent < 600) {
          return SliverList.separated(
            itemCount: contents.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm + 4),
            itemBuilder: (context, index) => _CompactStoryCard(
              content: contents[index],
            ).fadeSlideIn(delay: (index * 80).ms),
          );
        }

        final columns = constraints.crossAxisExtent >= kDesktopBreakpoint
            ? 3
            : 2;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 344,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _StoryCard(
              content: contents[index],
            ).fadeSlideIn(delay: (index * 80).ms),
            childCount: contents.length,
          ),
        );
      },
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return AppInteractiveCard(
      onTap: () => context.go('/contents/${content.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 164,
            width: double.infinity,
            child: _CoverImage(url: content.coverUrl),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _StoryBody(content: content),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStoryCard extends StatelessWidget {
  const _CompactStoryCard({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return AppInteractiveCard(
      onTap: () => context.go('/contents/${content.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 116,
                height: 132,
                child: _CoverImage(url: content.coverUrl),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _StoryBody(content: content, compact: true)),
          ],
        ),
      ),
    );
  }
}

class _StoryBody extends StatelessWidget {
  const _StoryBody({required this.content, this.compact = false});

  final BlogContent content;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateFormat('yyyy-MM-dd').format(content.publishedAt);
    final isArchived = content.status == ContentStatus.archived;
    final isDraft = content.status == ContentStatus.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              content.type.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.primary),
            ),
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
            const Spacer(),
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
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content.title,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          content.summary,
          maxLines: compact ? 2 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const Spacer(),
        _ContentStats(likeCount: content.likeCount),
      ],
    );
  }
}

class _PopularList extends StatelessWidget {
  const _PopularList({required this.contents});

  final List<BlogContent> contents;

  @override
  Widget build(BuildContext context) {
    final visible = contents.take(5).toList();
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              _PopularRow(
                rank: index + 1,
                content: visible[index],
              ).fadeSlideIn(delay: (index * 80).ms),
              if (index != visible.length - 1)
                Divider(
                  height: 1,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PopularRow extends StatelessWidget {
  const _PopularRow({required this.rank, required this.content});

  final int rank;
  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isTop = rank <= 3;
    return InkWell(
      onTap: () => context.go('/contents/${content.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                rank.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isTop ? scheme.secondary : scheme.onSurfaceVariant,
                  fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                content.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${content.likeCount}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentStats extends StatelessWidget {
  const _ContentStats({required this.likeCount});

  final int likeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedFavourite,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('$likeCount', style: style),
      ],
    );
  }
}
