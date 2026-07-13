import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/theme/app_design_tokens.dart';
import 'package:personal_blog_web/src/theme/app_motion.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('light theme text and controls meet WCAG contrast targets', () {
    final theme = buildAppTheme();
    final scheme = theme.colorScheme;
    final textSurfaces = [
      scheme.surface,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      theme.scaffoldBackgroundColor,
    ];

    for (final surface in textSurfaces) {
      expect(
        _contrastRatio(scheme.onSurfaceVariant, surface),
        greaterThanOrEqualTo(4.5),
        reason: 'muted text must remain readable on ${surface.toARGB32()}',
      );
    }
    expect(
      _contrastRatio(scheme.onSecondary, scheme.secondary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(scheme.outline, scheme.surface),
      greaterThanOrEqualTo(3),
    );
  });

  test('brand accents remain readable in light and dark themes', () {
    final light = buildAppTheme();
    final lightTokens = light.extension<AppDesignTokens>()!;
    expect(
      _contrastRatio(Colors.white, lightTokens.rose),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(Colors.white, lightTokens.lavender),
      greaterThanOrEqualTo(4.5),
    );

    final dark = buildDarkAppTheme();
    final darkTokens = dark.extension<AppDesignTokens>()!;
    expect(
      _contrastRatio(darkTokens.rose, dark.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(darkTokens.lavender, dark.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('motion duration becomes zero when animations are disabled', (
    tester,
  ) async {
    Duration? resolvedDuration;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resolvedDuration = AppMotion.duration(
                context,
                const Duration(milliseconds: 240),
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(resolvedDuration, Duration.zero);
  });
}
