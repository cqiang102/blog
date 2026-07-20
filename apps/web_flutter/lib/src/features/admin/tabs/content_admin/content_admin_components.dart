part of '../content_admin_tab.dart';

enum _BadgeTone { neutral, primary, warning, error }

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.label, this.tone = _BadgeTone.neutral});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      _BadgeTone.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      _BadgeTone.warning => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      _BadgeTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      _BadgeTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

_BadgeTone _statusTone(ContentStatus status) {
  return switch (status) {
    ContentStatus.published => _BadgeTone.primary,
    ContentStatus.draft => _BadgeTone.warning,
    ContentStatus.archived => _BadgeTone.error,
  };
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.tooltip,
  });

  final List<List<dynamic>> icon;
  final int value;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 16),
          const SizedBox(width: 4),
          Text('$value', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        leading: HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          color: scheme.onErrorContainer,
        ),
        title: const Text('刷新失败，当前仍显示上一次的数据'),
        subtitle: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
      ),
    );
  }
}
