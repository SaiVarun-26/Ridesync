import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography for RideSync.
///
/// A single geometric sans (Space Grotesk) carries the brand's futuristic
/// feel. Numbers use tabular figures so stats on the Ride Card align cleanly.
///
/// Note on implementation: we intentionally do *not* call
/// `GoogleFonts.spaceGroteskTextTheme()`. Since Flutter 3.44 split Material
/// into the standalone `material_ui` package, that helper returns a
/// conflicting `TextTheme` type and fails to compile. Instead we apply the
/// font per style using the `GoogleFonts.spaceGrotesk` tear-off, which returns
/// a `TextStyle` — a type both Material copies share. This is the
/// forward-compatible approach until `google_fonts` finishes migrating.
@immutable
abstract final class AppTypography {
  /// Applies Space Grotesk to every style of [base], preserving each style's
  /// size, weight and other geometry, then tunes brand-specific overrides.
  static TextTheme textTheme(TextTheme base) {
    TextStyle? font(TextStyle? style) =>
        style == null ? null : GoogleFonts.spaceGrotesk(textStyle: style);

    final themed = base.copyWith(
      displayLarge: font(base.displayLarge),
      displayMedium: font(base.displayMedium),
      displaySmall: font(base.displaySmall),
      headlineLarge: font(base.headlineLarge),
      headlineMedium: font(base.headlineMedium),
      headlineSmall: font(base.headlineSmall),
      titleLarge: font(base.titleLarge),
      titleMedium: font(base.titleMedium),
      titleSmall: font(base.titleSmall),
      bodyLarge: font(base.bodyLarge),
      bodyMedium: font(base.bodyMedium),
      bodySmall: font(base.bodySmall),
      labelLarge: font(base.labelLarge),
      labelMedium: font(base.labelMedium),
      labelSmall: font(base.labelSmall),
    );

    return themed
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          displayLarge: themed.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            height: 1.05,
            color: AppColors.textPrimary,
          ),
          displayMedium: themed.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
          displaySmall: themed.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
          headlineMedium: themed.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleLarge: themed.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleMedium: themed.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          labelLarge: themed.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          bodyMedium: themed.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        );
  }

  /// Tabular-figure style for stats and counters where digit alignment matters.
  static TextStyle stat({
    double fontSize = 28,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  const AppTypography._();
}
