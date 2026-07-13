import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_design_tokens.dart';
import 'app_spacing.dart';

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.seed,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.seed,
        onPrimary: Colors.white,
        primaryContainer: AppColors.lightTag,
        onPrimaryContainer: const Color(0xFF1A3F36),
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFECE9F8),
        onSecondaryContainer: const Color(0xFF342D67),
        tertiary: AppColors.warmAccent,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFFFE7EC),
        onTertiaryContainer: const Color(0xFF67152D),
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightInk,
        onSurfaceVariant: AppColors.lightMutedInk,
        surfaceContainerLowest: AppColors.lightSurface,
        surfaceContainerLow: AppColors.lightSurface,
        surfaceContainer: AppColors.lightSurfaceMuted,
        surfaceContainerHigh: const Color(0xFFE7ECE7),
        surfaceContainerHighest: AppColors.lightSearch,
        outline: const Color(0xFF747D78),
        outlineVariant: AppColors.lightBorder,
        surfaceTint: AppColors.seed,
      );

  return _buildTheme(
    scheme: scheme,
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    designTokens: AppDesignTokens.light(),
  );
}

ThemeData buildDarkAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.darkPrimary,
        onPrimary: const Color(0xFF082019),
        primaryContainer: const Color(0xFF254A42),
        onPrimaryContainer: const Color(0xFFBCEBDD),
        secondary: const Color(0xFFB7AEEA),
        onSecondary: const Color(0xFF251D57),
        secondaryContainer: const Color(0xFF3A3563),
        onSecondaryContainer: const Color(0xFFE7E1FF),
        tertiary: const Color(0xFFEDA4B3),
        onTertiary: const Color(0xFF4F1024),
        tertiaryContainer: const Color(0xFF63283A),
        onTertiaryContainer: const Color(0xFFFFD9E0),
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkInk,
        onSurfaceVariant: AppColors.darkMutedInk,
        surfaceContainerLowest: AppColors.darkBackground,
        surfaceContainerLow: AppColors.darkSurface,
        surfaceContainer: AppColors.darkSurfaceMuted,
        surfaceContainerHigh: const Color(0xFF28312D),
        surfaceContainerHighest: const Color(0xFF303A35),
        outline: const Color(0xFF78837D),
        outlineVariant: AppColors.darkBorder,
        surfaceTint: AppColors.darkPrimary,
      );

  return _buildTheme(
    scheme: scheme,
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    designTokens: AppDesignTokens.dark(),
  );
}

ThemeData _buildTheme({
  required ColorScheme scheme,
  required Brightness brightness,
  required Color background,
  required AppDesignTokens designTokens,
}) {
  final textTheme = _buildTextTheme(brightness);
  final radius = BorderRadius.circular(AppRadii.control);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    extensions: [designTokens],
    fontFamilyFallback: const [
      'system-ui',
      '-apple-system',
      'BlinkMacSystemFont',
      'Segoe UI',
      'Helvetica Neue',
      'Arial',
      'sans-serif',
      'Apple Color Emoji',
      'Segoe UI Emoji',
    ],
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: designTokens.cardBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      hoverColor: scheme.surfaceContainerHigh,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 16,
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.primaryContainer,
      selectedColor: scheme.primary.withValues(alpha: 0.15),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      labelStyle: textTheme.labelMedium,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: scheme.surface.withValues(alpha: 0.96),
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: scheme.onInverseSurface),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}

TextTheme _buildTextTheme(Brightness brightness) {
  final Color textColor = brightness == Brightness.light
      ? AppColors.lightInk
      : AppColors.darkInk;
  const editorialFallback = [
    'Songti SC',
    'Noto Serif CJK SC',
    'Source Han Serif SC',
    'STSong',
    'serif',
  ];

  return TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      color: textColor,
      fontFamilyFallback: editorialFallback,
    ),
    displayMedium: TextStyle(
      fontSize: 44,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      color: textColor,
      fontFamilyFallback: editorialFallback,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      height: 1.18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: textColor,
      fontFamilyFallback: editorialFallback,
    ),
    headlineLarge: TextStyle(
      fontSize: 28,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamilyFallback: editorialFallback,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamilyFallback: editorialFallback,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamilyFallback: editorialFallback,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: textColor,
      fontFamilyFallback: editorialFallback,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    bodyLarge: TextStyle(
      fontSize: 17,
      height: 1.75,
      fontWeight: FontWeight.w400,
      color: textColor,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.65,
      fontWeight: FontWeight.w400,
      color: textColor,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: textColor.withValues(alpha: 0.8),
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: textColor.withValues(alpha: 0.8),
    ),
  );
}
