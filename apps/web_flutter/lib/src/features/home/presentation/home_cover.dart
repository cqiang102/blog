part of 'home_view.dart';

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
