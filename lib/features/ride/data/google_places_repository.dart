import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/geo_point.dart';
import '../domain/places_repository.dart';

/// [PlacesRepository] backed by the Places API (New) over HTTPS.
///
/// Requests carry the app's identity headers (Android package and signing
/// certificate, or iOS bundle id), so the API key can be restricted to this
/// app in Google Cloud. Autocomplete keystrokes and the final details lookup
/// share one session token, which Google bills as a single session.
class GooglePlacesRepository implements PlacesRepository {
  GooglePlacesRepository({
    required String apiKey,
    required String androidPackage,
    required String androidCertSha1,
    required String iosBundleId,
    HttpClient? httpClient,
    Random? random,
  })  : _apiKey = apiKey,
        _androidPackage = androidPackage,
        _androidCertSha1 =
            androidCertSha1.replaceAll(':', '').toUpperCase(),
        _iosBundleId = iosBundleId,
        _http = httpClient ?? HttpClient(),
        _random = random ?? Random.secure();

  final String _apiKey;
  final String _androidPackage;
  final String _androidCertSha1;
  final String _iosBundleId;
  final HttpClient _http;
  final Random _random;
  String? _sessionToken;

  static const String _host = 'places.googleapis.com';
  static const String _autocompletePath = '/v1/places:autocomplete';
  static const String _detailsFieldMask =
      'id,displayName,formattedAddress,location';
  static const Duration _timeout = Duration(seconds: 10);

  /// Radius used to rank results near the host.
  static const double _biasRadiusMeters = 50000;

  /// Session tokens are opaque; 24 random bytes encode to 32 URL-safe chars.
  static const int _sessionTokenBytes = 24;

  static const Failure _notConfigured = UnexpectedFailure(
    message: 'Destination search is not set up in this build.',
  );

  @override
  Future<Result<List<PlaceSuggestion>>> search(
    String query, {
    GeoPoint? near,
    bool newSession = false,
  }) async {
    if (_apiKey.isEmpty) return const Failed(_notConfigured);
    if (newSession || _sessionToken == null) _sessionToken = _newToken();

    final body = <String, Object?>{
      'input': query,
      'sessionToken': _sessionToken,
      if (near != null)
        'locationBias': <String, Object?>{
          'circle': <String, Object?>{
            'center': <String, Object?>{
              'latitude': near.latitude,
              'longitude': near.longitude,
            },
            'radius': _biasRadiusMeters,
          },
        },
    };

    final response = await _send(
      method: 'POST',
      uri: Uri.https(_host, _autocompletePath),
      body: body,
    );
    return switch (response) {
      Success(:final value) => Success(_parseSuggestions(value)),
      Failed(:final failure) => Failed(failure),
    };
  }

  @override
  Future<Result<PlaceDetails>> details(String placeId) async {
    if (_apiKey.isEmpty) return const Failed(_notConfigured);
    final token = _sessionToken;
    // A session ends with the details request.
    _sessionToken = null;

    final response = await _send(
      method: 'GET',
      uri: Uri.https(
        _host,
        '/v1/places/${Uri.encodeComponent(placeId)}',
        token == null ? null : <String, String>{'sessionToken': token},
      ),
      fieldMask: _detailsFieldMask,
    );
    switch (response) {
      case Failed(:final failure):
        return Failed(failure);
      case Success(:final value):
        final details = _parseDetails(value);
        if (details == null) {
          return const Failed(
            NotFoundFailure(message: 'That place has no usable location.'),
          );
        }
        return Success(details);
    }
  }

  Future<Result<Map<String, Object?>>> _send({
    required String method,
    required Uri uri,
    Map<String, Object?>? body,
    String? fieldMask,
  }) async {
    try {
      final request = await _http.openUrl(method, uri).timeout(_timeout);
      request.headers
        ..set('X-Goog-Api-Key', _apiKey)
        ..contentType = ContentType.json;
      if (fieldMask != null) request.headers.set('X-Goog-FieldMask', fieldMask);
      _addAppIdentity(request.headers);
      if (body != null) request.write(jsonEncode(body));

      final response = await request.close().timeout(_timeout);
      final text =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        debugPrint('Places API ${response.statusCode}: $text');
        return const Failed(
          UnexpectedFailure(
            message: 'Destination search failed. Please try again.',
          ),
        );
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) {
        return const Failed(
          UnexpectedFailure(message: 'Unexpected search response.'),
        );
      }
      return Success(decoded);
    } on TimeoutException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on SocketException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on HttpException catch (e) {
      return Failed(NetworkFailure(cause: e));
    } on FormatException catch (e) {
      return Failed(
        UnexpectedFailure(message: 'Unexpected search response.', cause: e),
      );
    }
  }

  void _addAppIdentity(HttpHeaders headers) {
    if (Platform.isAndroid) {
      headers.set('X-Android-Package', _androidPackage);
      if (_androidCertSha1.isNotEmpty) {
        headers.set('X-Android-Cert', _androidCertSha1);
      }
    } else if (Platform.isIOS) {
      headers.set('X-Ios-Bundle-Identifier', _iosBundleId);
    }
  }

  String _newToken() {
    final bytes = List<int>.generate(
      _sessionTokenBytes,
      (_) => _random.nextInt(256),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static List<PlaceSuggestion> _parseSuggestions(Map<String, Object?> json) {
    final suggestions = json['suggestions'];
    if (suggestions is! List) return const [];
    return [
      for (final entry in suggestions) ?_parseSuggestion(entry),
    ];
  }

  static PlaceSuggestion? _parseSuggestion(Object? entry) {
    if (entry is! Map) return null;
    final prediction = entry['placePrediction'];
    if (prediction is! Map) return null;
    final placeId = prediction['placeId'];
    if (placeId is! String) return null;

    final structured = prediction['structuredFormat'];
    final main = _text(structured is Map ? structured['mainText'] : null);
    final secondary =
        _text(structured is Map ? structured['secondaryText'] : null);
    final full = _text(prediction['text']);
    final primary = main ?? full;
    if (primary == null) return null;
    return PlaceSuggestion(
      placeId: placeId,
      primaryText: primary,
      secondaryText: secondary ?? '',
    );
  }

  static PlaceDetails? _parseDetails(Map<String, Object?> json) {
    final name = _text(json['displayName']);
    final location = json['location'];
    if (name == null || location is! Map) return null;
    final latitude = location['latitude'];
    final longitude = location['longitude'];
    if (latitude is! num || longitude is! num) return null;
    final address = json['formattedAddress'];
    return PlaceDetails(
      name: name,
      address: address is String ? address : '',
      location: GeoPoint(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
    );
  }

  /// Reads `{"text": "..."}` objects used throughout the Places API.
  static String? _text(Object? value) {
    if (value is! Map) return null;
    final text = value['text'];
    return text is String && text.isNotEmpty ? text : null;
  }
}
