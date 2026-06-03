// 管理后台 - 媒体管理标签页
// 展示媒体列表，支持上传、编辑和删除
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_providers.dart';
import '../../../core/models.dart';
import '../admin_widgets.dart';
import '../media_editor_dialog.dart';
import '../upload_media_dialog.dart';

/// 媒体管理标签页
/// 支持媒体文件的上传、编辑、设为封面、删除操作
class AdminMediaTab extends ConsumerWidget {
  const AdminMediaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(adminMediaProvider);
    final contentsValue = ref.watch(adminContentsProvider);
    final contents = contentsValue.maybeWhen(
      data: (page) => page.items,
      orElse: () => const <AdminContentItem>[],
    );
    final contentError = contentsValue.maybeWhen(
      error: (error, stackTrace) => error.toString(),
      orElse: () => null,
    );

    return media.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => AdminErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminMediaProvider),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionToolbar(
                title: '媒体管理',
                actionLabel: '上传文件',
                actionIcon: Icons.upload_file,
                onAction: () => _pickAndUpload(context, ref, contents),
                secondaryLabel: '外链媒体',
                secondaryIcon: Icons.add_link,
                onSecondaryAction:
                    () => _openMediaEditor(context, ref, contents),
              ),
              if (contentError != null) ...[
                const SizedBox(height: 12),
                AdminInlineError(message: contentError),
              ],
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const AdminEmptyPane(message: '暂无媒体资源')
              else
                for (final item in page.items) ...[
                  _MediaAdminRow(
                    media: item,
                    onEdit:
                        () => _openMediaEditor(
                          context,
                          ref,
                          contents,
                          media: item,
                        ),
                    onSetCover:
                        item.contentId.isEmpty || item.cover
                            ? null
                            : () => _setCover(context, ref, item),
                    onDelete: () => _deleteMedia(context, ref, item),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  /// 选择文件并上传
  /// 打开文件选择器，选择文件后弹出上传对话框，提交到服务器
  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    List<AdminContentItem> contents,
  ) async {
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

      final draft = await showDialog<UploadMediaDraft>(
        context: context,
        builder:
            (context) => UploadMediaDialog(
              filename: file.name,
              inferredType: inferMediaType(file.name),
              contents: contents,
            ),
      );
      if (draft == null || !context.mounted) return;

      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) return;

      await ref
          .read(apiClientProvider)
          .uploadAdminMedia(
            accessToken: token,
            bytes: bytes,
            filename: file.name,
            type: draft.type,
            contentId: draft.contentId,
          );
      _refreshMediaState(ref);
      if (!context.mounted) return;
      showAdminSnack(context, '文件已上传');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  /// 打开媒体编辑器对话框
  /// 新增时 media 为 null，编辑时传入现有媒体数据
  Future<void> _openMediaEditor(
    BuildContext context,
    WidgetRef ref,
    List<AdminContentItem> contents, {
    AdminMediaItem? media,
  }) async {
    final draft = await showDialog<AdminMediaDraft>(
      context: context,
      builder:
          (context) => MediaEditorDialog(media: media, contents: contents),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (media == null) {
        await api.createAdminMedia(accessToken: token, draft: draft);
      } else {
        await api.updateAdminMedia(
          accessToken: token,
          id: media.id,
          draft: draft,
        );
      }
      _refreshMediaState(ref);
      if (!context.mounted) return;
      showAdminSnack(context, media == null ? '媒体已创建' : '媒体已保存');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  /// 设置内容封面
  /// 将指定媒体设为关联内容的封面图
  Future<void> _setCover(
    BuildContext context,
    WidgetRef ref,
    AdminMediaItem media,
  ) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null || media.contentId.isEmpty) return;

    try {
      await ref
          .read(apiClientProvider)
          .setAdminContentCover(
            accessToken: token,
            contentId: media.contentId,
            mediaId: media.id,
          );
      _refreshMediaState(ref);
      if (!context.mounted) return;
      showAdminSnack(context, '封面已设置');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  /// 删除媒体
  /// 弹出确认对话框后调用 API 删除媒体文件
  Future<void> _deleteMedia(
    BuildContext context,
    WidgetRef ref,
    AdminMediaItem media,
  ) async {
    final confirmed = await adminConfirm(
      context,
      title: '删除媒体',
      message: '确认删除「${media.displayName}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminMedia(accessToken: token, id: media.id);
      _refreshMediaState(ref);
      if (!context.mounted) return;
      showAdminSnack(context, '媒体已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  /// 刷新媒体相关状态
  /// 使媒体、内容、仪表盘和推荐 Provider 失效
  void _refreshMediaState(WidgetRef ref) {
    ref.invalidate(adminMediaProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(recommendationsProvider);
  }
}

/// 媒体管理行组件
/// 展示单条媒体的缩略图、名称、URL、类型和操作按钮
class _MediaAdminRow extends StatelessWidget {
  const _MediaAdminRow({
    required this.media,
    required this.onEdit,
    required this.onSetCover,
    required this.onDelete,
  });

  final AdminMediaItem media; // 媒体数据
  final VoidCallback onEdit; // 编辑回调
  final VoidCallback? onSetCover; // 设为封面回调
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final createdAt = formatAdminDate(media.createdAt);
    final size = media.byteSize == 0 ? '' : formatAdminBytes(media.byteSize);
    final dimensions =
        media.width > 0 && media.height > 0
            ? '${media.width} x ${media.height}'
            : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminMediaThumb(
                  url: media.publicUrl,
                  type: media.type,
                  size: const Size(112, 72),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        media.publicUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(media.type.label)),
                          if (media.cover)
                            const Chip(
                              avatar: Icon(Icons.image_outlined, size: 18),
                              label: Text('封面'),
                            ),
                          if (media.contentTitle.isNotEmpty)
                            Chip(label: Text(media.contentTitle)),
                          if (media.contentType.isNotEmpty)
                            Chip(label: Text(media.contentType)),
                          if (size.isNotEmpty) Chip(label: Text(size)),
                          if (dimensions.isNotEmpty)
                            Chip(label: Text(dimensions)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AdminMetaText(icon: Icons.schedule_outlined, text: createdAt),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed: onSetCover,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('设封面'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
