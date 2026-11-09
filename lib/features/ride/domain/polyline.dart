import 'dart:math' as math;

import 'geo_point.dart';

/// Encodes [points] as a Google encoded polyline (5-decimal precision), a very
/// compact text form: a few characters per point.
String encodePolyline(List<GeoPoint> points) {
  const precision = 1e5;
  final buffer = StringBuffer();
  var previousLat = 0;
  var previousLng = 0;

  void write(int value) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      buffer.writeCharCode((0x20 | (v & 0x1F)) + 63);
      v >>= 5;
    }
    buffer.writeCharCode(v + 63);
  }

  for (final point in points) {
    final lat = (point.latitude * precision).round();
    final lng = (point.longitude * precision).round();
    write(lat - previousLat);
    write(lng - previousLng);
    previousLat = lat;
    previousLng = lng;
  }
  return buffer.toString();
}

/// Decodes a Google encoded polyline into points.
///
/// Implements Google's published algorithm (5-decimal precision), so routes
/// are decoded on the device without any extra package. Malformed input
/// yields the points decoded before the error.
List<GeoPoint> decodePolyline(String encoded) {
  const precision = 1e5;
  final points = <GeoPoint>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  int? nextDelta() {
    var result = 0;
    var shift = 0;
    while (index < encoded.length) {
      final byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
      if (byte < 0x20) {
        return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      }
    }
    return null;
  }

  while (index < encoded.length) {
    final dLat = nextDelta();
    final dLng = nextDelta();
    if (dLat == null || dLng == null) break;
    latitude += dLat;
    longitude += dLng;
    points.add(
      GeoPoint(latitude: latitude / precision, longitude: longitude / precision),
    );
  }
  return points;
}

/// The smallest latitude/longitude box containing a set of points.
class GeoBounds {
  const GeoBounds({required this.southwest, required this.northeast});

  final GeoPoint southwest;
  final GeoPoint northeast;

  /// Bounds around [points], or `null` when there are none.
  static GeoBounds? around(Iterable<GeoPoint> points) {
    final list = points.toList();
    if (list.isEmpty) return null;
    var south = list.first.latitude;
    var north = south;
    var west = list.first.longitude;
    var east = west;
    for (final p in list.skip(1)) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    return GeoBounds(
      southwest: GeoPoint(latitude: south, longitude: west),
      northeast: GeoPoint(latitude: north, longitude: east),
    );
  }
}
