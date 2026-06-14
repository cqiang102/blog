import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/media_url.dart';
import '../../../../core/models.dart';
import '../../../../theme/app_spacing.dart';
import '../content_editor_state.dart';
import 'tag_selector.dart';

class PublishSettingsPanel extends StatelessWidget {
  const PublishSettingsPanel({
    super.key,
    required this.state,
    required this.slugController,
    required this.tags,
    required this.onSlugChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onPinnedChanged,
    required this.onPublishedAtPressed,
    required this.onPublishedAtCleared,
    required this.onTagToggled,
    required this.onCoverPressed,
  });

  final ContentEditorState state;
  final TextEditingController slugController;
  final List<TagItem> tags;
  final ValueChanged<String> onSlugChanged;
  final ValueChanged<ContentType> onTypeChanged;
  final ValueChanged<ContentStatus> onStatusChanged;
  final ValueChanged<bool> onPinnedChanged;
  final VoidCallback onPublishedAtPressed;
  final VoidCallback onPublishedAtCleared;
  final ValueChanged<String> onTagToggled;
  final VoidCallback onCoverPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSection(
          title: '发布设置',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<ContentStatus>(
                key: ValueKey(state.status),
                initialValue: state.status,
                decoration: const InputDecoration(labelText: '状态'),
                items: ContentStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onStatusChanged(value);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<ContentType>(
                key: ValueKey(state.type),
                initialValue: state.type,
                decoration: const InputDecoration(labelText: '内容类型'),
                items: ContentType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onTypeChanged(value);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('置顶展示'),
                subtitle: const Text('在首页置顶区域优先展示'),
                value: state.pinned,
                onChanged: onPinnedChanged,
              ),
              if (state.status == ContentStatus.published) ...[
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: onPublishedAtPressed,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar01,
                    size: 18,
                  ),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      state.publishedAt == null
                          ? '发布时使用当前时间'
                          : _formatDateTime(state.publishedAt!.toLocal()),
                    ),
                  ),
                ),
                if (state.publishedAt != null)
                  TextButton(
                    onPressed: onPublishedAtCleared,
                    child: const Text('恢复自动发布时间'),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SettingsSection(
          title: '链接与标签',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: slugController,
                decoration: const InputDecoration(
                  labelText: 'Slug',
                  hintText: '留空时由服务端自动生成',
                ),
                maxLength: 220,
                onChanged: onSlugChanged,
              ),
              if (tags.isNotEmpty)
                TagSelector(
                  tags: tags,
                  selectedSlugs: state.tagSlugs.toSet(),
                  onToggle: onTagToggled,
                  showTitle: false,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SettingsSection(
          title: '封面',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: state.coverUrl == null
                      ? ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedImage01,
                              size: 36,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: resolveMediaUrl(state.coverUrl!),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedImageNotFound01,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: state.mediaUrls.isEmpty ? null : onCoverPressed,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  size: 18,
                ),
                label: Text(state.mediaUrls.isEmpty ? '上传媒体后可设置' : '选择封面'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
