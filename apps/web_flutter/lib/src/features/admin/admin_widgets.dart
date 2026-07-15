// 管理后台共享组件
// 包含工具栏、状态标签、错误面板、确认对话框等通用组件
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/media_url.dart';
import '../../core/models.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_spacing.dart';

class AdminEditorDialog extends StatelessWidget {
  const AdminEditorDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.subtitle,
    this.maxWidth = 680,
    this.scrollable = true,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  final bool scrollable;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final body = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          )
        : Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
                  ),
                ],
              ),
            ),
            Divider(color: scheme.outlineVariant),
            Flexible(
              fit: scrollable ? FlexFit.loose : FlexFit.tight,
              child: body,
            ),
            Divider(color: scheme.outlineVariant),
            Container(
              width: double.infinity,
              color: scheme.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm + 4,
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminFormSection extends StatelessWidget {
  const AdminFormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

const double kAdminDenseControlHeight = 40;

ButtonStyle adminCompactButtonStyle({
  Color? foregroundColor,
  Color? backgroundColor,
  BorderSide? side,
}) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(0, kAdminDenseControlHeight),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    foregroundColor: foregroundColor == null
        ? null
        : WidgetStatePropertyAll(foregroundColor),
    backgroundColor: backgroundColor == null
        ? null
        : WidgetStatePropertyAll(backgroundColor),
    side: side == null ? null : WidgetStatePropertyAll(side),
  );
}

/// 筛选带中的一个字段。未指定 [width] 时会在桌面端按 [flex] 分配空间。
class AdminFilterItem {
  const AdminFilterItem({required this.child, this.width, this.flex = 1})
    : assert(width != null || flex > 0);

  final Widget child;
  final double? width;
  final int flex;
}

/// 桌面后台的紧凑筛选工具带。
///
/// 宽屏时字段按比例占满一行，窄屏时字段堆叠，避免固定宽度留下大片空白。
class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    super.key,
    required this.items,
    this.actions = const [],
    this.onReset,
    this.resetEnabled = true,
    this.resetLabel = '重置',
  });

  final List<AdminFilterItem> items;
  final List<Widget> actions;
  final VoidCallback? onReset;
  final bool resetEnabled;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveActions = <Widget>[
      ...actions,
      if (onReset != null && resetEnabled)
        TextButton.icon(
          onPressed: onReset,
          style: adminCompactButtonStyle(
            foregroundColor: scheme.onSurfaceVariant,
          ),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedFilterRemove,
            size: 18,
          ),
          label: Text(resetLabel),
        ),
    ];

    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: FocusTraversalGroup(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      SizedBox(
                        height: kAdminDenseControlHeight,
                        child: items[index].child,
                      ),
                      if (index != items.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                    if (effectiveActions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: effectiveActions,
                        ),
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    if (items[index].width case final width?)
                      SizedBox(
                        width: width,
                        height: kAdminDenseControlHeight,
                        child: items[index].child,
                      )
                    else
                      Expanded(
                        flex: items[index].flex,
                        child: SizedBox(
                          height: kAdminDenseControlHeight,
                          child: items[index].child,
                        ),
                      ),
                    if (index != items.length - 1 ||
                        effectiveActions.isNotEmpty)
                      const SizedBox(width: AppSpacing.sm),
                  ],
                  if (effectiveActions.isNotEmpty)
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: effectiveActions,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 与筛选工具带配套的紧凑输入样式，避免浮动标签打断横向对齐。
InputDecoration adminFilterInputDecoration(
  BuildContext context, {
  required String hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(AppRadii.control);
  final enabledBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: scheme.outlineVariant),
  );

  return InputDecoration(
    hintText: hintText,
    hintStyle: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    prefixIconConstraints: const BoxConstraints.tightFor(width: 38, height: 38),
    suffixIconConstraints: const BoxConstraints.tightFor(width: 38, height: 38),
    isDense: true,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    border: enabledBorder,
    enabledBorder: enabledBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 4,
      vertical: 10,
    ),
  );
}

class AdminFilterApplyButton extends StatelessWidget {
  const AdminFilterApplyButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: adminCompactButtonStyle(),
      icon: const HugeIcon(icon: HugeIcons.strokeRoundedFilter, size: 18),
      label: const Text('筛选'),
    );
  }
}

