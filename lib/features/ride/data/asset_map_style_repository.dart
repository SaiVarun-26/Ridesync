import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/map_style_repository.dart';

/// [MapStyleRepository] that reads the bundled night style asset.
///
/// The style is validated as a JSON array (the Google Maps style format) and
/// cached after the first load, so initialization pays the cost once and the
/// map receives it instantly.
class AssetMapStyleRepository implements MapStyleRepository {
  AssetMapStyleRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<String>? _nightStyle;

  static const String _nightStyleAsset = 'assets/map/night_style.json';

  @override
  Future<String> loadNightStyle() {
    return _nightStyle ??= _load().catchError((Object error) {
      // Let a later call retry instead of caching the failure.
      _nightStyle = null;
      throw error;
    });
  }

  Future<String> _load() async {
    final json = await _bundle.loadString(_nightStyleAsset);
    if (jsonDecode(json) is! List) {
      throw const FormatException('Map style must be a JSON array.');
    }
    return json;
  }
}
