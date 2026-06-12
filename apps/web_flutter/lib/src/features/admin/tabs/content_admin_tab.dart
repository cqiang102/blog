// 管理后台 - 内容管理标签页
// 展示内容列表，支持 CRUD 操作和编辑对话框
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../state/state.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';
import '../content_editor/content_editor.dart';

/// 内容管理标签页
/// 添加 AutomaticKeepAliveClientMixin 保持状态
class AdminContentTab extends ConsumerStatefulWidget {
  const AdminContentTab({super.key});

  @override
  ConsumerState<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends ConsumerState<AdminContentTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final contents = ref.watch(adminContentsProvider);
    final tagsValue = ref.watch(adminTagsProvider);
    final tags = tagsValue.maybeWhen(
      data: (items) => items,
      orElse: () => const <TagItem>[],
    );
    final tagError = tagsValue.maybeWhen(
      error: (error, stackTrace) => error.toString(),
      orElse: () => null,
    );

    return contents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminContentsProvider),
      ),
      data: (page) => _ContentList(
        page: page,
        tags: tags,
        tagError: tagError,
        onOpenEditor: (content) => _openContentEditor(context, ref, tags, content: content),
        onArchive: (content) => _archiveContent(context, ref, content),
      ),
    );
  }

  Future<void> _openContentEditor(
    BuildContext context,
    WidgetRef ref,
    List<TagItem> tags, {
    AdminContentItem? content,
  }) async {
    final result = await showDialog<ContentEditorSubmitResult>(
      context: context,
      builder: (context) => ContentEditorDialog(content: content, tags: tags),
    );
    if (result == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (content == null) {
        await api.createAdminContent(accessToken: token, draft: result.draft);
      } else {
        await api.updateAdminContent(
          accessToken: token,
          id: content.id,
          draft: result.draft,
        );
      }
      result.onSuccess();
      ref.invalidate(adminContentsProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);
      if (!context.mounted) return;
      showAdminSnack(context, content == null ? '内容已创建' : '内容已保存');
    } on ApiException catch (error) {
      result.onFailure();
      showAdminSnack(context, error.message);
    } catch (error) {
      result.onFailure();
      showAdminSnack(context, error.toString());
    }
  }

  Future<void> _archiveContent(
    BuildContext context,
    WidgetRef ref,
    AdminContentItem content,
  ) async {
    if (!context.mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '归档内容',
      message: '确认归档「${content.title}」？',
      action: '归档',
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
      showAdminSnack(context, '内容已归档');
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
    required this.tags,
    required this.tagError,
    required this.onOpenEditor,
    required this.onArchive,
  });

  final PageResult<AdminContentItem> page;
  final List<TagItem> tags;
  final String? tagError;
  final ValueChanged<AdminContentItem?> onOpenEditor;
  final ValueChanged<AdminContentItem> onArchive;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        final content = page.items[index - 1];
        return _ContentAdminRow(
          content: content,
          onEdit: () => onOpenEditor(content),
          onArchive: content.archived ? null : () => onArchive(content),
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
          onAction: () => onOpenEditor(null),
        ),
        if (tagError != null) ...[
          const SizedBox(height: AppSpacing.sm + 4),
          AdminInlineError(message: tagError!),
        ],
        if (page.items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无内容'),
        ],
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    );
  }
}

/// 内容管理行组件
class _ContentAdminRow extends StatelessWidget {
  const _ContentAdminRow({
    required this.content,
    required this.onEdit,
    required this.onArchive,
  });

  final AdminContentItem content;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final publishedAt = formatAdminDate(content.publishedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：封面 + 标题 + 操作按钮
            _buildHeader(context),
            const SizedBox(height: AppSpacing.sm + 4),

            // 标签
            _buildTags(context),
            const SizedBox(height: 10),

            // 统计信息
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
            onTap: () => context.go('/contents/${content.id}'),
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
        IconButton(
          tooltip: '归档',
          onPressed: onArchive,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedArchive),
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
        Chip(label: Text(content.type.label)),
        if (content.pinned)
          const Chip(
            avatar: HugeIcon(icon: HugeIcons.strokeRoundedPin, size: 18),
            label: Text('置顶'),
          ),
        Chip(
          avatar: const HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 18),
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
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedFavourite, size: 18),
          text: '${content.likeCount}',
        ),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedView, size: 18),
          text: '${content.viewCount}',
        ),
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedMessage01, size: 18),
          text: '${content.commentCount}',
        ),
        AdminMetaText(icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18), text: publishedAt),
      ],
    );
  }
}
