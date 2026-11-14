/// The few recap figures a history card shows, saved with the ride's history
/// entry once, so the list never has to work a recap out again.
///
/// Plain values only (ids and codes), so the history feature does not depend
/// on how recaps are made.
class RecapHighlights {
  const RecapHighlights({
    required this.score,
    required this.sentence,
    this.achievementIds = const [],
    this.weatherCode,
    this.temperatureC,
    this.isDay,
  });

  /// Format version written with the highlights, so a future change to what
  /// is saved can be told apart from this one.
  static const int version = 1;

  /// At most this many achievements are kept.
  static const int maxAchievements = 3;

  /// Longest recap sentence kept.
  static const int maxSentenceLength = 300;

  /// 0–100.
  final int score;
  final String sentence;

  /// The rider's achievements on the ride, best first, by stored name.
  final List<String> achievementIds;

  /// WMO weather code at the start of the ride, when it was recorded.
  final int? weatherCode;
  final double? temperatureC;
  final bool? isDay;
}
