import 'package:flutter/material.dart';

/// The RideSync colour system.
///
/// One purple, solid colours only. Near-black surfaces, one brand colour for
/// every accent, white and grey text, and hairline borders. There are no
/// gradients anywhere in the app's chrome: depth comes from layering and from
/// very soft, very faint shadows.
///
/// Colour is also information on the map, so riders keep their own identity
/// colours (see `RiderPalette`) and routes are coloured by speed; neither is
/// used for the app's chrome.
@immutable
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// App background.
  static const Color background = Color(0xFF000000);

  /// Cards, sheets and panels.
  static const Color surface = Color(0xFF121212);

  /// A step above [surface], for things that sit inside a card.
  static const Color surfaceRaised = Color(0xFF1A1A1A);

  /// Borders and dividers.
  static const Color border = Color(0xFF262626);

  /// The dimmed backdrop behind dialogs and sheets.
  static const Color scrim = Color(0xB3000000);

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  /// The RideSync purple. The only purple in the app.
  static const Color primary = Color(0xFF8C3EE2);

  /// [primary] a touch lighter, for hover.
  static final Color primaryHover = Color.lerp(primary, Colors.white, 0.10)!;

  /// [primary] a touch darker, for a pressed state.
  static final Color primaryPressed = Color.lerp(primary, Colors.black, 0.16)!;

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A9A9A);

  /// Hints, placeholders and disabled text: quieter than [textSecondary].
  static const Color textTertiary = Color(0xFF5C5C5C);

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Success and "all good" states (a valid input, a live connection, a
  /// finished step) are the brand purple: RideSync has no green chrome.
  static const Color success = primary;
  static const Color error = Color(0xFFFF5252);

  // ---------------------------------------------------------------------------
  // Rider identity colours
  //
  // Used only for riders' dots, trails and avatars, so friends can tell each
  // other apart on the map. Order matters: `RiderPalette` assigns from here.
  // ---------------------------------------------------------------------------

  static const Color neonGreen = Color(0xFF00FF94);
  static const Color orange = Color(0xFFFF9F1C);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color pink = Color(0xFFFF5CA8);
  static const Color yellow = Color(0xFFFFE23D);

  const AppColors._();
}
