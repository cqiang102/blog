part of '../content_admin_tab.dart';

class _DesktopContentTable extends StatelessWidget {
  const _DesktopContentTable({
    required this.items,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
    required this.onRestore,
  });

  final List<AdminContentItem> items;
  final ValueChanged<AdminContentItem> onEdit;
  final ValueChanged<AdminContentItem> onPreview;
  final ValueChanged<AdminContentItem> onDelete;
  final ValueChanged<AdminContentItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _TableHeader(),
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _DesktopContentRow(
              content: items[index],
              onEdit: items[index].deleted ? null : () => onEdit(items[index]),
              onPreview:
                  items[index].deleted ||
                      items[index].status != ContentStatus.published
                  ? null
                  : () => onPreview(items[index]),
              onDelete: items[index].deleted
                  ? null
                  : () => onDelete(items[index]),
              onRestore: items[index].deleted
                  ? () => onRestore(items[index])
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: 5, child: Text('内容', style: style)),
            SizedBox(width: 128, child: Text('状态 / 类型', style: style)),
            SizedBox(width: 178, child: Text('互动数据', style: style)),
            SizedBox(width: 124, child: Text('发布时间', style: style)),
            SizedBox(
              width: 132,
              child: Text('操作', textAlign: TextAlign.end, style: style),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopContentRow extends StatelessWidget {
  const _DesktopContentRow({
    required this.content,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
    required this.onRestore,
  });

  final AdminContentItem content;
  final VoidCallback? onEdit;
  final VoidCallback? onPreview;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onEdit != null,
      label: '编辑${content.title}',
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(flex: 5, child: _ContentIdentity(content: content)),
              SizedBox(
                width: 128,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _CompactBadge(
                      label: content.deleted ? '已删除' : content.status.label,
                      tone: content.deleted
                          ? _BadgeTone.error
                          : _statusTone(content.status),
                    ),
                    _CompactBadge(label: content.type.label),
                    if (content.pinned)
                      const _CompactBadge(
                        label: '置顶',
                        tone: _BadgeTone.primary,
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 178,
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Metric(
                      icon: HugeIcons.strokeRoundedView,
                      value: content.viewCount,
                      tooltip: '浏览',
                    ),
                    _Metric(
                      icon: HugeIcons.strokeRoundedFavourite,
                      value: content.likeCount,
                      tooltip: '点赞',
                    ),
                    _Metric(
                      icon: HugeIcons.strokeRoundedMessage01,
                      value: content.commentCount,
                      tooltip: '评论',
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 124,
                child: Text(
                  formatAdminDate(content.publishedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: 132,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: onPreview == null ? '仅已发布内容可预览' : '预览',
                      onPressed: onPreview,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedView,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      tooltip: '编辑',
                      onPressed: onEdit,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedEdit01,
                        size: 20,
                      ),
                    ),
                    if (onRestore != null)
                      IconButton(
                        tooltip: '恢复',
                        onPressed: onRestore,
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedRefresh,
                          size: 20,
                        ),
                      )
                    else
                      IconButton(
                        tooltip: '删除',
                        onPressed: onDelete,
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete01,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentIdentity extends StatelessWidget {
  const _ContentIdentity({required this.content});

  final AdminContentItem content;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        AdminMediaThumb(
          url: content.coverUrl,
          type: MediaAssetType.image,
          size: const Size(72, 52),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                content.summary.isEmpty ? content.slug : content.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: muted),
              ),
              if (content.tags.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  content.tags.take(3).map((tag) => '#${tag.name}').join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileContentCard extends StatelessWidget {
  const _MobileContentCard({
    required this.content,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
    required this.onRestore,
  });

  final AdminContentItem content;
  final VoidCallback? onEdit;
  final VoidCallback? onPreview;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContentIdentity(content: content),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CompactBadge(
                    label: content.deleted ? '已删除' : content.status.label,
                    tone: content.deleted
                        ? _BadgeTone.error
                        : _statusTone(content.status),
                  ),
                  _CompactBadge(label: content.type.label),
                  if (content.pinned)
                    const _CompactBadge(label: '置顶', tone: _BadgeTone.primary),
                  _CompactBadge(label: '${content.mediaCount} 个媒体'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(
                    icon: HugeIcons.strokeRoundedView,
                    value: content.viewCount,
                    tooltip: '浏览',
                  ),
                  const SizedBox(width: 14),
                  _Metric(
                    icon: HugeIcons.strokeRoundedFavourite,
                    value: content.likeCount,
                    tooltip: '点赞',
                  ),
                  const SizedBox(width: 14),
                  _Metric(
                    icon: HugeIcons.strokeRoundedMessage01,
                    value: content.commentCount,
                    tooltip: '评论',
                  ),
                  const Spacer(),
                  Text(
                    formatAdminDate(content.publishedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onPreview,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedView,
                      size: 18,
                    ),
                    label: const Text('预览'),
                  ),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit01,
                      size: 18,
                    ),
                    label: const Text('编辑'),
                  ),
                  if (onRestore != null)
                    TextButton.icon(
                      onPressed: onRestore,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedRefresh,
                        size: 18,
                      ),
                      label: const Text('恢复'),
                    )
                  else
                    IconButton(
                      tooltip: '删除',
                      onPressed: onDelete,
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedDelete01,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
