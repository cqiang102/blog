import 'package:flutter/widgets.dart';

/// A fixed-width inspector that releases its layout width while collapsing
/// toward the trailing edge of the viewport.
class CollapsibleInspector extends StatelessWidget {
  const CollapsibleInspector({
    super.key,
    required this.expanded,
    required this.width,
    required this.duration,
    required this.child,
  });

  final bool expanded;
  final double width;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: Curves.easeOutCubic,
      tween: Tween(end: expanded ? 1 : 0),
      child: IgnorePointer(
        ignoring: !expanded,
        child: ExcludeSemantics(
          excluding: !expanded,
          child: SizedBox(width: width, child: child),
        ),
      ),
      builder: (context, progress, child) => SizedBox(
        key: const ValueKey('content-editor-settings-viewport'),
        width: width * progress,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            child: child,
          ),
        ),
      ),
    );
  }
}
