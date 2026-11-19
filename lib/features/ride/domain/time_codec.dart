/// Packs the time of every recorded route point into a short string, so a
/// ride can be replayed as it happened and its stops found later.
///
/// The first value is the epoch second of the first point; each next value is
/// the whole seconds since the one before. Values are written with the same
/// variable-length printable encoding as a Google encoded polyline, so a
/// point a few seconds after the last costs one character.
abstract final class TimeCodec {
  static String encode(List<int> timesMs) {
    final buffer = StringBuffer();
    var previous = 0;
    for (var i = 0; i < timesMs.length; i++) {
      final seconds = timesMs[i] ~/ 1000;
      // Times never go backwards; a clock step back is stored as no time.
      final delta = i == 0 ? seconds : (seconds - previous).clamp(0, 1 << 30);
      _write(buffer, delta);
      previous = i == 0 ? seconds : previous + delta;
    }
    return buffer.toString();
  }

  /// The times in [encoded], in epoch milliseconds. Malformed input yields
  /// the times decoded before the error.
  static List<int> decode(String encoded) {
    final result = <int>[];
    var index = 0;
    var seconds = 0;
    while (index < encoded.length) {
      var value = 0;
      var shift = 0;
      var done = false;
      while (index < encoded.length) {
        final chunk = encoded.codeUnitAt(index++) - 63;
        if (chunk < 0) return result;
        value |= (chunk & 0x1F) << shift;
        shift += 5;
        if (chunk < 0x20) {
          done = true;
          break;
        }
      }
      if (!done) break;
      seconds = result.isEmpty ? value : seconds + value;
      result.add(seconds * 1000);
    }
    return result;
  }

  static void _write(StringBuffer buffer, int value) {
    var v = value;
    while (v >= 0x20) {
      buffer.writeCharCode((0x20 | (v & 0x1F)) + 63);
      v >>= 5;
    }
    buffer.writeCharCode(v + 63);
  }
}
