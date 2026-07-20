part of 'home_view.dart';

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
