import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/destination.dart';
import '../domain/geo_point.dart';
import '../domain/guidance/route_simplifier.dart';
import '../domain/polyline.dart';
import '../domain/route_repository.dart';

/// [RouteRepository] on free, keyless services built on OpenStreetMap data:
///
/// - **Photon** (photon.komoot.io) for search-as-you-type and naming a point
///   picked on the map.
/// - **OSRM** (router.project-osrm.org) for the road route.
///
/// Only the host calls these, a handful of times while planning; riders get
/// the finished route from the room. Both services ask for light use and an
/// identifying user agent, which this sends. All data is © OpenStreetMap
/// contributors and is credited on the planning screen.
class OsmRouteRepository implements RouteRepository {
  OsmRouteRepository({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

  static const String _photonHost = 'photon.komoot.io';
  static const String _osrmHost = 'router.project-osrm.org';
  static const String _userAgent =
      'RideSync/1.0 (com.ridesync.ridesync; group ride planner)';

  /// The room's route field accepts at most this many characters; a little
  /// is kept spare.
  static const int maxEncodedLength = 95000;

  static const int _suggestionLimit = 6;

  /// Suggestions already fetched, by id, so choosing one needs no request.
  final Map<String, Destination> _resolved = {};

  @override
  Future<Result<List<PlaceSuggestion>>> searchDestinations(
    String query, {
    GeoPoint? near,
    bool newSession = false,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const Success([]);
    final params = <String, String>{'q': text, 'limit': '$_suggestionLimit'};
    if (near != null) {
      params['lat'] = near.latitude.toStringAsFixed(4);
      params['lon'] = near.longitude.toStringAsFixed(4);
    }
    final json = await _getJson(Uri.https(_photonHost, '/api/', params));
    if (json == null) return const Failed(NetworkFailure());
    final places = parsePhoton(json);
    final suggestions = <PlaceSuggestion>[];
    for (final place in places) {
      final id = '${place.location.latitude},${place.location.longitude}';
      _resolved[id] = Destination(name: place.name, location: place.location);
      suggestions.add(
        PlaceSuggestion(
          placeId: id,
          primaryText: place.name,
          secondaryText: place.detail,
        ),
      );
    }
    return Success(suggestions);
  }

  @override
  Future<Result<Destination>> resolveDestination(String placeId) async {
    final known = _resolved[placeId];
    if (known != null) return Success(known);
    return const Failed(NotFoundFailure(message: 'That place is unavailable.'));
  }

  @override
  Future<Result<Destination>> describeLocation(GeoPoint at) async {
    final json = await _getJson(
      Uri.https(_photonHost, '/reverse', {
        'lat': at.latitude.toStringAsFixed(6),
        'lon': at.longitude.toStringAsFixed(6),
      }),
    );
    final places = json == null ? const <PhotonPlace>[] : parsePhoton(json);
    // The pin stays exactly where it was dropped; only its name is looked up.
    final name = places.isEmpty ? 'Pinned location' : places.first.name;
    return Success(Destination(name: name, location: at));
  }

  @override
  Future<Result<RouteEstimate>> computeRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    String coordinate(GeoPoint p) =>
        '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}';
    final uri = Uri.https(
      _osrmHost,
      '/route/v1/driving/${coordinate(origin)};${coordinate(destination)}',
      {'overview': 'full', 'geometries': 'polyline', 'steps': 'false'},
    );
    final json = await _getJson(uri);
    if (json == null) return const Failed(NetworkFailure());
    final estimate = parseOsrm(json);
    if (estimate == null) {
      return const Failed(
        NotFoundFailure(message: 'No road route to that place. Try another.'),
      );
    }
    return Success(estimate);
  }

  Future<Object?> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = _userAgent;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        // OSRM answers "no route" with 400 and a JSON body; anything else is
        // a transport problem.
        return response.statusCode == HttpStatus.badRequest
            ? const <String, Object?>{}
            : null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return jsonDecode(body);
    } on Object catch (e) {
      debugPrint('Route service request failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// The places in a Photon GeoJSON answer.
  @visibleForTesting
  static List<PhotonPlace> parsePhoton(Object? json) {
    if (json is! Map) return const [];
    final features = json['features'];
    if (features is! List) return const [];
    final places = <PhotonPlace>[];
    final seen = <String>{};
    for (final feature in features) {
      if (feature is! Map) continue;
      final geometry = feature['geometry'];
      final props = feature['properties'];
      if (geometry is! Map || props is! Map) continue;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final lng = coordinates[0];
      final lat = coordinates[1];
      if (lng is! num || lat is! num) continue;
      String? field(String key) {
        final v = props[key];
        return v is String && v.trim().isNotEmpty ? v.trim() : null;
      }

      final street = field('street');
      final number = field('housenumber');
      final name =
          field('name') ??
          (street == null ? null : [street, ?number].join(' ')) ??
          field('city');
      if (name == null) continue;
      final city = field('city');
      final detail = <String>[
        if (city != null && city != name) city,
        ?field('state'),
        ?field('country'),
      ].join(', ');
      if (!seen.add('$name|$detail')) continue;
      places.add(
        PhotonPlace(
          name: name.length > 200 ? name.substring(0, 200) : name,
          detail: detail,
          location: GeoPoint(
            latitude: lat.toDouble(),
            longitude: lng.toDouble(),
          ),
        ),
      );
    }
    return places;
  }

  /// The first route in an OSRM answer, fitted to the room's size limit, or
  /// `null` when there is none.
  @visibleForTesting
  static RouteEstimate? parseOsrm(Object? json) {
    if (json is! Map || json['code'] != 'Ok') return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final route = routes.first;
    if (route is! Map) return null;
    final geometry = route['geometry'];
    final distance = route['distance'];
    final duration = route['duration'];
    if (geometry is! String || distance is! num || duration is! num) {
      return null;
    }
    final points = decodePolyline(geometry);
    if (points.length < 2) return null;
    final encoded = geometry.length <= maxEncodedLength
        ? geometry
        : RouteSimplifier.encodeWithin(points, maxLength: maxEncodedLength);
    if (encoded == null) return null;
    return RouteEstimate(
      encodedPolyline: encoded,
      distanceMeters: distance.round(),
      durationSeconds: duration.round(),
    );
  }
}

/// One place found by Photon.
@visibleForTesting
class PhotonPlace {
  const PhotonPlace({
    required this.name,
    required this.detail,
    required this.location,
  });

  final String name;
  final String detail;
  final GeoPoint location;
}
