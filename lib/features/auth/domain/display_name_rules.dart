/// What counts as a valid display name.
///
/// A display name is how a rider appears to their group, so it is required:
/// at least [minLength] characters once surrounding spaces are removed, at
/// most [maxLength], with at least one letter or digit and no control
/// characters.
abstract final class DisplayNameRules {
  static const int minLength = 2;
  static const int maxLength = 40;

  static final RegExp _hasLetterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

  /// The name as it will be saved: trimmed, with runs of spaces collapsed.
  static String clean(String input) =>
      input.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Why [input] is not a valid name, or `null` when it is valid.
  static String? validate(String input) {
    final name = clean(input);
    if (name.isEmpty) return 'Enter your name to continue.';
    if (_controlCharacters.hasMatch(name)) {
      return 'That name has characters we cannot use.';
    }
    if (name.length < minLength) {
      return 'Use at least $minLength characters.';
    }
    if (name.length > maxLength) {
      return 'Keep it to $maxLength characters or fewer.';
    }
    if (!_hasLetterOrDigit.hasMatch(name)) {
      return 'Include at least one letter or number.';
    }
    return null;
  }

  static bool isValid(String input) => validate(input) == null;
}
