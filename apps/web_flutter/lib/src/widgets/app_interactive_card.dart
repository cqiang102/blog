import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(widget.borderRadius);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerLow : Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: _hovered ? scheme.primary : scheme.outlineVariant,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
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
