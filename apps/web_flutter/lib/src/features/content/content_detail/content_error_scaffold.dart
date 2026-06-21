part of '../content_detail_page.dart';

class _ContentErrorScaffold extends StatelessWidget {
  const _ContentErrorScaffold({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notFound =
        error is ApiException && (error as ApiException).statusCode == 404;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('内容详情'),
        actions: const [
          AppThemeToggle(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: notFound
                            ? HugeIcons.strokeRoundedFileNotFound
                            : HugeIcons.strokeRoundedCloudOff,
                        size: 36,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      notFound ? '这篇内容已不可用' : '内容加载失败',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      notFound ? '内容可能已归档、删除，或当前链接已经失效。' : error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: () => context.go('/contents'),
                          child: const Text('返回全部内容'),
                        ),
                        OutlinedButton(
                          onPressed: onRetry,
                          child: const Text('重新检查'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 评论列表组件（使用 SliverList 优化性能）
// ============================================================================
