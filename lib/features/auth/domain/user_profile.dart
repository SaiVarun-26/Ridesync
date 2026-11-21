import 'package:flutter/foundation.dart';

/// A rider's own profile and preferences, stored under their uid and
/// restored on every device they sign in on.
@immutable
class UserProfile {
  const UserProfile({
    required this.uid,
    this.riderName,
    this.email,
    this.photoUrl,
    this.memberSince,
    this.soloColorId,
    this.fuelEnabled,
    this.hasPendingWrites = false,
  });

  final String uid;

  /// The name this rider chose to be called inside RideSync. Not the Google
  /// account's name. `null` until they have chosen one.
  final String? riderName;

  final String? email;
  final String? photoUrl;

  /// When the profile was first created.
  final DateTime? memberSince;

  // --- Preferences (synced) ---------------------------------------------------

  /// The rider's colour for solo rides (a `RiderPalette` id); `null` for the
  /// default.
  final String? soloColorId;

  /// Whether fuel stations are shown on the ride map; `null` when never set.
  final bool? fuelEnabled;

  /// Whether changes made on this device are still waiting to reach the
  /// cloud (offline, or just saved).
  final bool hasPendingWrites;

  bool get hasRiderName => riderName != null && riderName!.trim().isNotEmpty;
}
