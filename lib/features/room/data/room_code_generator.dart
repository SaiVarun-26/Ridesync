import 'dart:math';

/// Generates short, human-friendly room codes.
///
/// Codes are 6 characters drawn from an unambiguous alphabet — digits and
/// letters that are easy to read aloud and type, with visually confusable
/// characters (O/0, I/1, etc.) removed to reduce join errors. Uniqueness is
/// enforced by the repository against the database; this type only produces
/// candidates.
class RoomCodeGenerator {
  RoomCodeGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  /// Length of a generated code.
  static const int codeLength = 6;

  /// Alphabet excluding easily-confused glyphs: no 0/O, 1/I/L, etc.
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Produces a single candidate code.
  String generate() {
    final buffer = StringBuffer();
    for (var i = 0; i < codeLength; i++) {
      buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Whether [code] is structurally a valid room code (correct length and all
  /// characters within the alphabet). Used to validate user-entered codes
  /// before a database lookup.
  static bool isValid(String code) {
    if (code.length != codeLength) return false;
    for (final unit in code.codeUnits) {
      if (!_alphabet.contains(String.fromCharCode(unit))) return false;
    }
    return true;
  }
}
