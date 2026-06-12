import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
