part of 'home_view.dart';

class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedIdea01,
            color: scheme.secondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '愿这里的记录，能给正在解决相似问题的你一点启发。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => context.go('/about'),
            child: const Text('关于'),
          ),
        ],
      ),
    );
  }
}
