// 管理后台 - 内容管理标签页
// 展示内容列表，支持 CRUD 操作，搜索筛选，通过独立页面编辑内容
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../state/state.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';

/// 内容管理标签页
class AdminContentTab extends ConsumerStatefulWidget {
  const AdminContentTab({super.key});

  @override
  ConsumerState<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends ConsumerState<AdminContentTab> {
  final _searchController = TextEditingController();
  ContentStatus? _statusFilter;
  ContentType? _typeFilter;
  bool _includeDeleted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 用当前筛选条件更新查询状态并强制 refetch
  void _applyFilters() {
    ref.read(adminContentQueryProvider.notifier).update(AdminContentQuery(
      query: _searchController.text.trim(),
      status: _statusFilter,
      type: _typeFilter,
      includeDeleted: _includeDeleted,
    ));
    ref.invalidate(adminContentsProvider);
  }

  void _clearFilters() {
    _searchController.clear();
    _statusFilter = null;
    _typeFilter = null;
    _includeDeleted = false;
    ref.read(adminContentQueryProvider.notifier).update(
          const AdminContentQuery(),
        );
    ref.invalidate(adminContentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final contents = ref.watch(adminContentsProvider);

    return contents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminContentsProvider),
      ),
      data: (page) => _ContentList(
        page: page,
        searchController: _searchController,
        statusFilter: _statusFilter,
        typeFilter: _typeFilter,
        includeDeleted: _includeDeleted,
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
        onCreate: () => _navigateToEditor(context),
        onEdit: (content) => _navigateToEditor(context, contentId: content.id),
        onDelete: (content) => _deleteContent(context, content),
        onRestore: (content) => _restoreContent(context, content),
      ),
    );
  }

  Future<void> _navigateToEditor(
    BuildContext context, {
    String? contentId,
  }) async {
    final path = contentId != null
        ? '/admin/contents/$contentId/edit'
        : '/admin/contents/new';
    await context.push(path);
    if (mounted) {
      ref.invalidate(adminContentsProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);
    }
  }

  Future<void> _deleteContent(
    BuildContext context,
    AdminContentItem content,
  ) async {
    if (!context.mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除内容',
      message: '确认删除「${content.title}」？删除后可在"显示已删除"中恢复。',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .archiveAdminContent(accessToken: token, id: content.id);
      ref.invalidate(adminContentsProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);
      if (!context.mounted) return;
      showAdminSnack(context, '内容已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  Future<void> _restoreContent(
    BuildContext context,
    AdminContentItem content,
  ) async {
    if (!context.mounted) return;
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
      ref.invalidate(adminContentsProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);
      if (!context.mounted) return;
      showAdminSnack(context, '内容已恢复');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }
}

/// 内容列表组件
class _ContentList extends StatelessWidget {
  const _ContentList({
    required this.page,
    required this.searchController,
    required this.statusFilter,
    required this.typeFilter,
    required this.includeDeleted,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
    required this.onToggleIncludeDeleted,
    required this.onApply,
    required this.onClear,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final PageResult<AdminContentItem> page;
  final TextEditingController searchController;
  final ContentStatus? statusFilter;
  final ContentType? typeFilter;
  final bool includeDeleted;
  final ValueChanged<ContentStatus?> onStatusFilterChanged;
  final ValueChanged<ContentType?> onTypeFilterChanged;
  final ValueChanged<bool> onToggleIncludeDeleted;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final VoidCallback onCreate;
  final ValueChanged<AdminContentItem> onEdit;
  final ValueChanged<AdminContentItem> onDelete;
  final ValueChanged<AdminContentItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        final content = page.items[index - 1];
        return _ContentAdminRow(
          content: content,
          onEdit: content.deleted ? null : () => onEdit(content),
          onDelete: content.deleted ? null : () => onDelete(content),
          onRestore: content.deleted ? () => onRestore(content) : null,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionToolbar(
          title: '内容管理',
          actionLabel: '新增内容',
          actionIcon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
          onAction: onCreate,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        _ContentFilters(
          searchController: searchController,
          statusFilter: statusFilter,
          typeFilter: typeFilter,
          includeDeleted: includeDeleted,
          onStatusFilterChanged: onStatusFilterChanged,
          onTypeFilterChanged: onTypeFilterChanged,
          onToggleIncludeDeleted: onToggleIncludeDeleted,
          onApply: onApply,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          '共 ${page.total} 条内容',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (page.items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无内容'),
        ],
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    );
  }
}

/// 内容筛选组件
class _ContentFilters extends StatelessWidget {
  const _ContentFilters({
    required this.searchController,
    required this.statusFilter,
    required this.typeFilter,
    required this.includeDeleted,
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
  final ValueChanged<ContentStatus?> onStatusFilterChanged;
  final ValueChanged<ContentType?> onTypeFilterChanged;
  final ValueChanged<bool> onToggleIncludeDeleted;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm + 4,
      runSpacing: AppSpacing.sm + 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: '搜索标题或摘要',
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 20,
              ),
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<ContentStatus?>(
            value: statusFilter,
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
          width: 150,
          child: DropdownButtonFormField<ContentType?>(
            value: typeFilter,
            decoration: const InputDecoration(labelText: '类型'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部类型')),
              DropdownMenuItem(
                value: ContentType.markdown,
                child: Text('文章'),
              ),
              DropdownMenuItem(
                value: ContentType.image,
                child: Text('图片'),
              ),
              DropdownMenuItem(
                value: ContentType.video,
                child: Text('视频'),
              ),
            ],
            onChanged: onTypeFilterChanged,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('显示已删除',
                style: Theme.of(context).textTheme.bodySmall),
            Switch(
              value: includeDeleted,
              onChanged: onToggleIncludeDeleted,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: onApply,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedFilter),
          label: const Text('筛选'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
          label: const Text('清空'),
        ),
      ],
    );
  }
}

/// 内容管理行组件
class _ContentAdminRow extends StatelessWidget {
  const _ContentAdminRow({
    required this.content,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final AdminContentItem content;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final publishedAt = formatAdminDate(content.publishedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: AppSpacing.sm + 4),
            _buildTags(context),
            const SizedBox(height: 10),
            _buildStats(context, publishedAt),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminMediaThumb(
          url: content.coverUrl,
          type: MediaAssetType.image,
          size: const Size(96, 64),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: InkWell(
            onTap: content.deleted
                ? null
                : () => context.go('/contents/${content.id}'),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: content.deleted
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  content.summary.isEmpty ? content.slug : content.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: '编辑',
          onPressed: onEdit,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit01),
        ),
        if (onRestore != null)
          IconButton(
            tooltip: '恢复',
            onPressed: onRestore,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: Theme.of(context).colorScheme.primary,
            ),
          )
        else
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedDelete01,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }

  Widget _buildTags(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AdminStatusChip(status: content.status),
        if (content.deleted)
          Chip(
            label: const Text('已删除'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        Chip(label: Text(content.type.label)),
        if (content.pinned)
          const Chip(
            avatar: HugeIcon(icon: HugeIcons.strokeRoundedPin, size: 18),
            label: Text('置顶'),
          ),
        Chip(
          avatar:
              const HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 18),
          label: Text('${content.mediaCount} 个媒体'),
        ),
        if (content.coverMediaId.isNotEmpty)
          const Chip(
            avatar: HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 18),
            label: Text('有封面'),
          ),
        for (final tag in content.tags) Chip(label: Text(tag.name)),
      ],
    );
  }

  Widget _buildStats(BuildContext context, String publishedAt) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        AdminMetaText(
          icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedFavourite, size: 18),
          text: '${content.likeCount}',
        ),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedView, size: 18),
          text: '${content.viewCount}',
        ),
        AdminMetaText(
          icon:
              const HugeIcon(icon: HugeIcons.strokeRoundedMessage01, size: 18),
          text: '${content.commentCount}',
        ),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18),
          text: publishedAt,
        ),
      ],
    );
  }
}
