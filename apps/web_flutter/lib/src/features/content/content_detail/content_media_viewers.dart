part of '../content_detail_page.dart';

// ============================================================================
// 内容查看器组件
// ============================================================================

class _ContentViewer extends StatelessWidget {
  const _ContentViewer({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return switch (content.type) {
      ContentType.markdown => _MarkdownArticle(content: content),
      ContentType.image => _ImageGallery(urls: content.mediaUrls),
      ContentType.video => _VideoPlayerWidget(content: content),
    };
  }
}

// ============================================================================
// 媒体空状态组件
// ============================================================================

class _MediaEmpty extends StatelessWidget {
  const _MediaEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label)),
      ),
    );
  }
}
