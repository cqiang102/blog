import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_providers.dart';
import '../../core/models.dart';

class ContentListPage extends ConsumerStatefulWidget {
  const ContentListPage({super.key});

  @override
  ConsumerState<ContentListPage> createState() => _ContentListPageState();
}

class _ContentListPageState extends ConsumerState<ContentListPage> {
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
    final query = ContentListQuery(
      query: _searchController.text.trim(),
      tag: _tag,
      type: _type,
      size: 20,
    );
    final page = ref.watch(contentListProvider(query));

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
              page.maybeWhen(
                data:
                    (data) => _TagFilters(
                      contents: data.items,
                      selectedTag: _tag,
                      onSelected: (tag) => setState(() => _tag = tag),
                    ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              page.when(
                loading:
                    () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 56),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                error:
                    (error, stackTrace) => _ErrorPanel(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(contentListProvider(query)),
                    ),
                data: (data) {
                  if (data.items.isEmpty) {
                    return const _EmptyPanel();
                  }
                  return Column(
                    children: [
                      for (final item in data.items) ...[
                        _ContentRow(content: item),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagFilters extends StatelessWidget {
  const _TagFilters({
    required this.contents,
    required this.selectedTag,
    required this.onSelected,
  });

  final List<BlogContent> contents;
  final String? selectedTag;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final tags = contents.expand((item) => item.tags).toSet().toList()..sort();
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('全部标签'),
          selected: selectedTag == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final tag in tags)
          FilterChip(
            label: Text(tag),
            selected: selectedTag == tag,
            onSelected: (_) => onSelected(tag),
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
                child: _Thumb(url: content.coverUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          label: Text(content.type.label),
                          visualDensity: VisualDensity.compact,
                        ),
                        for (final tag in content.tags)
                          Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          ),
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return SizedBox(
        width: 132,
        height: 92,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.article_outlined),
        ),
      );
    }
    return Image.network(
      url,
      width: 132,
      height: 92,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) => SizedBox(
            width: 132,
            height: 92,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(child: Text('没有找到内容')),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
