import 'package:flutter/material.dart';

/// Central color palette for RideSync.
///
/// The identity is "neon trails on a black map". Backgrounds are near-black,
/// surfaces are dark grey, and a curated set of neon accents is used for
/// riders and the planned route. Colors are never reused across riders, and
/// red is reserved exclusively for warnings.
@immutable
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Structural tones
  // ---------------------------------------------------------------------------

  /// App background. Near-black, never pure #000 everywhere so depth reads.
  static const Color background = Color(0xFF050505);

  /// Elevated surfaces: cards, sheets, dialogs.
  static const Color surface = Color(0xFF101010);

  /// Slightly raised surface for layering above [surface].
  static const Color surfaceElevated = Color(0xFF161616);

  /// Hairline dividers and borders.
  static const Color divider = Color(0xFF1B1B1B);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8A8A);
  static const Color textTertiary = Color(0xFF5A5A5A);

  // ---------------------------------------------------------------------------
  // Warning (the only sanctioned use of red)
  // ---------------------------------------------------------------------------

  static const Color warning = Color(0xFFFF4D4D);

  // ---------------------------------------------------------------------------
  // Signature accents
  // ---------------------------------------------------------------------------

  /// The planned destination route. Deliberately distinct from every rider
  /// accent so the route never blends into a trail.
  static const Color route = Color(0xFF2E6BFF); // Electric Blue

  // Rider accent palette. Order matters: [RiderPalette] assigns from this list.
  static const Color neonGreen = Color(0xFF00FF94);
  static const Color orange = Color(0xFFFF9F1C);
  static const Color purple = Color(0xFF9B5CFF);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color pink = Color(0xFFFF5CA8);
  static const Color yellow = Color(0xFFFFE23D);

  const AppColors._();
}
