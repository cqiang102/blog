part of '../knowledge_admin_tab.dart';

/// 知识库索引状态组件
class _KnowledgeIndexStatus extends StatelessWidget {
  const _KnowledgeIndexStatus({
    required this.indexStatus,
    required this.reindexState,
    required this.onReindex,
    required this.onReset,
  });

  final AsyncValue<IndexStatus> indexStatus;
  final AsyncValue<ReindexResult?> reindexState;
  final VoidCallback onReindex;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedBrain,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    '向量索引状态',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildActionButton(context, scheme),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildStatusInfo(context, scheme),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '当嵌入模型不可用时，知识分块的向量生成会失败。'
              '模型恢复后可点击"重新索引失败项"补齐向量。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, ColorScheme scheme) {
    return reindexState.when(
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, _) => IconButton(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAlertCircle,
          color: scheme.error,
        ),
        tooltip: '重新索引失败，点击重试',
        onPressed: onReindex,
      ),
      data: (result) {
        if (result == null) {
          return indexStatus.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (status) {
              if (!status.needsReindex) return const SizedBox.shrink();
              return FilledButton.icon(
                onPressed: onReindex,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  size: 18,
                ),
                label: Text('重新索引失败项 (${status.failedChunks})'),
              );
            },
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              result.isAllSuccess ? Icons.check_circle : Icons.warning,
              color: result.isAllSuccess ? scheme.primary : scheme.error,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '成功 ${result.successCount}/${result.totalCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!result.isAllSuccess) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '失败 ${result.failCount}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 18,
              ),
              tooltip: '关闭',
              onPressed: onReset,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusInfo(BuildContext context, ColorScheme scheme) {
    return indexStatus.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(
        '无法获取索引状态',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.error),
      ),
      data: (status) {
        if (status.totalChunks == 0) {
          return Text(
            '暂无知识分块',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(
                  label: '总分块',
                  value: status.totalChunks.toString(),
                  color: scheme.surfaceContainerHighest,
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusChip(
                  label: '已索引',
                  value: status.chunksWithEmbedding.toString(),
                  color: scheme.primaryContainer,
                ),
                if (status.failedChunks > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _StatusChip(
                    label: '失败',
                    value: status.failedChunks.toString(),
                    color: scheme.errorContainer,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: status.indexRate / 100,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: status.needsReindex
                          ? scheme.error
                          : scheme.primary,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${status.indexRate.toStringAsFixed(1)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 状态标签组件
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
