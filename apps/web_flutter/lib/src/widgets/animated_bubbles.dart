import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated floating bubbles that drift slowly across the background.
///
/// Uses [CustomPainter] with radial gradients for soft, blurred circles.
/// Accepts custom colors or derives them from the current [ColorScheme].
class AnimatedBubbles extends StatefulWidget {
  const AnimatedBubbles({
    super.key,
    this.colors,
    this.bubbleCount = 5,
    this.maxRadius = 200,
    this.speed = 0.02,
  });

  /// Colors for the bubbles. If null, uses [ColorScheme] container colors.
  final List<Color>? colors;

  /// Number of bubbles to render.
  final int bubbleCount;

  /// Maximum radius of bubbles in logical pixels.
  final double maxRadius;

  /// Speed of bubble movement in normalized units per second.
  /// Lower values = slower movement. 0.02 means ~50s to cross the screen.
  final double speed;

  @override
  State<AnimatedBubbles> createState() => _AnimatedBubblesState();
}

class _AnimatedBubblesState extends State<AnimatedBubbles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Bubble> _bubbles;
  final _random = math.Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 100),
    )..repeat();
    _bubbles = _generateBubbles();
  }

  List<_Bubble> _generateBubbles() {
    return List.generate(widget.bubbleCount, (_) {
      return _Bubble(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: widget.maxRadius * (0.5 + _random.nextDouble() * 0.5),
        vx: (_random.nextDouble() - 0.5) * 2 * widget.speed,
        vy: (_random.nextDouble() - 0.5) * 2 * widget.speed,
        colorIndex: _random.nextInt(widget.colors?.length ?? 3),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _defaultColors(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      scheme.primaryContainer.withValues(alpha: 0.4),
      scheme.secondaryContainer.withValues(alpha: 0.4),
      scheme.tertiaryContainer.withValues(alpha: 0.3),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? _defaultColors(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _BubblesPainter(
            bubbles: _bubbles,
            progress: _controller.value,
            colors: colors,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Bubble {
  const _Bubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.vx,
    required this.vy,
    required this.colorIndex,
  });

  final double x, y, radius, vx, vy;
  final int colorIndex;
}

class _BubblesPainter extends CustomPainter {
  _BubblesPainter({
    required this.bubbles,
    required this.progress,
    required this.colors,
  });

  final List<_Bubble> bubbles;
  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 100; // matches 100s controller duration

    for (final bubble in bubbles) {
      final x = _wrap(bubble.x + bubble.vx * time) * size.width;
      final y = _wrap(bubble.y + bubble.vy * time) * size.height;
      final color = colors[bubble.colorIndex % colors.length];

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset(x, y), radius: bubble.radius),
        );

      canvas.drawCircle(Offset(x, y), bubble.radius, paint);
    }
  }

  double _wrap(double value) => (value % 1.0 + 1.0) % 1.0;

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
