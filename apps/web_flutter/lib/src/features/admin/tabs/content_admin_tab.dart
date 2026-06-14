import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../core/models.dart';
import '../../../state/state.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';

class AdminContentTab extends ConsumerStatefulWidget {
  const AdminContentTab({super.key});

  @override
  ConsumerState<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends ConsumerState<AdminContentTab> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  late ContentStatus? _statusFilter;
  late ContentType? _typeFilter;
  late bool _includeDeleted;
  bool _correctingPage = false;

  @override
  void initState() {
    super.initState();
    final query = ref.read(adminContentQueryProvider);
    _searchController = TextEditingController(text: query.query);
    _statusFilter = query.status;
    _typeFilter = query.type;
    _includeDeleted = query.includeDeleted;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _applyFilters);
  }

  void _applyFilters() {
    _searchDebounce?.cancel();
    final previous = ref.read(adminContentQueryProvider);
    final next = AdminContentQuery(
      query: _searchController.text.trim(),
      status: _statusFilter,
      type: _typeFilter,
      includeDeleted: _includeDeleted,
      size: previous.size,
    );
    ref.read(adminContentQueryProvider.notifier).update(next);
    if (next == previous) {
      ref.invalidate(adminContentsProvider);
    }
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    final size = ref.read(adminContentQueryProvider).size;
    setState(() {
      _searchController.clear();
      _statusFilter = null;
      _typeFilter = null;
      _includeDeleted = false;
    });
    ref
        .read(adminContentQueryProvider.notifier)
        .update(AdminContentQuery(size: size));
  }

  void _changePage(int page) {
    final query = ref.read(adminContentQueryProvider);
    if (page < 0 || page == query.page) return;
    ref
        .read(adminContentQueryProvider.notifier)
        .update(query.copyWith(page: page));
  }

  void _changePageSize(int size) {
    final query = ref.read(adminContentQueryProvider);
    ref
        .read(adminContentQueryProvider.notifier)
        .update(query.copyWith(page: 0, size: size));
  }

  @override
  Widget build(BuildContext context) {
    final contents = ref.watch(adminContentsProvider);
    final query = ref.watch(adminContentQueryProvider);
    final page = contents.value;

    if (page == null && contents.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (page == null && contents.hasError) {
      return AdminErrorPane(
        message: contents.error.toString(),
        onRetry: () => ref.invalidate(adminContentsProvider),
      );
    }

    if (page!.items.isEmpty &&
        page.total > 0 &&
        query.page > 0 &&
        !_correctingPage) {
      _correctingPage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _correctingPage = false;
        _changePage(query.page - 1);
      });
    }

    return Stack(
      children: [
        _ContentList(
          page: page,
          query: query,
          searchController: _searchController,
          statusFilter: _statusFilter,
          typeFilter: _typeFilter,
          includeDeleted: _includeDeleted,
          errorMessage: contents.hasError ? contents.error.toString() : null,
          onSearchChanged: _scheduleSearch,
          onStatusFilterChanged: (value) {
            setState(() => _statusFilter = value);
            _applyFilters();
          },
          onTypeFilterChanged: (value) {
            setState(() => _typeFilter = value);
            _applyFilters();
          },
          onToggleIncludeDeleted: (value) {
            setState(() => _includeDeleted = value);
            _applyFilters();
          },
          onApply: _applyFilters,
          onClear: _clearFilters,
          onRefresh: () => ref.refresh(adminContentsProvider.future),
          onPageChanged: _changePage,
          onPageSizeChanged: _changePageSize,
          onCreate: () => _navigateToEditor(context),
          onEdit: (content) =>
              _navigateToEditor(context, contentId: content.id),
          onPreview: (content) => context.go('/contents/${content.id}'),
          onDelete: (content) => _deleteContent(context, content),
          onRestore: (content) => _restoreContent(context, content),
        ),
        if (contents.isLoading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  void _navigateToEditor(BuildContext context, {String? contentId}) {
    final path = contentId == null
        ? '/admin/contents/new'
        : '/admin/contents/$contentId/edit';
    context.go(path);
  }

  Future<void> _deleteContent(
    BuildContext context,
    AdminContentItem content,
  ) async {
    final confirmed = await adminConfirm(
      context,
      title: '删除内容',
      message: '确认删除「${content.title}」？删除后可在“显示已删除”中恢复。',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .archiveAdminContent(accessToken: token, id: content.id);
      _refreshRelatedData();
      if (context.mounted) showAdminSnack(context, '内容已删除');
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, error.message);
    } catch (error) {
      if (context.mounted) showAdminSnack(context, error.toString());
    }
  }

  Future<void> _restoreContent(
    BuildContext context,
    AdminContentItem content,
  ) async {
    final confirmed = await adminConfirm(
      context,
      title: '恢复内容',
      message: '确认恢复「${content.title}」？',
      action: '恢复',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .restoreAdminContent(accessToken: token, id: content.id);
      _refreshRelatedData();
      if (context.mounted) showAdminSnack(context, '内容已恢复');
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, error.message);
    } catch (error) {
      if (context.mounted) showAdminSnack(context, error.toString());
    }
  }

  void _refreshRelatedData() {
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(recommendationsProvider);
  }
}

