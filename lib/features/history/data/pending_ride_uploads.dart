import 'package:flutter/foundation.dart';

import 'json_cache.dart';

/// A finished ride whose history entry has not reached the cloud yet.
///
/// The ride's own record (statistics and route) is already written on the
/// device: the Realtime Database keeps unsent writes on disk and delivers
/// them when the connection returns, even after a restart. What still needs
/// doing is the publishing step (summary and history entry), which is what
/// this item queues.
@immutable
class PendingRideUpload {
  const PendingRideUpload({
    required this.uid,
    required this.code,
    required this.name,
    required this.queuedAtMs,
  });

  final String uid;
  final String code;

  /// The name the ride is saved under.
  final String name;
  final int queuedAtMs;

  Map<String, Object?> toJson() => {
    'uid': uid,
    'code': code,
    'name': name,
    'queuedAtMs': queuedAtMs,
  };

  static PendingRideUpload? fromJson(Object? value) {
    if (value is! Map) return null;
    final uid = value['uid'];
    final code = value['code'];
    final name = value['name'];
    final queued = value['queuedAtMs'];
    if (uid is! String || code is! String || name is! String) return null;
    return PendingRideUpload(
      uid: uid,
      code: code,
      name: name,
      queuedAtMs: queued is int ? queued : 0,
    );
  }
}

/// The on-device queue of [PendingRideUpload]s, kept in a [JsonCache] so it
/// survives the app being closed.
class PendingRideUploads {
  PendingRideUploads(this._cache);

  final JsonCache _cache;

  static const String cacheKey = 'pending_ride_uploads';

  Future<List<PendingRideUpload>> all() async {
    final json = await _cache.read(cacheKey);
    final items = json?['items'];
    if (items is! List) return const [];
    return [for (final item in items) ?PendingRideUpload.fromJson(item)];
  }

  /// Adds [upload], replacing an earlier item for the same rider and ride.
  Future<List<PendingRideUpload>> add(PendingRideUpload upload) async {
    final next = [
      for (final item in await all())
        if (!_same(item, upload.uid, upload.code)) item,
      upload,
    ];
    await _save(next);
    return next;
  }

  Future<List<PendingRideUpload>> remove({
    required String uid,
    required String code,
  }) async {
    final next = [
      for (final item in await all())
        if (!_same(item, uid, code)) item,
    ];
    await _save(next);
    return next;
  }

  static bool _same(PendingRideUpload item, String uid, String code) =>
      item.uid == uid && item.code == code;

  Future<void> _save(List<PendingRideUpload> items) => items.isEmpty
      ? _cache.remove(cacheKey)
      : _cache.write(cacheKey, {
          'items': [for (final item in items) item.toJson()],
        });
}
