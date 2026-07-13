part of '../content_list_page.dart';

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          AppMotion.reduce(context)
              ? Text(
                  '正在整理内容',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : AnimatedTextKit(
                  isRepeatingAnimation: true,
                  repeatForever: true,
                  pause: const Duration(milliseconds: 1500),
                  animatedTexts: [
                    RotateAnimatedText(
                      '正在整理内容',
                      textStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    RotateAnimatedText(
                      '马上就好',
                      textStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    RotateAnimatedText(
                      '稍等一下',
                      textStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('没有找到匹配的内容', style: Theme.of(context).textTheme.titleMedium),
          if (onClear != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onClear, child: const Text('清空筛选')),
          ],
        ],
      ),
    );
  }
}

class _NoMoreContent extends StatelessWidget {
  const _NoMoreContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(
          '已经到底了',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCloudOff,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
