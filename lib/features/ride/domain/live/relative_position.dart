import '../geo_point.dart';
import 'ride_format.dart';

/// Where another rider is, relative to this one.
enum RelativeDirection {
  /// Further along the ride than this rider.
  ahead,

  /// Not as far along the ride as this rider.
  behind,

  /// Direction cannot be told reliably (too close, no data, or the data
  /// disagrees with itself): only the distance is shown.
  unknown,
}

/// One rider's position relative to this rider: how far away they are right
/// now, and whether they are ahead or behind.
///
/// The distance is always the live great-circle distance between the two
/// riders' current GPS positions. Direction is decided from ride progression
/// first (who has covered more distance), with a heading-based fallback, and
/// is [RelativeDirection.unknown] only when neither can be trusted.
class RelativePosition {
  const RelativePosition({required this.meters, required this.direction});

  /// Live straight-line distance between the two riders.
  final double meters;
  final RelativeDirection direction;

  /// Closer than this, ahead and behind stop meaning anything: riding side by
  /// side, the distance is simply "away".
  static const double besideMeters = 15;

  /// Progression differences smaller than this are within the noise of two
  /// phones' GPS and their save intervals, so they decide nothing.
  static const double progressDeadbandMeters = 25;

  /// When the progression gap is this many times the straight-line distance
  /// (plus [_progressSlackMeters]), the two riders' distances are not
  /// comparable: one joined late, restarted, or took another road.
  static const double _progressRatioLimit = 4;
  static const double _progressSlackMeters = 500;

  /// The other rider counts as ahead within this angle of this rider's
  /// heading, and behind within this angle of the opposite direction.
  static const double _headingConeDegrees = 60;

  /// How far a rider's saved progression may be projected forward at their
  /// current speed, to cover the gap since it was last saved.
  static const Duration maxProgressProjection = Duration(seconds: 15);

  /// Works out where [other] is relative to [me].
  ///
  /// [myProgressMeters] and [theirProgressMeters] are each rider's distance
  /// covered so far, when known. [myHeadingDegrees] is this rider's direction
  /// of travel, or `null` while stopped.
  factory RelativePosition.between({
    required GeoPoint me,
    required GeoPoint other,
    double? myProgressMeters,
    double? theirProgressMeters,
    double? myHeadingDegrees,
  }) {
    final meters = me.distanceMetersTo(other);
    if (meters < besideMeters) {
      return RelativePosition(
        meters: meters,
        direction: RelativeDirection.unknown,
      );
    }

    final byProgress = _fromProgress(
      meters,
      myProgressMeters,
      theirProgressMeters,
    );
    if (byProgress != RelativeDirection.unknown) {
      return RelativePosition(meters: meters, direction: byProgress);
    }
    return RelativePosition(
      meters: meters,
      direction: _fromHeading(me, other, myHeadingDegrees),
    );
  }

  static RelativeDirection _fromProgress(
    double meters,
    double? mine,
    double? theirs,
  ) {
    if (mine == null || theirs == null) return RelativeDirection.unknown;
    final gap = theirs - mine;
    if (gap.abs() < progressDeadbandMeters) return RelativeDirection.unknown;
    if (gap.abs() > meters * _progressRatioLimit + _progressSlackMeters) {
      return RelativeDirection.unknown;
    }
    return gap > 0 ? RelativeDirection.ahead : RelativeDirection.behind;
  }

  static RelativeDirection _fromHeading(
    GeoPoint me,
    GeoPoint other,
    double? heading,
  ) {
    if (heading == null) return RelativeDirection.unknown;
    final bearing = me.bearingDegreesTo(other);
    final off = (((bearing - heading) + 540) % 360 - 180).abs();
    if (off <= _headingConeDegrees) return RelativeDirection.ahead;
    if (off >= 180 - _headingConeDegrees) return RelativeDirection.behind;
    return RelativeDirection.unknown;
  }

  /// A rider's progression projected forward from when it was last saved,
  /// at their current [speedMps], by at most [maxProgressProjection].
  static double projectProgress({
    required double savedMeters,
    required int? savedAtMs,
    required double? speedMps,
    required int nowMs,
  }) {
    if (savedAtMs == null || speedMps == null || speedMps <= 0) {
      return savedMeters;
    }
    final elapsedMs = (nowMs - savedAtMs).clamp(
      0,
      maxProgressProjection.inMilliseconds,
    );
    return savedMeters + speedMps * elapsedMs / 1000;
  }

  /// "48 m", "1.2 km".
  String get distanceLabel => RideFormat.distance(meters);

  /// "ahead", "behind" or "away".
  String get directionLabel => switch (direction) {
    RelativeDirection.ahead => 'ahead',
    RelativeDirection.behind => 'behind',
    RelativeDirection.unknown => 'away',
  };

  /// "48 m ahead".
  String get label => '$distanceLabel $directionLabel';
}
