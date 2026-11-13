import 'package:flutter/painting.dart';

/// The app's shadows. There are only three, and all are black, very large and
/// very faint: enough to lift a surface off the black page, never enough to
/// read as a glow.
abstract final class AppShadows {
  /// A card or floating panel at rest.
  static const List<BoxShadow> rest = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 40,
      offset: Offset(0, 12),
      spreadRadius: -10,
    ),
  ];

  /// The same surface while a finger is on it: it lifts a little further.
  static const List<BoxShadow> lifted = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 48,
      offset: Offset(0, 16),
      spreadRadius: -10,
    ),
  ];

  /// A sheet rising from the bottom edge: cast upwards.
  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 40,
      offset: Offset(0, -12),
      spreadRadius: -10,
    ),
  ];
}