class _ContentList extends StatelessWidget {
  const _ContentList({
    required this.page,
    required this.query,
    required this.searchController,
    required this.statusFilter,
    required this.typeFilter,
    required this.includeDeleted,
    required this.errorMessage,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
    required this.onToggleIncludeDeleted,
    required this.onApply,
    required this.onClear,
    required this.onRefresh,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
    required this.onRestore,
  });

  final PageResult<AdminContentItem> page;
  final AdminContentQuery query;
  final TextEditingController searchController;
  final ContentStatus? statusFilter;
  final ContentType? typeFilter;
  final bool includeDeleted;
  final String? errorMessage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ContentStatus?> onStatusFilterChanged;
  final ValueChanged<ContentType?> onTypeFilterChanged;
  final ValueChanged<bool> onToggleIncludeDeleted;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback onCreate;
  final ValueChanged<AdminContentItem> onEdit;
  final ValueChanged<AdminContentItem> onPreview;
  final ValueChanged<AdminContentItem> onDelete;
  final ValueChanged<AdminContentItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1040;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              constraints.maxWidth < 700 ? AppSpacing.md : AppSpacing.lg,
            ),
            children: [
              _ContentHeader(onCreate: onCreate),
              const SizedBox(height: AppSpacing.md),
              _ContentFilters(
                searchController: searchController,
                statusFilter: statusFilter,
                typeFilter: typeFilter,
                includeDeleted: includeDeleted,
                onSearchChanged: onSearchChanged,
                onStatusFilterChanged: onStatusFilterChanged,
                onTypeFilterChanged: onTypeFilterChanged,
                onToggleIncludeDeleted: onToggleIncludeDeleted,
                onApply: onApply,
                onClear: onClear,
              ),
              const SizedBox(height: AppSpacing.md),
              if (errorMessage != null) ...[
                _RefreshErrorBanner(message: errorMessage!, onRetry: onApply),
                const SizedBox(height: AppSpacing.md),
              ],
              _ResultSummary(
                page: page,
                pageSize: query.size,
                onPageSizeChanged: onPageSizeChanged,
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              if (page.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AdminEmptyPane(message: '没有符合条件的内容'),
                )
              else if (desktop)
                _DesktopContentTable(
                  items: page.items,
                  onEdit: onEdit,
                  onPreview: onPreview,
                  onDelete: onDelete,
                  onRestore: onRestore,
                )
              else
                ...page.items.map(
                  (content) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                    child: _MobileContentCard(
                      content: content,
                      onEdit: content.deleted ? null : () => onEdit(content),
                      onPreview:
                          content.deleted ||
                              content.status != ContentStatus.published
                          ? null
                          : () => onPreview(content),
                      onDelete: content.deleted
                          ? null
                          : () => onDelete(content),
                      onRestore: content.deleted
                          ? () => onRestore(content)
                          : null,
                    ),
                  ),
                ),
              if (page.total > 0) ...[
                const SizedBox(height: AppSpacing.md),
                _PaginationBar(
                  page: page.page,
                  pageSize: page.size,
                  total: page.total,
                  onChanged: onPageChanged,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '内容管理',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '统一维护文章、图片和视频内容',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        final action = FilledButton.icon(
          onPressed: onCreate,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
          label: const Text('新增内容'),
        );

        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 12), action],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            action,
          ],
        );
      },
    );
  }
}

