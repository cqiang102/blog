import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../../../theme/app_spacing.dart';

class TagSelector extends StatefulWidget {
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
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final visible = widget.tags.where((tag) {
      if (normalized.isEmpty) return true;
      return tag.name.toLowerCase().contains(normalized) ||
          tag.slug.toLowerCase().contains(normalized);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Text('标签', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          decoration: const InputDecoration(
            hintText: '搜索标签',
            prefixIcon: Icon(Icons.search, size: 20),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (visible.isEmpty)
          Text(
            '没有匹配的标签',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in visible)
                FilterChip(
                  label: Text(tag.name),
                  selected: widget.selectedSlugs.contains(tag.slug),
                  onSelected: (_) => widget.onToggle(tag.slug),
                ),
            ],
          ),
      ],
    );
  }
}
