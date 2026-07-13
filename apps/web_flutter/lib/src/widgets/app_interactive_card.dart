import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import '../theme/app_spacing.dart';
import '../theme/app_motion.dart';

class AppInteractiveCard extends StatefulWidget {
  const AppInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = AppRadii.card,
    this.clipBehavior = Clip.antiAlias,
    this.enablePressScale = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Clip clipBehavior;
  final bool enablePressScale;

  @override
  State<AppInteractiveCard> createState() => _AppInteractiveCardState();
}

class _AppInteractiveCardState extends State<AppInteractiveCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.borderRadius);
    final reduceMotion = AppMotion.reduce(context);
    final emphasized = _hovered || _focused;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neutralRing = isDark ? Colors.white : Colors.black;
    final shadows = <BoxShadow>[
      if (_focused)
        BoxShadow(
          color: scheme.primary.withValues(alpha: 0.45),
          spreadRadius: 2,
        ),
      BoxShadow(
        color: neutralRing.withValues(
          alpha: isDark ? (emphasized ? 0.13 : 0.08) : 0.06,
        ),
        spreadRadius: 1,
      ),
      if (!isDark) ...[
        BoxShadow(
          color: Colors.black.withValues(alpha: emphasized ? 0.08 : 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: emphasized ? 0.06 : 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ];

    return Listener(
      onPointerDown: widget.onTap == null || !widget.enablePressScale
          ? null
          : (_) => setState(() => _pressed = true),
      onPointerUp: widget.onTap == null || !widget.enablePressScale
          ? null
          : (_) => setState(() => _pressed = false),
      onPointerCancel: widget.onTap == null || !widget.enablePressScale
          ? null
          : (_) => setState(() => _pressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _pressed && !reduceMotion ? 0.96 : 1,
          duration: AppMotion.duration(context, AppAnimations.fast),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppAnimations.fast),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              emphasized && !reduceMotion ? -2 : 0,
              0,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: radius,
              boxShadow: shadows,
            ),
            clipBehavior: widget.clipBehavior,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onFocusChange: (focused) => setState(() => _focused = focused),
                borderRadius: radius,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
