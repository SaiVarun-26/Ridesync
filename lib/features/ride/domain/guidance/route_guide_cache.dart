import 'dart:collection';
import 'dart:isolate';

import '../route_model.dart';
import 'route_guide.dart';

/// Builds [RouteGuide]s off the UI thread and keeps the last few.
///
/// The planning preview, the live map and every reconnect ask for the same
/// route; it is decoded and analysed once, in a background isolate, and the
/// result is reused. Concurrent requests for one route share one build.
class RouteGuideCache {
  RouteGuideCache({this.capacity = 3});

  /// Shared by the whole app: routes are immutable, so one cache is enough.
  static final RouteGuideCache instance = RouteGuideCache();

  final int capacity;

  final LinkedHashMap<String, RouteGuide> _built = LinkedHashMap();
  final Map<String, Future<RouteGuide>> _building = {};

  /// Short routes are cheaper to analyse here than to send to an isolate.
  static const int _isolateFromChars = 600;

  Future<RouteGuide> guideFor(PlannedRoute route) {
    final key = route.encodedPolyline;
    final hit = _built.remove(key);
    if (hit != null && hit.route == route) {
      _built[key] = hit;
      return Future.value(hit);
    }
    final pending = _building[key];
    if (pending != null) return pending;

    final future = key.length < _isolateFromChars
        ? Future.value(RouteGuide.build(route))
        : Isolate.run(() => RouteGuide.build(route));
    final tracked = future.then((guide) {
      _built[key] = guide;
      while (_built.length > capacity) {
        _built.remove(_built.keys.first);
      }
      return guide;
    });
    _building[key] = tracked;
    tracked.whenComplete(() {
      _building.remove(key);
    }).ignore();
    return tracked;
  }
}
