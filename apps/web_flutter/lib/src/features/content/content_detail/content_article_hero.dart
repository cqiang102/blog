part of '../content_detail_page.dart';

class _ArticleHero extends StatelessWidget {
  const _ArticleHero({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          image: true,
          label: '${content.title}的封面',
          excludeSemantics: true,
          child: _HeroCover(content: content),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x24000000), Color(0x18000000), Color(0xC9000000)],
              stops: [0, 0.46, 1],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          bottom: 92,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: const Color(0x38FFFFFF)),
            ),
            child: Text(
              'PERSONAL NOTES · ${content.type.label}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onOverlay,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    if (content.coverUrl.isEmpty) {
      return const _HeroPlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: resolveMediaUrl(content.coverUrl),
      fit: BoxFit.cover,
      memCacheWidth: 1200,
      placeholder: (context, url) => const _HeroPlaceholder(),
      errorWidget: (context, url, error) => const _HeroPlaceholder(),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedBook01,
          size: 56,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
