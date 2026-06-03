// 首页模块
// 展示博客的轮播图、最新内容网格和最热内容网格，采用响应式布局
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_providers.dart';
import '../../core/models.dart';

/// 首页 Widget
/// 使用 Riverpod 管理状态，展示推荐内容（置顶轮播、最新更新、点赞最多）
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(recommendationsProvider); // 获取推荐内容数据
    final auth = ref.watch(authControllerProvider); // 获取认证状态

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('个人博客'),
          actions: [
            IconButton(
              tooltip: auth.isAuthenticated ? '个人中心' : '登录',
              onPressed:
                  () =>
                      context.go(auth.isAuthenticated ? '/profile' : '/login'),
              icon: Icon(auth.isAuthenticated ? Icons.person : Icons.login),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          sliver: recommendations.when(
            loading:
                () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (error, stackTrace) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(recommendationsProvider),
                  ),
                ),
            data:
                (data) => SliverList.list(
                  children: [
                    _PinnedCarousel(contents: data.pinned),
                    if (data.pinned.isNotEmpty) const SizedBox(height: 28),
                    _SectionHeader(
                      title: '最近更新',
                      actionLabel: '全部内容',
                      onAction: () => context.go('/contents'),
                    ),
                    const SizedBox(height: 12),
                    _ContentGrid(contents: data.latest),
                    const SizedBox(height: 28),
                    const _SectionHeader(title: '点赞最多'),
                    const SizedBox(height: 12),
                    _ContentGrid(contents: data.mostLiked),
                  ],
                ),
          ),
        ),
      ],
    );
  }
}

/// 置顶内容轮播图组件
/// 展示带封面图、标题和摘要的可滑动轮播卡片
class _PinnedCarousel extends StatelessWidget {
  const _PinnedCarousel({required this.contents});

  final List<BlogContent> contents; // 置顶内容列表

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) return const SizedBox.shrink(); // 无置顶内容时隐藏

    return SizedBox(
      height: 300,
      child: PageView.builder(
        itemCount: contents.length,
        itemBuilder: (context, index) {
          final item = contents[index];
          return InkWell(
            onTap: () => context.go('/contents/${item.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CoverImage(url: item.coverUrl),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.68),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.type.label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 区域标题组件
/// 带有可选的操作按钮（如"全部内容"链接）
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title; // 标题文本
  final String? actionLabel; // 操作按钮文本
  final VoidCallback? onAction; // 操作按钮点击回调

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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

/// 内容网格组件
/// 根据屏幕宽度自适应列数：>=1100显示3列，>=720显示2列，否则1列
class _ContentGrid extends StatelessWidget {
  const _ContentGrid({required this.contents});

  final List<BlogContent> contents; // 内容列表

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) {
      return const _EmptyState(message: '还没有发布内容');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式列数计算
        final columns =
            constraints.maxWidth >= 1100
                ? 3
                : constraints.maxWidth >= 720
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contents.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 2.4 : 1.35,
          ),
          itemBuilder:
              (context, index) => _ContentCard(content: contents[index]),
        );
      },
    );
  }
}

/// 内容卡片组件
/// 展示单个内容的封面、类型、标题、摘要、点赞数和发布日期
class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content});

  final BlogContent content; // 单个内容数据

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy-MM-dd').format(content.publishedAt); // 格式化发布日期
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/contents/${content.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _CoverImage(url: content.coverUrl)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.type.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.favorite_outline, size: 16),
                      const SizedBox(width: 4),
                      Text('${content.likeCount}'),
                      const SizedBox(width: 12),
                      const Icon(Icons.schedule, size: 16),
                      const SizedBox(width: 4),
                      Text(date),
                    ],
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

/// 封面图片组件
/// 使用 CachedNetworkImage 加载网络图片，加载失败时显示占位符
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String url; // 图片 URL

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const _CoverPlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
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

/// 空状态组件
/// 内容列表为空时显示的提示信息
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message; // 提示信息文本

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// 错误状态组件
/// 数据加载失败时显示错误信息和重试按钮
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message; // 错误信息
  final VoidCallback onRetry; // 重试回调

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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
