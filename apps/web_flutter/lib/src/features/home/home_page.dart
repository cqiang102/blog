import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_providers.dart';
import '../../core/app_ui.dart';
import '../../core/constants.dart';
import '../../core/media_url.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

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
    final recommendations = ref.watch(recommendationsProvider);
    final auth = ref.watch(authControllerProvider);

    return AppPageFrame(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            toolbarHeight: 72,
            title: const Text('推荐阅读'),
            actions: [
              const AppThemeToggle(),
              IconButton(
                tooltip: auth.isAuthenticated ? '个人中心' : '登录',
                onPressed:
                    () => context.go(
                      auth.isAuthenticated ? '/profile' : '/login',
                    ),
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  child: Icon(
                    auth.isAuthenticated
                        ? Icons.person_outline_rounded
                        : Icons.login_rounded,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          ...recommendations.when(
            loading:
                () => const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _LoadingState(),
                  ),
                ],
            error:
                (error, stackTrace) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(recommendationsProvider),
                    ),
                  ),
                ],
            data: (data) => _buildContent(data),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(Recommendations data) {
    final featured =
        data.pinned.isNotEmpty
            ? data.pinned.first
            : data.latest.isNotEmpty
            ? data.latest.first
            : null;
    final latestWithoutFeatured =
        featured == null
            ? data.latest
            : data.latest.where((item) => item.id != featured.id).toList();
    final latest =
        latestWithoutFeatured.isEmpty ? data.latest : latestWithoutFeatured;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(child: _HomeHero(featured: featured)),
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
      if (latest.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: _LatestContent(contents: latest),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= kTabletBreakpoint;
          final intro = _HeroIntro(hasFeatured: featured != null);
          final story =
              featured == null
                  ? const _HeroPlaceholder()
                  : _FeaturedStory(content: featured!);

          if (!wide) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  intro,
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(height: 280, child: story),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Expanded(flex: 5, child: intro),
                const SizedBox(width: AppSpacing.xl),
                Expanded(flex: 6, child: SizedBox(height: 340, child: story)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro({required this.hasFeatured});

  final bool hasFeatured;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedTextKit(
            isRepeatingAnimation: true,
            repeatForever: true,
            animatedTexts: [
              ColorizeAnimatedText(
                'PERSONAL NOTES · CODE & LIFE',
                textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                ) ?? const TextStyle(letterSpacing: 1.1),
                colors: [
                  scheme.primary,
                  scheme.secondary,
                  scheme.tertiary,
                  scheme.primary,
                ],
                speed: const Duration(milliseconds: 400),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedTextKit(
          isRepeatingAnimation: false,
          totalRepeatCount: 1,
          animatedTexts: [
            TypewriterAnimatedText(
              '写代码，\n也记录生活。',
              speed: const Duration(milliseconds: 80),
              textStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
              cursor: '|',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '这里收藏工程实践、AI 探索，以及值得被记住的普通日子。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
        ),
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
    );
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
        child: Icon(
          Icons.edit_note_rounded,
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
            separatorBuilder:
                (context, index) => const SizedBox(height: AppSpacing.sm + 4),
            itemBuilder:
                (context, index) => _CompactStoryCard(content: contents[index]),
          );
        }

        final columns =
            constraints.crossAxisExtent >= kDesktopBreakpoint ? 3 : 2;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 344,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _StoryCard(content: contents[index]),
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
        _ContentStats(likeCount: content.likeCount, date: date),
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
    return Column(
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          _PopularRow(rank: index + 1, content: visible[index]),
          if (index != visible.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
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
    return AppInteractiveCard(
      onTap: () => context.go('/contents/${content.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                rank.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: rank <= 3 ? scheme.secondary : scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    content.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.favorite_rounded, size: 16, color: scheme.secondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${content.likeCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentStats extends StatelessWidget {
  const _ContentStats({required this.likeCount, required this.date});

  final int likeCount;
  final String date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Row(
      children: [
        Icon(
          Icons.favorite_border_rounded,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('$likeCount', style: style),
        const SizedBox(width: AppSpacing.sm + 4),
        Icon(Icons.schedule_rounded, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(date, style: style),
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
        child: Icon(
          Icons.auto_stories_outlined,
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
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: scheme.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '愿这里的记录，能给正在解决相似问题的你一点启发。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => context.go('/about'),
            child: const Text('关于我'),
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
            Icon(
              Icons.cloud_off_outlined,
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