class AdminFilterClearButton extends StatelessWidget {
  const AdminFilterClearButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: adminCompactButtonStyle(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18),
      label: const Text('清空'),
    );
  }
}

/// 筛选工具带中的二态选项，视觉权重低于页面主操作。
class AdminFilterToggle extends StatelessWidget {
  const AdminFilterToggle({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final bool selected;
  final ValueChanged<bool> onChanged;
  final Widget icon;
  final Widget selectedIcon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      toggled: selected,
      child: OutlinedButton.icon(
        onPressed: () => onChanged(!selected),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, kAdminDenseControlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: selected
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
          backgroundColor: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLowest,
          side: BorderSide(
            color: selected
                ? scheme.primary.withValues(alpha: 0.35)
                : scheme.outlineVariant,
          ),
        ),
        icon: selected ? selectedIcon : icon,
        label: Text(label),
      ),
    );
  }
}

/// 管理后台壳层的紧凑上下文栏，避免与各模块页面标题形成双主标题。
class AdminShellHeader extends StatelessWidget {
  const AdminShellHeader({
    super.key,
    required this.title,
    required this.module,
    this.trailing,
  });

  final String title;
  final String module;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.36),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        module,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 模块名称由后台壳层统一承载；列表内部仅在需要时保留主操作。
class AdminListActions extends StatelessWidget {
  const AdminListActions({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: actions,
      ),
    );
  }
}

/// 卡片底部的元信息与操作区：宽屏两端对齐，窄屏时操作靠右换行。
class AdminRowFooter extends StatelessWidget {
  const AdminRowFooter({
    super.key,
    required this.metadata,
    this.actions = const [],
    this.stackBreakpoint = 680,
  });

  final List<Widget> metadata;
  final List<Widget> actions;
  final double stackBreakpoint;

  @override
  Widget build(BuildContext context) {
    final metadataGroup = Wrap(
      spacing: AppSpacing.sm + 4,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: metadata,
    );
    if (actions.isEmpty) return metadataGroup;

    final actionGroup = Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metadataGroup,
              const SizedBox(height: AppSpacing.sm + 4),
              Align(alignment: Alignment.centerRight, child: actionGroup),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: metadataGroup),
            const SizedBox(width: AppSpacing.md),
            actionGroup,
          ],
        );
      },
    );
  }
}

/// 区域工具栏组件
/// 显示标题和操作按钮，支持主按钮和副按钮
class SectionToolbar extends StatelessWidget {
  const SectionToolbar({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryAction,
  });

  final String title; // 区域标题
  final String actionLabel; // 主按钮文本
  final Widget actionIcon; // 主按钮图标
  final VoidCallback onAction; // 主按钮点击回调
  final String? secondaryLabel; // 副按钮文本
  final Widget? secondaryIcon; // 副按钮图标
  final VoidCallback? onSecondaryAction; // 副按钮点击回调

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (secondaryLabel != null)
              OutlinedButton.icon(
                onPressed: onSecondaryAction,
                style: adminCompactButtonStyle(),
                icon: secondaryIcon ?? const Icon(Icons.add),
                label: Text(secondaryLabel!),
              ),
            FilledButton.icon(
              onPressed: onAction,
              style: adminCompactButtonStyle(),
              icon: actionIcon,
              label: Text(actionLabel),
            ),
          ],
        ),
      ],
    );
  }
}

/// 数字输入框组件
/// 带数字验证的文本输入框
class AdminNumberField extends StatelessWidget {
  const AdminNumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller; // 输入框控制器
  final String label; // 标签文本

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kAdminNumberFieldWidth,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return null;
          return int.tryParse(text) == null ? '请输入数字' : null;
        },
      ),
    );
  }
}

/// 内容状态标签组件
/// 根据状态显示不同颜色的标签
class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});

  final ContentStatus status; // 内容状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ContentStatus.published => scheme.primaryContainer,
      ContentStatus.archived => scheme.errorContainer,
      ContentStatus.draft => scheme.secondaryContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 评论状态标签组件
/// 根据评论状态显示不同颜色的标签
class AdminCommentStatusChip extends StatelessWidget {
  const AdminCommentStatusChip({super.key, required this.status});

