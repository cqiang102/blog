import 'package:flutter/material.dart';

import '../../../../core/models.dart';

/// 标签选择器
/// 使用 FilterChip 展示可选标签，支持多选
class TagSelector extends StatelessWidget {
  const TagSelector({
    super.key,
    required this.tags,
    required this.selectedSlugs,
    required this.onToggle,
  });

  final List<TagItem> tags;
  final Set<String> selectedSlugs;
  final void Function(String slug) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '标签',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
