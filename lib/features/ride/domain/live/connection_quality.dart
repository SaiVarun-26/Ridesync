/// How fresh a rider's shared position is, in rider-friendly terms.
enum ConnectionQuality {
  good('Good'),
  fair('Fair'),
  poor('Poor'),
  offline('Offline');

  const ConnectionQuality(this.label);

  final String label;

  static const Duration _goodWithin = Duration(seconds: 5);
  static const Duration _fairWithin = Duration(seconds: 15);

  /// Quality of a rider whose last position reached this device
  /// [sinceUpdate] ago. Based on this device's own clock, so clock differences
  /// between phones do not matter.
  static ConnectionQuality fromAge(Duration sinceUpdate) {
    if (sinceUpdate <= _goodWithin) return ConnectionQuality.good;
    if (sinceUpdate <= _fairWithin) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }
}
