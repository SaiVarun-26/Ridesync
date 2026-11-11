import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Small on-device store for JSON documents, keyed by name.
abstract interface class JsonCache {
  /// The document saved under [key], or `null` if there is none or it cannot
  /// be read.
  Future<Map<String, Object?>?> read(String key);

  /// Saves [value] under [key], replacing any previous document.
  Future<void> write(String key, Map<String, Object?> value);
}

/// [JsonCache] that keeps one file per key in a directory.
///
/// Writes go to a temporary file first and are then renamed into place, so a
/// crash mid-write never leaves a half-written document. Failures are logged
/// and swallowed: the cache only ever makes things faster or available
/// offline, so it must not break the screen that uses it.
class FileJsonCache implements JsonCache {
  FileJsonCache(this._directory);

  final Future<Directory> Function() _directory;

  Future<File> _file(String key, {String suffix = '.json'}) async {
    final directory = await _directory();
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return File('${directory.path}${Platform.pathSeparator}$safe$suffix');
  }

  @override
  Future<Map<String, Object?>?> read(String key) async {
    try {
      final file = await _file(key);
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object catch (e) {
      debugPrint('Reading cache "$key" failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    try {
      final file = await _file(key);
      final temp = await _file(key, suffix: '.tmp');
      await temp.writeAsString(jsonEncode(value), flush: true);
      await temp.rename(file.path);
    } on Object catch (e) {
      debugPrint('Writing cache "$key" failed: $e');
    }
  }
}
