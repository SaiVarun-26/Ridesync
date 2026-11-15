import 'package:flutter/foundation.dart';

import '../../domain/geo_point.dart';

/// Lets the screen around the live map steer its camera without owning it.
///
/// The map widget attaches itself; the screen calls [recenter], [showOverview]
/// or [focus] and watches [isFollowing] to show a recenter control. Commands
/// sent while no map is attached are dropped.
class LiveMapCommands {
  /// Whether the camera is following this rider.
  final ValueNotifier<bool> isFollowing = ValueNotifier<bool>(true);

  LiveMapTarget? _target;

  /// Called by the map widget.
  void attach(LiveMapTarget target) => _target = target;

  /// Called by the map widget when it goes away.
  void detach(LiveMapTarget target) {
    if (identical(_target, target)) _target = null;
  }

  /// Follow this rider again.
  void recenter() => _target?.recenter();

  /// Frame all of [points] (a route overview) until [recenter].
  void showOverview(List<GeoPoint> points) => _target?.showOverview(points);

  /// Glide to [point] and hold there until [recenter].
  void focus(GeoPoint point) => _target?.focus(point);

  void dispose() => isFollowing.dispose();
}

/// What the map widget implements for [LiveMapCommands].
abstract interface class LiveMapTarget {
  void recenter();
  void showOverview(List<GeoPoint> points);
  void focus(GeoPoint point);
}
