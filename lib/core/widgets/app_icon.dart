/// The icon sizes used across RideSync. Every icon in the app comes from one
/// family (Material Symbols Rounded, via `Icons.*_rounded`) at one of these.
abstract final class AppIconSize {
  /// Inside a chip, a badge or a dense row.
  static const double small = 16;

  /// The default: beside a label or inside a button.
  static const double medium = 20;

  /// Standalone controls: round map buttons, back buttons.
  static const double large = 24;

  /// A state shown on its own, such as an empty list.
  static const double hero = 36;
}