  final AdminCommentStatus status; // 评论状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      AdminCommentStatus.visible => scheme.primaryContainer,
      AdminCommentStatus.deleted => scheme.errorContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 用户角色标签组件
/// 根据用户角色显示不同颜色的标签
class AdminUserRoleChip extends StatelessWidget {
  const AdminUserRoleChip({super.key, required this.role});

  final AdminUserRole role; // 用户角色

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      AdminUserRole.admin => scheme.tertiaryContainer,
      AdminUserRole.user => scheme.secondaryContainer,
    };
    return Chip(label: Text(role.label), backgroundColor: color);
  }
}

/// 用户状态标签组件
/// 根据用户状态显示不同颜色的标签
class AdminUserStatusChip extends StatelessWidget {
  const AdminUserStatusChip({super.key, required this.status});

  final AdminUserStatus status; // 用户状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      AdminUserStatus.active => scheme.primaryContainer,
      AdminUserStatus.disabled => scheme.errorContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 元数据文本组件
/// 显示图标 + 文本的元数据信息
class AdminMetaText extends StatelessWidget {
  const AdminMetaText({super.key, required this.icon, required this.text});

  final Widget icon; // 图标
  final String text; // 文本

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = Tooltip(
          message: text,
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            if (constraints.hasBoundedWidth) Flexible(child: label) else label,
          ],
        );
      },
    );
  }
}

/// 媒体缩略图组件
/// 根据媒体类型显示缩略图或占位图标
class AdminMediaThumb extends StatelessWidget {
  const AdminMediaThumb({
    super.key,
    required this.url,
    required this.type,
    required this.size,
  });

  final String url; // 媒体 URL
  final MediaAssetType type; // 媒体类型
  final Size size; // 缩略图尺寸

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = switch (type) {
      MediaAssetType.video => HugeIcons.strokeRoundedPlayCircle,
      MediaAssetType.file => HugeIcons.strokeRoundedFile01,
      MediaAssetType.image => HugeIcons.strokeRoundedImage01,
    };
    final placeholder = SizedBox(
      width: size.width,
      height: size.height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: HugeIcon(icon: fallbackIcon),
      ),
    );

    if (url.isEmpty || type != MediaAssetType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder,
      );
    }

    final resolvedUrl = resolveMediaUrl(url);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: kIsWeb
          ? Image.network(
              resolvedUrl,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => placeholder,
            )
          : CachedNetworkImage(
              imageUrl: resolvedUrl,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
              memCacheWidth: size.width.toInt() * 2,
              errorWidget: (context, url, error) => placeholder,
            ),
    );
  }
}

/// 内联错误组件
/// 在列表中显示错误信息的卡片
class AdminInlineError extends StatelessWidget {
  const AdminInlineError({super.key, required this.message});

  final String message; // 错误信息

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert01,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

/// 错误面板组件
/// 居中显示错误信息和重试按钮
class AdminErrorPane extends StatelessWidget {
  const AdminErrorPane({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message; // 错误信息
  final VoidCallback onRetry; // 重试回调

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空面板组件
/// 数据为空时显示的提示信息
class AdminEmptyPane extends StatelessWidget {
  const AdminEmptyPane({super.key, required this.message});

  final String message; // 提示信息

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(child: Text(message)),
    );
  }
}

/// 确认对话框
/// 通用的确认操作对话框，返回用户是否确认
Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// 显示 SnackBar 提示
void showAdminSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// 格式化日期
/// 时间戳为 0 时返回"未发布"，否则返回 yyyy-MM-dd HH:mm 格式
String formatAdminDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return '未发布';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}

/// 格式化字节数
/// 自动转换为 B/KB/MB/GB 单位
String formatAdminBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

/// 解析可空整数
/// 空字符串返回 null，非空时尝试解析为 int
int? parseNullableInt(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

/// 根据文件名推断媒体类型
/// 视频：mp4/webm/mov；图片：jpg/jpeg/png/gif/webp；其他：file
MediaAssetType inferMediaType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mov')) {
    return MediaAssetType.video;
  }
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp')) {
    return MediaAssetType.image;
  }
  return MediaAssetType.file;
}
