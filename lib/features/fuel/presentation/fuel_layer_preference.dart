import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether fuel stations are shown on the ride map: the rider's choice,
/// remembered on the device across rides and restarts. On by default.
///
/// `null` until the saved choice has been read (a few milliseconds at
/// start), during which nothing is drawn, so a rider who turned stations off
/// never sees them flash up.
///
/// Only drawing reads this: the background search carries on either way, so
/// turning the layer back on shows everything at once and turning it off
/// sends nothing.
class FuelLayerPreference extends Notifier<bool?> {
  static const String key = 'map.fuel_stations_visible';

  @override
  bool? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(key) ?? true;
      // A choice made while reading wins.
      state ??= saved;
    } on Object catch (e) {
      debugPrint('[fuel] Reading the fuel layer setting failed: $e');
      state ??= true;
    }
  }

  Future<void> setVisible(bool visible) async {
    state = visible;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, visible);
    } on Object catch (e) {
      debugPrint('[fuel] Saving the fuel layer setting failed: $e');
    }
  }
}

final fuelLayerVisibleProvider = NotifierProvider<FuelLayerPreference, bool?>(
  FuelLayerPreference.new,
);
