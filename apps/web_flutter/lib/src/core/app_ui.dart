import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'theme.dart';
import 'theme_controller.dart';

class AppThemeToggle extends ConsumerWidget {
  const AppThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;

    return IconButton(
      tooltip: dark ? '切换到亮色主题' : '切换到暗色主题',
      onPressed: () => ref.read(themeControllerProvider).toggle(brightness),
      icon: AnimatedSwitcher(
        duration: AppAnimations.fast,
        transitionBuilder:
            (child, animation) =>
                RotationTransition(turns: animation, child: child),
        child: HugeIcon(
          icon: dark ? HugeIcons.strokeRoundedSun01 : HugeIcons.strokeRoundedMoon01,
          key: ValueKey(dark),
        ),
      ),
    );
  }
}

class AppHorizontalTabs extends StatelessWidget {
  const AppHorizontalTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              _AppHorizontalTab(
                label: labels[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
              if (index < labels.length - 1)
                const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppHorizontalTab extends StatelessWidget {
  const _AppHorizontalTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color:
                  selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class AppPageFrame extends StatelessWidget {
  const AppPageFrame({super.key, required this.child, this.maxWidth = 1240});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppInteractiveCard extends StatefulWidget {
  const AppInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Clip clipBehavior;

  @override
  State<AppInteractiveCard> createState() => _AppInteractiveCardState();
}

class _AppInteractiveCardState extends State<AppInteractiveCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.borderRadius);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
          border: Border.all(
            color: _hovered ? scheme.primary : scheme.outlineVariant,
          ),
          boxShadow:
              _hovered
                  ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                  : const [],
        ),
        clipBehavior: widget.clipBehavior,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text('$actionLabel  →')),
      ],
    );
  }
}

// ============================================================================
// flutter_animate 统一动画扩展
// ============================================================================

extension AnimateX on Widget {
  /// 淡入 + 轻微上滑，用于列表项、卡片等的入场动画
  Widget fadeSlideIn({
    Duration? delay,
    Duration duration = const Duration(milliseconds: 400),
  }) =>
      animate(delay: delay)
          .fadeIn(duration: duration, curve: Curves.easeOutCubic)
          .slideY(
            begin: 0.08,
            end: 0,
            duration: duration,
            curve: Curves.easeOutCubic,
          );

  /// 淡入 + 轻微左滑，用于时间线卡片等从左侧入场
  Widget fadeSlideFromLeft({
    Duration? delay,
    Duration duration = const Duration(milliseconds: 400),
  }) =>
      animate(delay: delay)
          .fadeIn(duration: duration, curve: Curves.easeOutCubic)
          .slideX(
            begin: -0.08,
            end: 0,
            duration: duration,
            curve: Curves.easeOutCubic,
          );

  /// 轻微缩放弹跳，用于点赞等交互反馈
  Widget scalePulse({
    Duration duration = const Duration(milliseconds: 300),
  }) =>
      animate()
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: duration,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: duration);
}
