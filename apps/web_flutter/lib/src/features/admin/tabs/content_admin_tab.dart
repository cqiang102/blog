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

class _AdminContentTabState extends ConsumerState<AdminContentTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ContentStatus? _statusFilter;
  ContentType? _typeFilter;
  bool _includeDeleted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AdminContentQuery get _query => AdminContentQuery(
        query: _searchQuery,
        status: _statusFilter,
        type: _typeFilter,
        includeDeleted: _includeDeleted,
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final contents = ref.watch(adminContentsProvider(_query));
    final tagsValue = ref.watch(adminTagsProvider);
    final tagError = tagsValue.maybeWhen(
      error: (error, stackTrace) => error.toString(),
      orElse: () => null,
    );

    return contents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminContentsProvider(_query)),
      ),
      data: (page) => _ContentList(
        page: page,
        tagError: tagError,
        searchController: _searchController,
        searchQuery: _searchQuery,
        statusFilter: _statusFilter,
        typeFilter: _typeFilter,
        includeDeleted: _includeDeleted,
        onSearchChanged: (value) {
          setState(() => _searchQuery = value);
        },
        onSearchSubmitted: (_) {
          ref.invalidate(adminContentsProvider(_query));
        },
        onStatusFilterChanged: (value) {
          setState(() => _statusFilter = value);
          ref.invalidate(adminContentsProvider(_query));
        },
        onTypeFilterChanged: (value) {
          setState(() => _typeFilter = value);
          ref.invalidate(adminContentsProvider(_query));
        },
        onToggleIncludeDeleted: (value) {
          setState(() => _includeDeleted = value);
          ref.invalidate(adminContentsProvider(_query));
        },
        onCreate: () => _navigateToEditor(context),
        onEdit: (content) => _navigateToEditor(context, contentId: content.id),
        onDelete: (content) => _deleteContent(context, ref, content),
        onRestore: (content) => _restoreContent(context, ref, content),
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
      ref.invalidate(adminContentsProvider(_query));
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);
    }
  }

  Future<void> _deleteContent(
    BuildContext context,
    WidgetRef ref,
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
      ref.invalidate(adminContentsProvider(_query));
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
    WidgetRef ref,
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
      ref.invalidate(adminContentsProvider(_query));
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
    required this.tagError,
    required this.searchController,
    required this.searchQuery,
    required this.statusFilter,
    required this.typeFilter,
    required this.includeDeleted,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onStatusFilterChanged,
    required this.onTypeFilterChanged,
    required this.onToggleIncludeDeleted,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final PageResult<AdminContentItem> page;
  final String? tagError;
  final TextEditingController searchController;
  final String searchQuery;
  final ContentStatus? statusFilter;
  final ContentType? typeFilter;
  final bool includeDeleted;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<ContentStatus?> onStatusFilterChanged;
  final ValueChanged<ContentType?> onTypeFilterChanged;
  final ValueChanged<bool> onToggleIncludeDeleted;
  final VoidCallback onCreate;
  final ValueChanged<AdminContentItem> onEdit;
  final ValueChanged<AdminContentItem> onDelete;
  final ValueChanged<AdminContentItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(context),
        if (tagError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AdminInlineError(message: tagError!),
          ),
        Expanded(
          child: page.items.isEmpty
              ? const AdminEmptyPane(message: '暂无内容')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm + 4),
                  itemBuilder: (context, index) {
                    final content = page.items[index];
                    return _ContentAdminRow(
                      content: content,
                      onEdit: content.deleted
                          ? null
                          : () => onEdit(content),
                      onDelete: content.deleted
                          ? null
                          : () => onDelete(content),
                      onRestore: content.deleted
                          ? () => onRestore(content)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：标题 + 新增按钮
          SectionToolbar(
            title: '内容管理',
            actionLabel: '新增内容',
            actionIcon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
            onAction: onCreate,
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          // 第二行：搜索框
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: '搜索标题或摘要...',
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 20,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 18,
                      ),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                        onSearchSubmitted('');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: onSearchSubmitted,
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          // 第三行：筛选器
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 状态筛选
              _FilterDropdown<ContentStatus>(
                label: '状态',
                value: statusFilter,
                items: ContentStatus.values,
                labelBuilder: (v) => v.label,
                onChanged: onStatusFilterChanged,
              ),
              // 类型筛选
              _FilterDropdown<ContentType>(
                label: '类型',
                value: typeFilter,
                items: ContentType.values,
                labelBuilder: (v) => v.label,
                onChanged: onTypeFilterChanged,
              ),
              // 显示已删除
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '显示已删除',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Switch(
                    value: includeDeleted,
                    onChanged: onToggleIncludeDeleted,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 通用筛选下拉框
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isDense: true,
          value: value,
          hint: Text(label, style: Theme.of(context).textTheme.bodySmall),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text('全部$label',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            ...items.map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelBuilder(item),
                      style: Theme.of(context).textTheme.bodySmall),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
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
        // 始终显示状态标签
        AdminStatusChip(status: content.status),
        // 已删除时额外显示删除标记
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