class _ContentFilters extends StatelessWidget {
  const _ContentFilters({
    required this.searchController,
    required this.statusFilter,
    required this.typeFilter,
    required this.includeDeleted,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
    required this.onToggleIncludeDeleted,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController searchController;
  final ContentStatus? statusFilter;
  final ContentType? typeFilter;
  final bool includeDeleted;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ContentStatus?> onStatusFilterChanged;
  final ValueChanged<ContentType?> onTypeFilterChanged;
  final ValueChanged<bool> onToggleIncludeDeleted;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: '搜索标题或摘要',
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 20,
                  ),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          onPressed: () {
                            searchController.clear();
                            onApply();
                          },
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 18,
                          ),
                        ),
                ),
                textInputAction: TextInputAction.search,
                onChanged: onSearchChanged,
                onSubmitted: (_) => onApply(),
              ),
            ),
            SizedBox(
              width: 156,
              child: DropdownButtonFormField<ContentStatus?>(
                key: ValueKey(statusFilter),
                initialValue: statusFilter,
                decoration: const InputDecoration(labelText: '状态'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部状态')),
                  DropdownMenuItem(
                    value: ContentStatus.draft,
                    child: Text('草稿'),
                  ),
                  DropdownMenuItem(
                    value: ContentStatus.published,
                    child: Text('已发布'),
                  ),
                  DropdownMenuItem(
                    value: ContentStatus.archived,
                    child: Text('已归档'),
                  ),
                ],
                onChanged: onStatusFilterChanged,
              ),
            ),
            SizedBox(
              width: 156,
              child: DropdownButtonFormField<ContentType?>(
                key: ValueKey(typeFilter),
                initialValue: typeFilter,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部类型')),
                  DropdownMenuItem(
                    value: ContentType.markdown,
                    child: Text('文章'),
                  ),
                  DropdownMenuItem(value: ContentType.image, child: Text('图片')),
                  DropdownMenuItem(value: ContentType.video, child: Text('视频')),
                ],
                onChanged: onTypeFilterChanged,
              ),
            ),
            FilterChip(
              selected: includeDeleted,
              onSelected: onToggleIncludeDeleted,
              avatar: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete01,
                size: 18,
              ),
              label: const Text('显示已删除'),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 18,
              ),
              label: const Text('重置'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.page,
    required this.pageSize,
    required this.onPageSizeChanged,
  });

  final PageResult<AdminContentItem> page;
  final int pageSize;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final start = page.total == 0 ? 0 : page.page * page.size + 1;
    final end = (page.page * page.size + page.items.length).clamp(
      0,
      page.total,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            '共 ${page.total} 条，当前显示 $start–$end',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const Text('每页'),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: pageSize,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 20, child: Text('20')),
            DropdownMenuItem(value: 50, child: Text('50')),
          ],
          onChanged: (value) {
            if (value != null) onPageSizeChanged(value);
          },
        ),
      ],
    );
  }
}

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

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onChanged,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final totalPages = (total / pageSize).ceil().clamp(1, 1 << 20);
    final visiblePages = <int>{
      0,
      totalPages - 1,
      for (var value = page - 1; value <= page + 1; value++) value,
    }.where((value) => value >= 0 && value < totalPages).toList()..sort();

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        IconButton.outlined(
          tooltip: '上一页',
          onPressed: page > 0 ? () => onChanged(page - 1) : null,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 18,
          ),
        ),
        for (var index = 0; index < visiblePages.length; index++) ...[
          if (index > 0 && visiblePages[index] - visiblePages[index - 1] > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…'),
            ),
          if (visiblePages[index] == page)
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: Theme.of(context).colorScheme.primary,
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary,
                minimumSize: const Size(42, 42),
                padding: EdgeInsets.zero,
              ),
              child: Text('${visiblePages[index] + 1}'),
            )
          else
            OutlinedButton(
              onPressed: () => onChanged(visiblePages[index]),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(42, 42),
                padding: EdgeInsets.zero,
              ),
              child: Text('${visiblePages[index] + 1}'),
            ),
        ],
        IconButton.outlined(
          tooltip: '下一页',
          onPressed: page + 1 < totalPages ? () => onChanged(page + 1) : null,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            size: 18,
          ),
        ),
      ],
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
