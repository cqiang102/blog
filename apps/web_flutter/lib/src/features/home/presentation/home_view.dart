import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../widgets/widgets.dart';
import '../../../core/constants.dart';
import '../../../core/media_url.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_design_tokens.dart';
import '../application/home_feed_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(homeFeedProvider);

    return AppPageFrame(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
            toolbarHeight: 72,
            title: Text('首页'),
            actions: [
              AppThemeToggle(),
              SizedBox(width: AppSpacing.sm),
            ],
          ),
          ...feed.when(
            loading: () => const [
              SliverFillRemaining(hasScrollBody: false, child: _LoadingState()),
            ],
            error: (error, stackTrace) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(homeFeedProvider),
                ),
              ),
            ],
            data: (data) => _buildContent(data),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(HomeFeed data) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(child: _HomeHero(featured: data.featured)),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverToBoxAdapter(
          child: AppSectionHeader(
            title: '最近更新',
            subtitle: '新写下的文章、照片与生活片段',
            actionLabel: '查看全部',
            onAction: () => context.go('/contents'),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
      if (data.latest.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: _LatestContent(contents: data.latest),
        )
      else
        const SliverToBoxAdapter(child: _EmptyState(message: '还没有发布内容')),
      if (data.mostLiked.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: AppSectionHeader(title: '大家喜欢', subtitle: '被读者收藏和点赞最多的内容'),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: _PopularList(contents: data.mostLiked),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        sliver: SliverToBoxAdapter(child: _HomeFooter()),
      ),
    ];
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.featured});

  final BlogContent? featured;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // 底层渐变
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer,
                    scheme.secondaryContainer.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
          // 弥散光晕
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DiffuseCirclePainter(
                  lavender: design.lavender.withValues(alpha: 0.12),
                  rose: design.rose.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          // 原有内容
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= kTabletBreakpoint;
              const intro = _HeroIntro();
              final story = featured == null
                  ? const _HeroPlaceholder()
                  : _FeaturedStory(content: featured!);

              if (!wide) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      intro,
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(height: 240, child: story),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const Expanded(flex: 5, child: intro),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 6,
                      child: SizedBox(height: 280, child: story),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiffuseCirclePainter extends CustomPainter {
  const _DiffuseCirclePainter({required this.lavender, required this.rose});

  final Color lavender;
  final Color rose;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      const Offset(80, 60),
      180,
      Paint()
        ..color = lavender
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 80),
    );
    canvas.drawCircle(
      Offset(size.width - 60, size.height - 40),
      160,
      Paint()
        ..color = rose
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 80),
    );
  }

  @override
  bool shouldRepaint(covariant _DiffuseCirclePainter oldDelegate) =>
      oldDelegate.lavender != lavender || oldDelegate.rose != rose;
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eyebrowStyle =
        Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontSize: 12, letterSpacing: 1.1) ??
        const TextStyle(fontSize: 12, letterSpacing: 1.1);
    final titleStyle = Theme.of(context).textTheme.displayMedium?.copyWith(
      color: scheme.onPrimaryContainer,
      height: 1.15,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.surface.withValues(alpha: 0.82),
                  width: 2,
                ),
                image: const DecorationImage(
                  image: AssetImage('assets/images/lacia.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  'PERSONAL NOTES · CODE & LIFE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: eyebrowStyle.copyWith(color: scheme.primary),
                ),
              ),
            ),
          ],
        ).fadeSlideIn(),
        const SizedBox(height: AppSpacing.sm + 4),
        Text('写代码，记生活。', style: titleStyle).fadeSlideIn(delay: 80.ms),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          '代码开发、AI 学习，以及值得记住的普通日子。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
          ),
        ).fadeSlideIn(delay: 140.ms),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton(
              onPressed: () => context.go('/contents'),
              child: const Text('开始阅读'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/about'),
              child: const Text('认识我'),
            ),
          ],
        ).fadeSlideIn(delay: 200.ms),
      ],
    );
  }
}

class _FeaturedStory extends StatelessWidget {
  const _FeaturedStory({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return AppInteractiveCard(
      borderRadius: 18,
      onTap: () => context.go('/contents/${content.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CoverImage(url: content.coverUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.overlayDark],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  content.pinned ? '精选置顶' : '本期推荐',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.onOverlay),
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.type.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onOverlayMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.onOverlay,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  content.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onOverlayMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).fadeSlideIn(delay: 120.ms);
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedEdit01,
          size: 72,
          color: scheme.primary.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

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

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _CoverPlaceholder();
    return CachedNetworkImage(
      imageUrl: resolveMediaUrl(url),
      fit: BoxFit.cover,
      width: double.infinity,
      memCacheWidth: 1000,
      errorWidget: (context, url, error) => const _CoverPlaceholder(),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedBook01,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedIdea01,
            color: scheme.secondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '愿这里的记录，能给正在解决相似问题的你一点启发。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => context.go('/about'),
            child: const Text('关于'),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(child: Text(message)),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
