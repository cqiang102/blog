// 管理后台 - 媒体管理标签页
// 展示媒体列表，支持上传、编辑和删除
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/models.dart';
import '../../../state/state.dart';
import '../../../theme/app_spacing.dart';
import '../admin_mutation.dart';
import '../admin_widgets.dart';
import '../media_editor_dialog.dart';
import '../upload_media_dialog.dart';

/// 媒体管理标签页
class AdminMediaTab extends ConsumerStatefulWidget {
  const AdminMediaTab({super.key});

  @override
  ConsumerState<AdminMediaTab> createState() => _AdminMediaTabState();
}

class _AdminMediaTabState extends ConsumerState<AdminMediaTab>
    with AdminPageCorrectionMixin<AdminMediaTab> {
  AdminPageQuery _query = const AdminPageQuery(size: 80);

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(adminMediaProvider(_query));

    return media.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: adminErrorMessage(error),
        onRetry: () => ref.invalidate(adminMediaProvider(_query)),
      ),
      data: (page) {
        correctAdminPage(
          page,
          requestedPage: _query.page,
          onChanged: _changePage,
        );
        return _MediaList(
          page: page,
          onPickAndUpload: () => _pickAndUpload(context, ref),
          onOpenEditor: (media) => _openMediaEditor(context, ref, media: media),
          onSetCover: (media) => _setCover(context, ref, media),
          onDelete: (media) => _deleteMedia(context, ref, media),
          onPageChanged: _changePage,
        );
      },
    );
  }

  void _changePage(int page) {
    if (page < 0 || page == _query.page) return;
    setState(() => _query = _query.copyWith(page: page));
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !context.mounted) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        showAdminSnack(context, '没有读取到文件内容');
        return;
      }

      if (!context.mounted) return;
      final draft = await showDialog<UploadMediaDraft>(
        context: context,
        builder: (context) => UploadMediaDialog(
          filename: file.name,
          inferredType: inferMediaType(file.name),
        ),
      );
      if (draft == null || !context.mounted) return;

      await runAdminMutation(
        context: context,
        ref: ref,
        mutationKey: 'media:upload',
        request: (api, token) async {
          await api.uploadAdminMedia(
            accessToken: token,
            bytes: bytes,
            filename: file.name,
            type: draft.type,
            contentId: draft.contentId,
          );
        },
        invalidate: () => _refreshMediaState(ref),
        successMessage: '文件已上传',
      );
    } catch (error) {
      if (context.mounted) {
        showAdminSnack(context, adminErrorMessage(error));
      }
    }
  }

  Future<void> _openMediaEditor(
    BuildContext context,
    WidgetRef ref, {
    AdminMediaItem? media,
  }) async {
    final draft = await showDialog<AdminMediaDraft>(
      context: context,
      builder: (context) => MediaEditorDialog(media: media),
    );
    if (draft == null || !context.mounted) return;

    await runAdminMutation(
      context: context,
      ref: ref,
      mutationKey: 'media:${media?.id ?? 'create'}',
      request: (api, token) async {
        if (media == null) {
          await api.createAdminMedia(accessToken: token, draft: draft);
        } else {
          await api.updateAdminMedia(
            accessToken: token,
            id: media.id,
            draft: draft,
          );
        }
      },
      invalidate: () => _refreshMediaState(ref),
      successMessage: media == null ? '媒体已创建' : '媒体已保存',
    );
  }

  Future<void> _setCover(
    BuildContext context,
    WidgetRef ref,
    AdminMediaItem media,
  ) async {
    if (media.contentId.isEmpty) return;

    await runAdminMutation(
      context: context,
      ref: ref,
      mutationKey: 'media:${media.id}',
      request: (api, token) async {
        await api.setAdminContentCover(
          accessToken: token,
          contentId: media.contentId,
          mediaId: media.id,
        );
      },
      invalidate: () => _refreshMediaState(ref),
      successMessage: '封面已设置',
    );
  }

  Future<void> _deleteMedia(
    BuildContext context,
    WidgetRef ref,
    AdminMediaItem media,
  ) async {
    if (!context.mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除媒体',
      message: '确认删除「${media.displayName}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    await runAdminMutation(
      context: context,
      ref: ref,
      mutationKey: 'media:${media.id}',
      request: (api, token) async {
        await api.deleteAdminMedia(accessToken: token, id: media.id);
      },
      invalidate: () => _refreshMediaState(ref),
      successMessage: '媒体已删除',
    );
  }

  void _refreshMediaState(WidgetRef ref) {
    ref.invalidate(adminMediaProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(recommendationsProvider);
  }
}

