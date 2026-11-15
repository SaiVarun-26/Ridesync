import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../ride/domain/geo_point.dart';
import 'reverse_geocoder.dart';
import 'ride_name_store.dart';
import 'ride_title_generator.dart';

/// Everything about ride names, in one place: suggesting one from where the
/// ride ended, cleaning what a rider types, and saving it.
///
/// History, solo rides, guided rides and room rides all name and rename
/// through this service, so a name is made, checked and stored the same way
/// everywhere.
class RideNamingService {
  RideNamingService({
    required ReverseGeocoder geocoder,
    required RideNameStore store,
  }) : _geocoder = geocoder,
       _store = store;

  final ReverseGeocoder _geocoder;
  final RideNameStore _store;

  /// A suggested name for a ride that ended at [end] (and began at [start],
  /// when known). Never fails: when the place cannot be found the suggestion
  /// is [RideNames.fallback].
  Future<String> suggest({GeoPoint? start, required GeoPoint? end}) async {
    if (end == null) return RideNames.fallback;
    final address = await _geocoder.lookup(end);
    return RideTitleGenerator.suggest(
      address: address,
      startToEndMeters: start?.distanceMetersTo(end),
    );
  }

  /// What a rider typed, made tidy: trimmed, runs of spaces collapsed, control
  /// characters dropped and cut to [RideNames.maxLength]. `null` when nothing
  /// usable is left.
  static String? clean(String raw) {
    final tidy = raw
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (tidy.isEmpty) return null;
    return RideTitleGenerator.clip(tidy);
  }

  /// Gives the ride its shared name, after the ride. Host only. Returns the
  /// name as saved.
  Future<Result<String>> nameRide({
    required String code,
    required String name,
  }) async {
    final cleaned = clean(name);
    if (cleaned == null) {
      return const Failed(UnexpectedFailure(message: 'Give your ride a name.'));
    }
    final saved = await _store.saveSharedName(code: code, name: cleaned);
    return switch (saved) {
      Success() => Success(cleaned),
      Failed(:final failure) => Failed(failure),
    };
  }

  /// Renames the rider's own copy of the ride later on. Returns the name as
  /// saved.
  Future<Result<String>> renameMyRide({
    required String uid,
    required String code,
    required String name,
  }) async {
    final cleaned = clean(name);
    if (cleaned == null) {
      return const Failed(UnexpectedFailure(message: 'Give your ride a name.'));
    }
    final saved = await _store.saveMyName(uid: uid, code: code, name: cleaned);
    return switch (saved) {
      Success() => Success(cleaned),
      Failed(:final failure) => Failed(failure),
    };
  }

  /// For a ride saved before the host had named it: once the host has, copies
  /// the shared name onto the rider's own entry. Returns the new name, or
  /// `null` when the host has not named the ride yet (or it cannot be read).
  Future<String?> syncSharedName({
    required String uid,
    required String code,
  }) async {
    final shared = await _store.readSharedName(code);
    if (shared == null || !shared.isFinal) return null;
    final saved = await _store.saveMyName(
      uid: uid,
      code: code,
      name: shared.name,
    );
    return saved.isSuccess ? shared.name : null;
  }
}
