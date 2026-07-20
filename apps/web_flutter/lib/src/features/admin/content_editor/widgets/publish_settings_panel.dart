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
    this.onCollapse,
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
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('content-editor-settings-panel'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsSection(
            title: '发布设置',
            trailing: onCollapse == null
                ? null
                : IconButton(
                    key: const ValueKey('content-editor-settings-collapse'),
                    tooltip: '收起发布设置',
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onCollapse,
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSidebarRight01,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompactSettingsSelect<ContentStatus>(
                  key: ValueKey(('content-editor-status-field', state.status)),
                  label: '状态',
                  value: state.status,
                  values: ContentStatus.values,
                  labelFor: (status) => status.label,
                  onChanged: onStatusChanged,
                ),
                const SizedBox(height: AppSpacing.sm),
                _CompactSettingsSelect<ContentType>(
                  key: ValueKey(('content-editor-type-field', state.type)),
                  label: '类型',
                  value: state.type,
                  values: ContentType.values,
                  labelFor: (type) => type.label,
                  onChanged: onTypeChanged,
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '置顶展示',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
          Divider(
            height: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
            color: scheme.outlineVariant,
          ),
          _SettingsSection(
            title: '链接与标签',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('content-editor-slug-field'),
                  controller: slugController,
                  decoration: _compactSettingsDecoration(
                    context,
                    hintText: 'Slug（留空自动生成）',
                  ),
                  maxLength: 220,
                  buildCounter: _hideSettingsLengthCounter,
                  onChanged: onSlugChanged,
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TagSelector(
                    tags: tags,
                    selectedSlugs: state.tagSlugs.toSet(),
                    onToggle: onTagToggled,
                    showTitle: false,
                  ),
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
            color: scheme.outlineVariant,
          ),
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
                            errorWidget: (_, _, _) => const Center(
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
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _CompactSettingsSelect<T> extends StatelessWidget {
  const _CompactSettingsSelect({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(10);
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.maxWidth < 160
            ? constraints.maxWidth
            : 160.0;
        return PopupMenuButton<T>(
          initialValue: value,
          tooltip: '$label：${labelFor(value)}',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          padding: EdgeInsets.zero,
          menuPadding: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints.tightFor(width: menuWidth),
          borderRadius: radius,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: scheme.outlineVariant),
          ),
          color: scheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          shadowColor: scheme.shadow.withValues(alpha: 0.12),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          onSelected: onChanged,
          itemBuilder: (context) => [
            for (final option in values)
              PopupMenuItem<T>(
                value: option,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  labelFor(option),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: option == value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
          child: SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: radius,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        labelFor(value),
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

InputDecoration _compactSettingsDecoration(
  BuildContext context, {
  String? hintText,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(10);
  final enabledBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return InputDecoration(
    hintText: hintText,
    counterText: '',
    isDense: true,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    constraints: const BoxConstraints(minHeight: 40),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    border: enabledBorder,
    enabledBorder: enabledBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
  );
}

Widget? _hideSettingsLengthCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
