import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/sample_data.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final pinned = sampleContents.where((item) => item.pinned).toList();
    final latest = [...sampleContents]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final mostLiked = [...sampleContents]..sort((a, b) => b.likeCount.compareTo(a.likeCount));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('个人博客'),
          actions: [
            IconButton(
              tooltip: '登录',
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          sliver: SliverList.list(
            children: [
              _PinnedCarousel(contents: pinned),
              const SizedBox(height: 28),
              _SectionHeader(
                title: '最近更新',
                actionLabel: '全部内容',
                onAction: () => context.go('/contents'),
              ),
              const SizedBox(height: 12),
              _ContentGrid(contents: latest),
              const SizedBox(height: 28),
              const _SectionHeader(title: '点赞最多'),
              const SizedBox(height: 12),
              _ContentGrid(contents: mostLiked),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinnedCarousel extends StatelessWidget {
  const _PinnedCarousel({required this.contents});

  final List<BlogContent> contents;

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) return const SizedBox.shrink();

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
                  CachedNetworkImage(imageUrl: item.coverUrl, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.68)],
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
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
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
          child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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

class _ContentGrid extends StatelessWidget {
  const _ContentGrid({required this.contents});

  final List<BlogContent> contents;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 720 ? 2 : 1;
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
          itemBuilder: (context, index) => _ContentCard(content: contents[index]),
        );
      },
    );
  }
}

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
            Expanded(
              child: CachedNetworkImage(
                imageUrl: content.coverUrl,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(content.type.label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(content.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
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
