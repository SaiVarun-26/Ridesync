import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import '../../../../core/errors/result.dart';
import '../../../history/domain/ride_details.dart';
import '../../../history/domain/ride_details_repository.dart';
import '../../../ride/domain/summary/ride_summary.dart';
import '../achievements/achievement.dart';
import '../weather/weather_repositories.dart';
import 'ride_recap.dart';
import 'ride_recap_builder.dart';

/// Produces ride recaps, off the UI thread, and remembers them.
///
/// Building a recap walks every rider's route a few times, so it runs in a
/// background isolate. The result is kept for the most recent rides, so
/// opening the same ride again (results, details, share, history) never
/// works it out twice; requests for a recap already being built share that
/// one build.
class RideRecapService {
  RideRecapService({
    required RideDetailsRepository details,
    required RideWeatherRepository weather,
    String Function(RiderRideSummary rider)? nameOf,
    RideRecapBuilder builder = const RideRecapBuilder(),
    this.capacity = 16,
  }) : _details = details,
       _weather = weather,
       _nameOf = nameOf,
       _builder = builder;

  final RideDetailsRepository _details;
  final RideWeatherRepository _weather;
  final RideRecapBuilder _builder;

  /// How the app names a rider. Resolved here, on the calling isolate, and
  /// handed to the builder as plain strings.
  final String Function(RiderRideSummary rider)? _nameOf;

  /// How many recaps are kept.
  final int capacity;

  final LinkedHashMap<String, RideRecap> _cache = LinkedHashMap();
  final Map<String, Future<RideRecap>> _building = {};

  static String _key(String code, String? uid) => '$code|$uid';

  /// The recap for ride [code] as seen by [myUid], if already built.
  RideRecap? cached(String code, String? myUid) {
    final key = _key(code, myUid);
    final recap = _cache.remove(key);
    if (recap != null) _cache[key] = recap;
    return recap;
  }

  /// Drops every remembered recap of ride [code] (for any rider), so the next
  /// request builds it again, for instance after the ride was renamed.
  void forget(String code) {
    _cache.removeWhere((key, _) => key.startsWith('$code|'));
  }

  /// The recap for already loaded [details].
  Future<RideRecap> fromDetails(
    RideDetails details, {
    required String? myUid,
    List<PastRide> previousRides = const [],
  }) {
    final code = details.summary.roomCode;
    final hit = cached(code, myUid);
    if (hit != null) return Future.value(hit);
    final key = _key(code, myUid);
    // The block body matters: `whenComplete` waits for any future its
    // callback returns, and `remove` returns this very build, so an arrow
    // here would make the build wait for itself forever.
    return _building[key] ??= _build(details, myUid, previousRides)
        .whenComplete(() {
          _building.remove(key);
        });
  }

  /// The recap for ride [code], loading the ride first. `null` when the ride
  /// cannot be loaded.
  Future<RideRecap?> load(
    String code, {
    required String? myUid,
    List<PastRide> previousRides = const [],
  }) async {
    final hit = cached(code, myUid);
    if (hit != null) return hit;
    final result = await _details.load(code);
    return switch (result) {
      Success(:final value) => fromDetails(
        value,
        myUid: myUid,
        previousRides: previousRides,
      ),
      Failed() => null,
    };
  }

  Future<RideRecap> _build(
    RideDetails details,
    String? myUid,
    List<PastRide> previousRides,
  ) async {
    final weather = await _weather.load(details.summary.roomCode);
    final nameOf = _nameOf;
    final input = RecapInput(
      details: details,
      myUid: myUid,
      weather: weather,
      previousRides: previousRides,
      riderNames: nameOf == null
          ? const {}
          : {for (final r in details.summary.riders) r.uid: nameOf(r)},
    );
    final builder = _builder;
    RideRecap recap;
    try {
      recap = await Isolate.run(() => builder.build(input));
    } on Object {
      // Isolates are unavailable in some test and debug setups; the build is
      // the same either way.
      recap = builder.build(input);
    }
    final key = _key(details.summary.roomCode, myUid);
    _cache[key] = recap;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return recap;
  }
}
