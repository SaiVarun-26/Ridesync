import '../geo_point.dart';
import '../live/rider_trail.dart';

/// One rider as the leaderboard sees them: where they are now, how fast they
/// are going, and the path they have ridden.
class LeaderboardRider {
  const LeaderboardRider({
    required this.uid,
    required this.point,
    required this.isMe,
    this.speedMps,
    this.trail,
  });

  final String uid;
  final GeoPoint point;
  final bool isMe;
  final double? speedMps;

  /// Their ridden path, oldest first; `null` when none is known yet.
  final RiderTrail? trail;
}

/// One row of the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.rank,
    required this.isMe,
    required this.speedMps,
    required this.isOffPath,
    this.gapMeters,
  });

  final String uid;

  /// 1 for the rider furthest along.
  final int rank;
  final bool isMe;

  /// Live ground speed; 0 while stopped.
  final double speedMps;

  /// How far ahead of this rider (positive) or behind (negative) they are,
  /// measured along the path both are on. `null` when they do not share one
  /// right now, or for this rider's own row.
  final double? gapMeters;

  /// Whether they have left the group's path (free roam) or the planned route
  /// (guided ride).
  final bool isOffPath;

  @override
  bool operator ==(Object other) =>
      other is LeaderboardEntry &&
      other.uid == uid &&
      other.rank == rank &&
      other.isMe == isMe &&
      other.speedMps == speedMps &&
      other.gapMeters == gapMeters &&
      other.isOffPath == isOffPath;

  @override
  int get hashCode =>
      Object.hash(uid, rank, isMe, speedMps, gapMeters, isOffPath);
}

/// What happened to a rider's place on the shared path.
enum RidePathEventKind {
  /// Left the group's path, or the planned route.
  left('left'),

  /// Came back to it.
  rejoined('rejoined');

  const RidePathEventKind(this.wireValue);

  /// The value stored in the ride's event log.
  final String wireValue;
}

/// A rider leaving or rejoining the shared path, once.
class RidePathEvent {
  const RidePathEvent({
    required this.uid,
    required this.kind,
    required this.atMs,
    required this.guided,
    required this.point,
  });

  final String uid;
  final RidePathEventKind kind;
  final int atMs;

  /// Whether the path is a planned route (guided) or the group's own path.
  final bool guided;

  /// Where the rider was.
  final GeoPoint point;
}

/// The leaderboard after one update, and anything that happened in it.
class LeaderboardResult {
  const LeaderboardResult({required this.entries, required this.events});

  /// Best first.
  final List<LeaderboardEntry> entries;

  /// Riders who left or rejoined the path in this update.
  final List<RidePathEvent> events;
}
