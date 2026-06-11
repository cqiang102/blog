import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppAnimations {
  AppAnimations._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 500);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve playfulCurve = Curves.elasticOut;
  static const Curve slideCurve = Curves.easeOutCubic;
}

class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF27665A);
  static const Color accent = Color(0xFFB77924);

  static const Color lightBackground = Color(0xFFF5F3ED);
  static const Color lightSurface = Color(0xFFFCFBF8);
  static const Color lightSurfaceMuted = Color(0xFFEEEDE7);
  static const Color lightInk = Color(0xFF18201D);
  static const Color lightMutedInk = Color(0xFF65706B);
  static const Color lightBorder = Color(0xFFD9DDD8);

  static const Color darkPrimary = Color(0xFF78B7A7);
  static const Color darkBackground = Color(0xFF111614);
  static const Color darkSurface = Color(0xFF181E1B);
  static const Color darkSurfaceMuted = Color(0xFF202824);
  static const Color darkInk = Color(0xFFEDF2EF);
  static const Color darkMutedInk = Color(0xFFAAB5B0);
  static const Color darkBorder = Color(0xFF34403B);

  static const Color overlayDark = Color(0xB0000000);
  static const Color onOverlay = Colors.white;
  static const Color onOverlayMuted = Color(0xC7FFFFFF);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.seed,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDCECE6),
    onPrimaryContainer: const Color(0xFF173C34),
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFF5E3C8),
    onSecondaryContainer: const Color(0xFF5A3509),
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightInk,
    onSurfaceVariant: AppColors.lightMutedInk,
    surfaceContainerLowest: AppColors.lightSurface,
    surfaceContainerLow: const Color(0xFFF9F8F4),
    surfaceContainer: AppColors.lightSurfaceMuted,
    surfaceContainerHigh: const Color(0xFFE8E8E1),
    surfaceContainerHighest: const Color(0xFFE2E4DE),
    outline: const Color(0xFFA9B0AB),
    outlineVariant: AppColors.lightBorder,
    surfaceTint: AppColors.seed,
  );

  return _buildTheme(
    scheme: scheme,
    brightness: Brightness.light,
    background: AppColors.lightBackground,
  );
}

ThemeData buildDarkAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.darkPrimary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.darkPrimary,
    onPrimary: const Color(0xFF082019),
    primaryContainer: const Color(0xFF254A42),
    onPrimaryContainer: const Color(0xFFBCEBDD),
    secondary: const Color(0xFFE5B86A),
    onSecondary: const Color(0xFF3E2807),
    secondaryContainer: const Color(0xFF594317),
    onSecondaryContainer: const Color(0xFFFFE0A3),
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
  );
}

ThemeData _buildTheme({
  required ColorScheme scheme,
  required Brightness brightness,
  required Color background,
}) {
  final textTheme = _buildTextTheme(brightness);
  final radius = BorderRadius.circular(12);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    fontFamilyFallback: const [
      'system-ui',
      '-apple-system',
      'BlinkMacSystemFont',
      'Segoe UI',
      'Helvetica Neue',
      'Arial',
      'Noto Sans',
      'Noto Sans SC',
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        scheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
  );
}

TextTheme _buildTextTheme(Brightness brightness) {
  final Color textColor =
      brightness == Brightness.light ? AppColors.lightInk : AppColors.darkInk;

  return TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      color: textColor,
    ),
    displayMedium: TextStyle(
      fontSize: 44,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      color: textColor,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      height: 1.18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: textColor,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
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
      fontSize: 16,
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
