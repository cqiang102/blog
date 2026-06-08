// 首页模块
// 展示博客的轮播图、最新内容网格和最热内容网格，采用响应式布局
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_providers.dart';
import '../../core/constants.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

/// 首页 Widget
/// 使用 Riverpod 管理状态，展示推荐内容（置顶轮播、最新更新、点赞最多）
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(recommendationsProvider);
    final auth = ref.watch(authControllerProvider);

    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          title: const Text('个人博客'),
          actions: [
            IconButton(
              tooltip: auth.isAuthenticated ? '个人中心' : '登录',
              onPressed: () =>
                  context.go(auth.isAuthenticated ? '/profile' : '/login'),
              icon: Icon(auth.isAuthenticated ? Icons.person : Icons.login),
            ),
          ],
        ),

        // 内容区域
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm + 4,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          sliver: recommendations.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: _LoadingState(),
            ),
            error: (error, stackTrace) => SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(recommendationsProvider),
              ),
            ),
            data: (data) => SliverList.list(
              children: [
                // 轮播图
                _PinnedCarousel(contents: data.pinned),
                if (data.pinned.isNotEmpty)
                  const SizedBox(height: AppSpacing.xl - 4),

                // 最近更新
                _SectionHeader(
                  title: '最近更新',
                  actionLabel: '全部内容',
                  onAction: () => context.go('/contents'),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                _ContentGrid(contents: data.latest),
                const SizedBox(height: AppSpacing.xl - 4),

                // 点赞最多
                const _SectionHeader(title: '点赞最多'),
                const SizedBox(height: AppSpacing.sm + 4),
                _ContentGrid(contents: data.mostLiked),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 轮播图组件
// ============================================================================

/// 置顶内容轮播图组件
/// 展示带封面图、标题和摘要的可滑动轮播卡片
class _PinnedCarousel extends StatelessWidget {
  const _PinnedCarousel({required this.contents});

  final List<BlogContent> contents;

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: kCarouselHeight,
      child: PageView.builder(
        itemCount: contents.length,
        itemBuilder: (context, index) {
          final item = contents[index];
          return _CarouselCard(item: item);
        },
      ),
    );
  }
}

/// 轮播卡片组件
class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.item});

  final BlogContent item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/contents/${item.id}'),
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 封面图
            _CoverImage(url: item.coverUrl),

            // 渐变遮罩
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.overlayDark,
                  ],
                ),
              ),
            ),

            // 文字内容
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.type.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onOverlayMuted,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.onOverlay,
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.onOverlay,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 区域标题组件
// ============================================================================

/// 区域标题组件
/// 带有可选的操作按钮（如"全部内容"链接）
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

// ============================================================================
// 内容网格组件
// ============================================================================

/// 内容网格组件
/// 根据屏幕宽度自适应列数：>=1100显示3列，>=720显示2列，否则1列
class _ContentGrid extends StatelessWidget {
  const _ContentGrid({required this.contents});

  final List<BlogContent> contents;

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) {
      return const _EmptyState(message: '还没有发布内容');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= kDesktopBreakpoint
            ? 3
            : constraints.maxWidth >= kTabletBreakpoint
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contents.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio:
                columns == 1 ? kContentCardAspectRatioNarrow : kContentCardAspectRatioWide,
          ),
          itemBuilder: (context, index) =>
              _ContentCard(content: contents[index]),
        );
      },
    );
  }
}

/// 内容卡片组件
/// 展示单个内容的封面、类型、标题、摘要、点赞数和发布日期
class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy-MM-dd').format(content.publishedAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/contents/${content.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            Expanded(child: _CoverImage(url: content.coverUrl)),

            // 内容信息
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 类型标签
                  Text(
                    content.type.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),

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

                  // 统计信息
                  _ContentStats(
                    likeCount: content.likeCount,
                    date: date,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 内容统计信息组件
class _ContentStats extends StatelessWidget {
  const _ContentStats({
    required this.likeCount,
    required this.date,
  });

  final int likeCount;
  final String date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.favorite_outline, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$likeCount',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 12),
        Icon(Icons.schedule, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          date,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ============================================================================
// 封面图片组件
// ============================================================================

/// 封面图片组件
/// 使用 CachedNetworkImage 加载网络图片，加载失败时显示占位符
/// 优化：添加 memCacheWidth 限制内存占用
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const _CoverPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      memCacheWidth: 800, // 限制内存缓存宽度，优化内存占用
      errorWidget: (context, url, error) => const _CoverPlaceholder(),
    );
  }
}

/// 封面占位符组件
/// 无封面图片时显示的默认占位界面
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 44,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

/// 空状态组件
/// 内容列表为空时显示的提示信息
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
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
              message,
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

/// 错误状态组件
/// 数据加载失败时显示错误信息和重试按钮
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
