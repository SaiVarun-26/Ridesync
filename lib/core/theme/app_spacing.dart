import 'package:flutter/widgets.dart';

/// 4-point spacing scale. Use these tokens instead of raw numbers so spacing
/// stays consistent across the app.
@immutable
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  const AppSpacing._();
}

/// Corner radii. Cards use [card]; buttons are fully pill-shaped via [pill].
@immutable
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double card = 16;
  static const double lg = 24;
  static const double pill = 999;

  const AppRadius._();
}

/// Motion durations and curves. The product feel is calm and premium, so
/// curves are ease-out with no bounce.
@immutable
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve curve = Curves.easeOutCubic;

  const AppMotion._();
}
