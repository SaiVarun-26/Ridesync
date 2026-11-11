import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where on screen the history card that was just tapped sits, so the ride
/// details can grow out of it. `null` when the details open some other way.
final rideTransitionOriginProvider =
    NotifierProvider<RideTransitionOrigin, Rect?>(RideTransitionOrigin.new);

class RideTransitionOrigin extends Notifier<Rect?> {
  @override
  Rect? build() => null;

  void set(Rect? origin) => state = origin;
}
