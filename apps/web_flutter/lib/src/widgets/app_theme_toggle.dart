import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_controller.dart';

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
