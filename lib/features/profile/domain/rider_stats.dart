import 'package:flutter/foundation.dart';

import '../../history/domain/ride_history_entry.dart';
import '../../room/domain/ride_mode.dart';

/// A rider's figures across their whole ride history, for the profile page.
///
/// Worked out on the device from the history entries (the same records the
/// history list shows), so they always agree with it and need nothing extra
/// stored in the cloud.
@immutable
class RiderStats {
  const RiderStats({
    required this.totalRides,
    required this.totalDistanceMeters,
    required this.totalRideTime,
    required this.highestSpeedMps,
    required this.longestRideMeters,
    required this.averageDistanceMeters,
    required this.averageSpeedMps,
    required this.guidedRides,
    required this.freeRoamRides,
    required this.groupRides,
    required this.soloRides,
  });

  static const RiderStats empty = RiderStats(
    totalRides: 0,
    totalDistanceMeters: 0,
    totalRideTime: Duration.zero,
    highestSpeedMps: 0,
    longestRideMeters: 0,
    averageDistanceMeters: 0,
    averageSpeedMps: 0,
    guidedRides: 0,
    freeRoamRides: 0,
    groupRides: 0,
    soloRides: 0,
  );

  final int totalRides;
  final double totalDistanceMeters;

  /// Time spent riding (pauses excluded), summed over every ride.
  final Duration totalRideTime;

  final double highestSpeedMps;

  /// The furthest single ride.
  final double longestRideMeters;

  final double averageDistanceMeters;

  /// Distance over moving time across all rides, so a long ride counts for
  /// more than a short one.
  final double averageSpeedMps;

  final int guidedRides;
  final int freeRoamRides;

  /// Rides with more than one rider.
  final int groupRides;
  final int soloRides;

  factory RiderStats.from(Iterable<RideHistoryEntry> entries) {
    var rides = 0;
    var distance = 0.0;
    var rideTimeMs = 0;
    var top = 0.0;
    var longest = 0.0;
    var movingSeconds = 0.0;
    var movingDistance = 0.0;
    var guided = 0;
    var free = 0;
    var group = 0;
    var solo = 0;

    for (final e in entries) {
      rides++;
      final d = _finite(e.distanceMeters);
      distance += d;
      rideTimeMs += e.durationMs > 0 ? e.durationMs : 0;
      if (_finite(e.maxSpeedMps) > top) top = _finite(e.maxSpeedMps);
      if (d > longest) longest = d;
      final avg = _finite(e.averageSpeedMps);
      if (d > 0 && avg > 0) {
        movingSeconds += d / avg;
        movingDistance += d;
      }
      switch (e.mode) {
        case RideMode.guided:
          guided++;
        case RideMode.free:
          free++;
      }
      if (e.isGroup) {
        group++;
      } else {
        solo++;
      }
    }

    return RiderStats(
      totalRides: rides,
      totalDistanceMeters: distance,
      totalRideTime: Duration(milliseconds: rideTimeMs),
      highestSpeedMps: top,
      longestRideMeters: longest,
      averageDistanceMeters: rides == 0 ? 0 : distance / rides,
      averageSpeedMps: movingSeconds > 0 ? movingDistance / movingSeconds : 0,
      guidedRides: guided,
      freeRoamRides: free,
      groupRides: group,
      soloRides: solo,
    );
  }

  static double _finite(double value) =>
      value.isFinite && value > 0 ? value : 0;
}