/// 媒体列表组件
class _MediaList extends StatelessWidget {
  const _MediaList({
    required this.page,
    required this.onPickAndUpload,
    required this.onOpenEditor,
    required this.onSetCover,
    required this.onDelete,
    required this.onPageChanged,
  });

  final PageResult<AdminMediaItem> page;
  final VoidCallback onPickAndUpload;
  final ValueChanged<AdminMediaItem?> onOpenEditor;
  final ValueChanged<AdminMediaItem> onSetCover;
  final ValueChanged<AdminMediaItem> onDelete;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.items.length + 1 + (page.total > page.size ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm + 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        if (index > page.items.length) {
          return AdminPaginationBar(
            page: page.page,
            pageSize: page.size,
            total: page.total,
            onChanged: onPageChanged,
          );
        }
        final item = page.items[index - 1];
        return _MediaAdminRow(
          media: item,
          onEdit: () => onOpenEditor(item),
          onSetCover: item.contentId.isEmpty || item.cover
              ? null
              : () => onSetCover(item),
          onDelete: () => onDelete(item),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionToolbar(
          title: '媒体管理',
          actionLabel: '上传文件',
          actionIcon: const HugeIcon(icon: HugeIcons.strokeRoundedUpload01),
          onAction: onPickAndUpload,
          secondaryLabel: '外链媒体',
          secondaryIcon: const HugeIcon(icon: HugeIcons.strokeRoundedLink01),
          onSecondaryAction: () => onOpenEditor(null),
        ),
        if (page.items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无媒体资源'),
        ],
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    );
  }
}

/// 媒体管理行组件
class _MediaAdminRow extends StatelessWidget {
  const _MediaAdminRow({
    required this.media,
    required this.onEdit,
    required this.onSetCover,
    required this.onDelete,
  });

  final AdminMediaItem media;
  final VoidCallback onEdit;
  final VoidCallback? onSetCover;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final createdAt = formatAdminDate(media.createdAt);
    final size = media.byteSize == 0 ? '' : formatAdminBytes(media.byteSize);
    final dimensions = media.width > 0 && media.height > 0
        ? '${media.width} x ${media.height}'
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：缩略图 + 信息
            _buildHeader(context, size, dimensions),
            const SizedBox(height: AppSpacing.sm + 4),

            // 操作按钮
            _buildActions(context, createdAt),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String size, String dimensions) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminMediaThumb(
          url: media.publicUrl,
          type: media.type,
          size: const Size(112, 72),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                media.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                media.publicUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  Chip(label: Text(media.type.label)),
                  if (media.cover)
                    const Chip(
                      avatar: HugeIcon(
                        icon: HugeIcons.strokeRoundedImage01,
                        size: 18,
                      ),
                      label: Text('封面'),
                    ),
                  if (media.contentTitle.isNotEmpty)
                    Chip(label: Text(media.contentTitle)),
                  if (media.contentType.isNotEmpty)
                    Chip(label: Text(media.contentType)),
                  if (size.isNotEmpty) Chip(label: Text(size)),
                  if (dimensions.isNotEmpty) Chip(label: Text(dimensions)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, String createdAt) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AdminMetaText(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18),
          text: createdAt,
        ),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit01, size: 18),
          label: const Text('编辑'),
        ),
        OutlinedButton.icon(
          onPressed: onSetCover,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 18),
          label: const Text('设封面'),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: 18),
          label: const Text('删除'),
        ),
      ],
    );
  }
}
