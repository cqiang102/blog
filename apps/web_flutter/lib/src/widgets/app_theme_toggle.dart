import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_motion.dart';
import '../theme/theme_controller.dart';

class AppThemeToggle extends ConsumerWidget {
  const AppThemeToggle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;

    return IconButton(
      tooltip: dark ? '切换到亮色主题' : '切换到暗色主题',
      onPressed: () =>
          ref.read(themeControllerProvider.notifier).toggle(brightness),
      icon: AnimatedSwitcher(
        duration: AppMotion.duration(
          context,
          const Duration(milliseconds: 300),
        ),
        switchInCurve: const Cubic(0.2, 0, 0, 1),
        switchOutCurve: const Cubic(0.2, 0, 0, 1),
        transitionBuilder: (child, animation) {
          final scale = Tween<double>(begin: 0.25, end: 1).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: scale,
              child: AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (context, child) => ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: 4 * (1 - animation.value),
                    sigmaY: 4 * (1 - animation.value),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: HugeIcon(
          icon: dark
              ? HugeIcons.strokeRoundedSun01
              : HugeIcons.strokeRoundedMoon01,
          key: ValueKey(dark),
          color: color,
        ),
      ),
    );
  }
}
