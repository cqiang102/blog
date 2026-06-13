// 管理后台 - 标签管理标签页
// 展示标签列表，支持新增、编辑和删除
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../state/state.dart';
import '../../../core/models.dart';
import '../admin_widgets.dart';
import '../tag_editor_dialog.dart';

/// 标签管理标签页
/// 支持标签的新增、编辑、删除操作
class AdminTagTab extends ConsumerWidget {
  const AdminTagTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(adminTagsProvider);

    return tags.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => AdminErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminTagsProvider),
          ),
      data:
          (items) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionToolbar(
                title: '标签管理',
                actionLabel: '新增标签',
                actionIcon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
                onAction: () => _openTagEditor(context, ref),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const AdminEmptyPane(message: '暂无标签')
              else
                for (final tag in items) ...[
                  Card(
                    child: ListTile(
                      leading: const HugeIcon(icon: HugeIcons.strokeRoundedTag01),
                      title: Text(tag.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tag.description.isEmpty
                                ? tag.slug
                                : '${tag.slug} · ${tag.description}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (tag.updatedAt case final updatedAt?) ...[
                            const SizedBox(height: 4),
                            Text(
                              '更新于 ${formatAdminDate(updatedAt)}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: '编辑',
                            onPressed:
                                () => _openTagEditor(context, ref, tag: tag),
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit01),
                          ),
                          IconButton(
                            tooltip: '删除',
                            onPressed: () => _deleteTag(context, ref, tag),
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  /// 打开标签编辑器对话框
  /// 新增时 tag 为 null，编辑时传入现有标签数据
  Future<void> _openTagEditor(
    BuildContext context,
    WidgetRef ref, {
    TagItem? tag,
  }) async {
    final draft = await showDialog<TagDraft>(
      context: context,
      builder: (context) => TagEditorDialog(tag: tag),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (tag == null) {
        await api.createAdminTag(accessToken: token, draft: draft);
      } else {
        await api.updateAdminTag(accessToken: token, id: tag.id, draft: draft);
      }
      ref.invalidate(adminTagsProvider);
      ref.invalidate(adminContentsProvider(const AdminContentQuery()));
      if (!context.mounted) return;
      showAdminSnack(context, tag == null ? '标签已创建' : '标签已保存');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  /// 删除标签
  /// 弹出确认对话框后调用 API 删除标签
  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    TagItem tag,
  ) async {
    if (!context.mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除标签',
      message: '确认删除「${tag.name}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminTag(accessToken: token, id: tag.id);
      ref.invalidate(adminTagsProvider);
      ref.invalidate(adminContentsProvider(const AdminContentQuery()));
      if (!context.mounted) return;
      showAdminSnack(context, '标签已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }
}
