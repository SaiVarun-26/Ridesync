import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../ride/domain/geo_point.dart';
import '../domain/fuel_station.dart';
import '../domain/fuel_station_source.dart';

/// [FuelStationProviders] on free, keyless OpenStreetMap services:
///
/// - **Photon** for [nearest]: a reverse search filtered to `amenity=fuel`,
///   nearest first, at most [photonLimit] per request.
/// - **Overpass** for [inBox]: every station in a box, uncapped. The public
///   servers are often overloaded, so each of [overpassHosts] is tried in
///   turn and the caller treats Overpass as a bonus, not a dependency.
///
/// The hosts are plain settings: a production deployment can point them at
/// its own Photon and Overpass servers. Data © OpenStreetMap contributors,
/// credited on the map.
class OsmFuelStationProviders implements FuelStationProviders {
  OsmFuelStationProviders({
    this.photonHost = 'photon.komoot.io',
    this.overpassHosts = const [
      'overpass-api.de',
      'overpass.kumi.systems',
      'overpass.private.coffee',
    ],
    this.photonTimeout = const Duration(seconds: 10),
    this.overpassTimeout = const Duration(seconds: 12),
  });

  final String photonHost;
  final List<String> overpassHosts;
  final Duration photonTimeout;
  final Duration overpassTimeout;

  static const int photonLimit = 50;
  static const String _userAgent =
      'RideSync/1.1 (com.ridesync.ridesync; fuel stations on the ride map)';

  @override
  Future<FuelProviderResult> nearest(GeoPoint c, double radiusMeters) async {
    final clock = Stopwatch()..start();
    final uri = Uri.https(photonHost, '/reverse', {
      'lat': c.latitude.toStringAsFixed(6),
      'lon': c.longitude.toStringAsFixed(6),
      'radius': (radiusMeters / 1000).toStringAsFixed(2),
      'osm_tag': 'amenity:fuel',
      'limit': '$photonLimit',
    });
    final (status, json, error) = await _get(uri, photonTimeout);
    if (error != null || status != HttpStatus.ok) {
      return FuelProviderFailed(
        error ?? 'HTTP $status',
        throttled: status == HttpStatus.tooManyRequests,
        provider: 'photon',
        elapsed: clock.elapsed,
      );
    }
    final stations = parsePhoton(json);
    if (stations == null) {
      return FuelProviderFailed(
        'unreadable reply',
        provider: 'photon',
        elapsed: clock.elapsed,
      );
    }
    final farthest = stations.fold<double>(
      0,
      (m, s) => math.max(m, s.point.distanceMetersTo(c)),
    );
    return FuelProviderFound(
      [
        for (final s in stations)
          if (s.point.distanceMetersTo(c) <= radiusMeters) s,
      ],
      // Nearest first: a full page that stops short of the radius means
      // more lie beyond it.
      capped: stations.length >= photonLimit && farthest < radiusMeters * 0.98,
      provider: 'photon',
      elapsed: clock.elapsed,
    );
  }

  @override
  Future<FuelProviderResult> inBox({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final clock = Stopwatch()..start();
    String f(double v) => v.toStringAsFixed(5);
    final query =
        '[out:json][timeout:10];'
        'nwr["amenity"="fuel"](${f(south)},${f(west)},${f(north)},${f(east)});'
        'out center tags;';
    final reasons = <String>[];
    for (final host in overpassHosts) {
      final uri = Uri.https(host, '/api/interpreter', {'data': query});
      final (status, json, error) = await _get(uri, overpassTimeout);
      if (error == null && status == HttpStatus.ok) {
        final stations = parseOverpass(json);
        if (stations != null) {
          return FuelProviderFound(
            stations,
            capped: false,
            provider: 'overpass:$host',
            elapsed: clock.elapsed,
          );
        }
        reasons.add('$host unreadable reply');
      } else {
        reasons.add('$host ${error ?? 'HTTP $status'}');
      }
    }
    return FuelProviderFailed(
      reasons.join('; '),
      provider: 'overpass',
      elapsed: clock.elapsed,
    );
  }

  /// GETs [uri] as JSON: (status, body, error). Never throws.
  Future<(int, Object?, String?)> _get(Uri uri, Duration timeout) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = _userAgent;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return (response.statusCode, null, null);
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return (response.statusCode, jsonDecode(body), null);
    } on TimeoutException {
      return (0, null, 'timed out');
    } on Object catch (e) {
      return (0, null, e.toString());
    } finally {
      client.close(force: true);
    }
  }

  static const Map<String, String> _photonTypes = {
    'N': 'node',
    'W': 'way',
    'R': 'relation',
  };

  /// The fuel stations in a Photon GeoJSON answer, or `null` when it is not
  /// one.
  @visibleForTesting
  static List<FuelStation>? parsePhoton(Object? json) {
    if (json is! Map) return null;
    final features = json['features'];
    if (features is! List) return null;
    final seen = <String>{};
    final stations = <FuelStation>[];
    for (final feature in features) {
      if (feature is! Map) continue;
      final props = feature['properties'];
      final geometry = feature['geometry'];
      if (props is! Map || geometry is! Map) continue;
      if (props['osm_key'] != 'amenity' || props['osm_value'] != 'fuel') {
        continue;
      }
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final lng = coordinates[0];
      final lat = coordinates[1];
      final type = _photonTypes[props['osm_type']];
      final id = props['osm_id'];
      if (lng is! num || lat is! num || type == null || id is! num) continue;
      final key = '$type/${id.toInt()}';
      if (!seen.add(key)) continue;
      stations.add(
        FuelStation(
          id: key,
          point: GeoPoint(latitude: lat.toDouble(), longitude: lng.toDouble()),
          name: _clean(props['name']),
        ),
      );
    }
    return stations;
  }

  /// The fuel stations in an Overpass answer, or `null` when it is not one.
  @visibleForTesting
  static List<FuelStation>? parseOverpass(Object? json) {
    if (json is! Map) return null;
    final elements = json['elements'];
    if (elements is! List) return null;
    final seen = <String>{};
    final stations = <FuelStation>[];
    for (final element in elements) {
      if (element is! Map) continue;
      final type = element['type'];
      final id = element['id'];
      if (type is! String || id is! num) continue;
      final center = element['center'];
      final lat = element['lat'] ?? (center is Map ? center['lat'] : null);
      final lon = element['lon'] ?? (center is Map ? center['lon'] : null);
      if (lat is! num || lon is! num) continue;
      final key = '$type/${id.toInt()}';
      if (!seen.add(key)) continue;
      final tags = element['tags'];
      Object? tag(String name) => tags is Map ? tags[name] : null;
      stations.add(
        FuelStation(
          id: key,
          point: GeoPoint(latitude: lat.toDouble(), longitude: lon.toDouble()),
          name:
              _clean(tag('name')) ??
              _clean(tag('brand')) ??
              _clean(tag('operator')),
          brand: _clean(tag('brand')),
          operator: _clean(tag('operator')),
        ),
      );
    }
    return stations;
  }

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final v = value.trim();
    if (v.isEmpty) return null;
    return v.length <= 80 ? v : v.substring(0, 80);
  }
}
