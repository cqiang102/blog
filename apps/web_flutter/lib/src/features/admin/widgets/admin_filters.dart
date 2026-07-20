import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../theme/app_design_tokens.dart';
import '../../../theme/app_spacing.dart';

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
