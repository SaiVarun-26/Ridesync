import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/geo_point.dart';
import '../domain/location_repository.dart';

/// [LocationRepository] backed by the `geolocator` plugin.
class GeolocatorLocationRepository implements LocationRepository {
  const GeolocatorLocationRepository();

  /// How often to re-check whether the location service is on. Polling works
  /// identically on Android and iOS.
  static const Duration _servicePollInterval = Duration(seconds: 2);

  @override
  Future<LocationAccess> checkPermission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<LocationAccess> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Stream<bool> watchServiceEnabled() => _pollServiceEnabled().distinct();

  Stream<bool> _pollServiceEnabled() async* {
    yield await isServiceEnabled();
    yield* Stream<void>.periodic(_servicePollInterval)
        .asyncMap((_) => isServiceEnabled());
  }

  @override
  Future<GeoPoint?> currentPosition({required Duration timeout}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(timeLimit: timeout),
      );
      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on TimeoutException {
      debugPrint('No GPS fix within ${timeout.inSeconds}s.');
      return null;
    } on LocationServiceDisabledException {
      debugPrint('Location service turned off while acquiring a fix.');
      return null;
    } on PermissionDeniedException {
      debugPrint('Location permission revoked while acquiring a fix.');
      return null;
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static LocationAccess _map(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine =>
        LocationAccess.denied,
    };
  }
}
