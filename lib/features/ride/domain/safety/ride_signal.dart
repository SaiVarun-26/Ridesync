import '../geo_point.dart';

/// A short message a rider sends the whole group during a ride.
enum RideSignalKind {
  /// "I need attention": stays up until the rider clears it.
  attention('attention'),

  /// "Let's regroup": asks the group to gather.
  regroup('regroup'),

  /// "Follow me": asks the group to follow this rider.
  followMe('followMe'),

  /// "I'm OK": a check-in; also clears an earlier attention call.
  ok('ok');

  const RideSignalKind(this.wireValue);

  /// The value stored in the database (checked by the security rules).
  final String wireValue;

  /// Transient signals show for a little while; attention stays until
  /// cleared.
  bool get isPersistent => this == attention;

  static RideSignalKind? fromWire(Object? value) {
    for (final kind in values) {
      if (kind.wireValue == value) return kind;
    }
    return null;
  }
}

/// The latest signal from one rider. Each rider has at most one at a time;
/// sending another replaces it.
class RideSignal {
  const RideSignal({
    required this.uid,
    required this.kind,
    required this.sentAtMs,
    this.point,
  });

  final String uid;
  final RideSignalKind kind;

  /// Server time it was sent (epoch millis).
  final int sentAtMs;

  /// Where the rider was, when known.
  final GeoPoint? point;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideSignal &&
          other.uid == uid &&
          other.kind == kind &&
          other.sentAtMs == sentAtMs &&
          other.point == point);

  @override
  int get hashCode => Object.hash(uid, kind, sentAtMs, point);
}
