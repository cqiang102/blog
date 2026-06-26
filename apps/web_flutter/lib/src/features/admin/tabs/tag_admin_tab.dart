// 管理后台 - 标签管理标签页
// 展示标签列表，支持新增、编辑和删除
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../core/models.dart';
import '../../../state/state.dart';
import '../../../theme/app_spacing.dart';
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
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminTagsProvider),
      ),
      data: (items) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= kTabletBreakpoint;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionToolbar(
                  title: '标签管理 · 共 ${items.length} 个',
                  actionLabel: '新增标签',
                  actionIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                  ),
                  onAction: () => _openTagEditor(context, ref),
                ),
                const SizedBox(height: AppSpacing.md),
                if (items.isEmpty)
                  const Expanded(child: AdminEmptyPane(message: '暂无标签'))
                else
                  Expanded(
                    child: isWide
                        ? _TagTable(
                            tags: items,
                            onEdit: (tag) =>
                                _openTagEditor(context, ref, tag: tag),
                            onDelete: (tag) => _deleteTag(context, ref, tag),
                          )
                        : _CompactTagList(
                            tags: items,
                            onEdit: (tag) =>
                                _openTagEditor(context, ref, tag: tag),
                            onDelete: (tag) => _deleteTag(context, ref, tag),
                          ),
                  ),
              ],
            ),
          );
        },
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
      ref.invalidate(adminContentsProvider);
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
      ref.invalidate(adminContentsProvider);
      if (!context.mounted) return;
      showAdminSnack(context, '标签已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }
}

class _TagTable extends StatelessWidget {
  const _TagTable({
    required this.tags,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TagItem> tags;
  final ValueChanged<TagItem> onEdit;
  final ValueChanged<TagItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _TagTableHeader(),
          Expanded(
            child: ListView.separated(
              itemCount: tags.length,
              itemBuilder: (context, index) => _TagTableRow(
                tag: tags[index],
                onEdit: onEdit,
                onDelete: onDelete,
              ),
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagTableHeader extends StatelessWidget {
  const _TagTableHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Container(
      height: 42,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('名称', style: style)),
          Expanded(flex: 2, child: Text('Slug', style: style)),
          Expanded(flex: 4, child: Text('描述', style: style)),
          SizedBox(width: 136, child: Text('更新时间', style: style)),
          SizedBox(
            width: 84,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('操作', style: style),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagTableRow extends StatelessWidget {
  const _TagTableRow({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  final TagItem tag;
  final ValueChanged<TagItem> onEdit;
  final ValueChanged<TagItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updatedAt = tag.updatedAt == null
        ? '-'
        : formatAdminDate(tag.updatedAt!);
    return InkWell(
      onTap: () => onEdit(tag),
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTag01,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        tag.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  tag.slug,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  tag.description.isEmpty ? '无描述' : tag.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 136,
                child: Text(
                  updatedAt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 84,
                child: _TagActions(
                  tag: tag,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTagList extends StatelessWidget {
  const _CompactTagList({
    required this.tags,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TagItem> tags;
  final ValueChanged<TagItem> onEdit;
  final ValueChanged<TagItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: tags.length,
        itemBuilder: (context, index) => _CompactTagRow(
          tag: tags[index],
          onEdit: onEdit,
          onDelete: onDelete,
        ),
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _CompactTagRow extends StatelessWidget {
  const _CompactTagRow({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  final TagItem tag;
  final ValueChanged<TagItem> onEdit;
  final ValueChanged<TagItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = tag.description.isEmpty
        ? tag.slug
        : '${tag.slug} · ${tag.description}';
    return InkWell(
      onTap: () => onEdit(tag),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedTag01,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _TagActions(tag: tag, onEdit: onEdit, onDelete: onDelete),
          ],
        ),
      ),
    );
  }
}

class _TagActions extends StatelessWidget {
  const _TagActions({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  final TagItem tag;
  final ValueChanged<TagItem> onEdit;
  final ValueChanged<TagItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '编辑',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          onPressed: () => onEdit(tag),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit01, size: 18),
        ),
        IconButton(
          tooltip: '删除',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          onPressed: () => onDelete(tag),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedDelete01,
            size: 18,
            color: scheme.error,
          ),
        ),
      ],
    );
  }
}
