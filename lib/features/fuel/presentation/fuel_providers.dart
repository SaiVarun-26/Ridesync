import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../history/data/json_cache.dart';
import '../data/osm_fuel_station_source.dart';
import '../domain/fuel_station_source.dart';
import 'fuel_station_controller.dart';

/// The services fuel stations are looked up in: OpenStreetMap via Photon and
/// Overpass, merged.
final fuelStationProvidersProvider = Provider<FuelStationProviders>((ref) {
  return OsmFuelStationProviders();
});

/// The fuel stations around the rider. One for the whole app, so what one
/// ride found is there for the next, in memory and on the device.
final fuelStationControllerProvider = Provider<FuelStationController>((ref) {
  final controller = FuelStationController(
    providers: ref.watch(fuelStationProvidersProvider),
    cache: FileJsonCache(() async {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}${Platform.pathSeparator}fuel_cache_v2');
    }),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
