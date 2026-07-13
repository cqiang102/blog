import 'package:flutter/widgets.dart';

/// Central motion policy. It follows both platform and MediaQuery accessibility
/// preferences so decorative movement can disappear without disabling feedback.
abstract final class AppMotion {
  static bool get reduceGlobally => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  static bool reduce(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return reduceGlobally ||
        mediaQuery?.disableAnimations == true ||
        mediaQuery?.accessibleNavigation == true;
  }

  static Duration duration(BuildContext context, Duration preferred) =>
      reduce(context) ? Duration.zero : preferred;

  static Widget optional(
    BuildContext context, {
    required Widget child,
    required Widget Function(Widget child) animatedBuilder,
  }) => reduce(context) ? child : animatedBuilder(child);
}
