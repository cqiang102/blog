import 'package:flutter/material.dart';

/// Blog-specific visual tokens layered on top of Material's [ColorScheme].
@immutable
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  const AppDesignTokens({
    required this.mint,
    required this.rose,
    required this.lavender,
    required this.grid,
    required this.cardBorder,
    required this.cardShadow,
    required this.cardHoverShadow,
  });

  factory AppDesignTokens.light() => const AppDesignTokens(
    mint: Color(0xFFE5F4EF),
    rose: Color(0xFFB84D68),
    lavender: Color(0xFF7067A8),
    grid: Color(0x0D20312C),
    cardBorder: Color(0xFFE5E4DE),
    cardShadow: BoxShadow(
      color: Color(0x0F1B332C),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    cardHoverShadow: BoxShadow(
      color: Color(0x1C1B332C),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  );

  factory AppDesignTokens.dark() => const AppDesignTokens(
    mint: Color(0xFF203C35),
    rose: Color(0xFFEDA4B3),
    lavender: Color(0xFFB7AEEA),
    grid: Color(0x14EDF4F1),
    cardBorder: Color(0xFF34403B),
    cardShadow: BoxShadow(
      color: Color(0x52000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    cardHoverShadow: BoxShadow(
      color: Color(0x70000000),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  );

  final Color mint;
  final Color rose;
  final Color lavender;
  final Color grid;
  final Color cardBorder;
  final BoxShadow cardShadow;
  final BoxShadow cardHoverShadow;

  static AppDesignTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppDesignTokens>() ??
        (theme.brightness == Brightness.dark
            ? AppDesignTokens.dark()
            : AppDesignTokens.light());
  }

  @override
  AppDesignTokens copyWith({
    Color? mint,
    Color? rose,
    Color? lavender,
    Color? grid,
    Color? cardBorder,
    BoxShadow? cardShadow,
    BoxShadow? cardHoverShadow,
  }) {
    return AppDesignTokens(
      mint: mint ?? this.mint,
      rose: rose ?? this.rose,
      lavender: lavender ?? this.lavender,
      grid: grid ?? this.grid,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      cardHoverShadow: cardHoverShadow ?? this.cardHoverShadow,
    );
  }

  @override
  AppDesignTokens lerp(covariant AppDesignTokens? other, double t) {
    if (other == null) return this;
    return AppDesignTokens(
      mint: Color.lerp(mint, other.mint, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardShadow: BoxShadow.lerp(cardShadow, other.cardShadow, t)!,
      cardHoverShadow: BoxShadow.lerp(
        cardHoverShadow,
        other.cardHoverShadow,
        t,
      )!,
    );
  }
}

abstract final class AppRadii {
  static const double control = 12;
  static const double card = 18;
  static const double contentCard = 20;
  static const double contentMedia = 8;
  static const double hero = 24;
  static const double pill = 999;
}

abstract final class AppLayout {
  static const double readingWidth = 760;
  static const double archiveWidth = 860;
  static const double archiveAsideWidth = 248;
}
