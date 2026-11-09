/// Contract for loading the map's visual style.
///
/// The night style is loaded and validated during ride initialization so the
/// live map can apply it immediately when it appears.
abstract interface class MapStyleRepository {
  /// The night map style as a JSON string. Loaded once, then served from
  /// memory.
  Future<String> loadNightStyle();
}
