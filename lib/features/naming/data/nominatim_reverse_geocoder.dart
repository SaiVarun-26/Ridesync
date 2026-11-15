import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../ride/domain/geo_point.dart';
import '../domain/place_address.dart';
import '../domain/reverse_geocoder.dart';

/// [ReverseGeocoder] on OpenStreetMap's Nominatim service: free, no key.
///
/// Nominatim asks for light use and an identifying user agent. A ride is
/// named once, so this makes one small request per ride. Positions are sent
/// to about 10 m: an area is found from where the street is. Data is © OpenStreetMap
/// contributors, credited where the suggestion is shown.
class NominatimReverseGeocoder implements ReverseGeocoder {
  NominatimReverseGeocoder({this.timeout = const Duration(seconds: 6)});

  final Duration timeout;

  static const String _host = 'nominatim.openstreetmap.org';
  static const String _userAgent =
      'RideSync/1.0 (com.ridesync.ridesync; ride naming)';

  /// Zoom 16 resolves to a street but reports the neighbourhood, suburb and
  /// taluk around it; zoom 14 gives only coarse municipal zones in many
  /// Indian cities. Only area parts are ever used.
  static const String _zoom = '16';

  @override
  Future<PlaceAddress?> lookup(GeoPoint at) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = _userAgent;
    try {
      final uri = Uri.https(_host, '/reverse', {
        'format': 'jsonv2',
        'lat': at.latitude.toStringAsFixed(4),
        'lon': at.longitude.toStringAsFixed(4),
        'zoom': _zoom,
        'addressdetails': '1',
        'accept-language': 'en',
      });
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return parse(body);
    } on Object catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// The address in a Nominatim answer, or `null` when it has none.
  @visibleForTesting
  static PlaceAddress? parse(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final address = json['address'];
    if (address is! Map) return null;
    final parts = <String, String>{};
    address.forEach((key, value) {
      if (key is String && value is String && value.trim().isNotEmpty) {
        parts[key] = value.trim();
      }
    });
    return parts.isEmpty ? null : PlaceAddress(parts);
  }
}
