import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/models.dart';
import '../../core/sample_data.dart';

class ContentDetailPage extends StatelessWidget {
  const ContentDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    final content = sampleContents.firstWhere(
      (item) => item.id == id,
      orElse: () => sampleContents.first,
    );

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          title: Text(content.title),
          flexibleSpace: FlexibleSpaceBar(
            background: Image.network(content.coverUrl, fit: BoxFit.cover),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(content.type.label)),
                  for (final tag in content.tags) Chip(label: Text(tag)),
                ],
              ),
              const SizedBox(height: 16),
              Text(content.summary, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              _ContentViewer(content: content),
              const SizedBox(height: 32),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_outline),
                    label: Text('点赞 ${content.likeCount}'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.mode_comment_outlined),
                    label: const Text('评论'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const TextField(
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '写下你的评论',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContentViewer extends StatelessWidget {
  const _ContentViewer({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return switch (content.type) {
      ContentType.text || ContentType.article => Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: MarkdownBody(data: content.markdown, selectable: true),
          ),
        ),
      ContentType.image => _ImageGallery(urls: content.mediaUrls),
      ContentType.video => _VideoPlaceholder(content: content),
    };
  }
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 560 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: urls.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(urls[index], fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(content.coverUrl, fit: BoxFit.cover),
            ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
            Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 80,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
