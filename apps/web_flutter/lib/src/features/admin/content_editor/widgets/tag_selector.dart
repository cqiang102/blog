import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../../../theme/app_spacing.dart';

class TagSelector extends StatelessWidget {
  const TagSelector({
    super.key,
    required this.tags,
    required this.selectedSlugs,
    required this.onToggle,
    this.showTitle = true,
  });

  final List<TagItem> tags;
  final Set<String> selectedSlugs;
  final ValueChanged<String> onToggle;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text('标签', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (tags.isEmpty)
          Text(
            '暂无标签',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag.name),
                  selected: selectedSlugs.contains(tag.slug),
                  onSelected: (_) => onToggle(tag.slug),
                ),
            ],
          ),
      ],
    );
  }
}
