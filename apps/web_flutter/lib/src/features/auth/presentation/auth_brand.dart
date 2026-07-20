part of 'auth_view.dart';

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heroStyle = Theme.of(
      context,
    ).textTheme.displaySmall?.copyWith(color: scheme.onPrimaryContainer);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/images/lacia.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Text('沐凉·日记', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              const AppThemeToggle(),
            ],
          ),
          const Spacer(),
          AppMotion.reduce(context)
              ? Text('欢迎回来，\n继续写下新的故事。', style: heroStyle)
              : AnimatedTextKit(
                  isRepeatingAnimation: false,
                  totalRepeatCount: 1,
                  animatedTexts: [
                    TypewriterAnimatedText(
                      '欢迎回来，\n继续写下新的故事。',
                      speed: const Duration(milliseconds: 80),
                      textStyle: heroStyle,
                      cursor: '|',
                    ),
                  ],
                ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '登录后可以参与评论、收藏喜欢的内容，并与博客 AI 助手继续对话。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _BrandFeature(label: '参与文章讨论').fadeSlideIn(delay: 400.ms),
          const SizedBox(height: AppSpacing.sm + 4),
          const _BrandFeature(label: '保存你的阅读足迹').fadeSlideIn(delay: 500.ms),
          const SizedBox(height: AppSpacing.sm + 4),
          const _BrandFeature(
            label: '使用个人知识库 AI 助手',
          ).fadeSlideIn(delay: 600.ms),
          const Spacer(),
          Text(
            '写代码，也记录生活。',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MobileAuthBrand extends StatelessWidget {
  const _MobileAuthBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '沐凉·日记',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const AppThemeToggle(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '登录后继续阅读、交流与探索。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
