import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/sample_data.dart';

class ContentListPage extends StatefulWidget {
  const ContentListPage({super.key});

  @override
  State<ContentListPage> createState() => _ContentListPageState();
}

class _ContentListPageState extends State<ContentListPage> {
  final _searchController = TextEditingController();
  ContentType? _type;
  String? _tag;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = sampleContents.expand((item) => item.tags).toSet().toList();
    final query = _searchController.text.trim().toLowerCase();
    final filtered = sampleContents.where((item) {
      final matchesQuery = query.isEmpty || item.title.toLowerCase().contains(query) || item.summary.toLowerCase().contains(query);
      final matchesType = _type == null || item.type == _type;
      final matchesTag = _tag == null || item.tags.contains(_tag);
      return matchesQuery && matchesType && matchesTag;
    }).toList();

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('全部内容')),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索标题、摘要',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('全部类型'),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                  for (final type in ContentType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('全部标签'),
                    selected: _tag == null,
                    onSelected: (_) => setState(() => _tag = null),
                  ),
                  for (final tag in tags)
                    FilterChip(
                      label: Text(tag),
                      selected: _tag == tag,
                      onSelected: (_) => setState(() => _tag = tag),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              for (final item in filtered) ...[
                _ContentRow(content: item),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContentRow extends StatelessWidget {
  const _ContentRow({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/contents/${content.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  content.coverUrl,
                  width: 132,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(content.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(label: Text(content.type.label), visualDensity: VisualDensity.compact),
                        for (final tag in content.tags) Chip(label: Text(tag), visualDensity: VisualDensity.compact),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
