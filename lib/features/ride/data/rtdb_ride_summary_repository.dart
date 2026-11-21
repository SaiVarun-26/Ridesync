import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/summary/ride_summary.dart';
import '../domain/summary/ride_summary_repository.dart';
import 'ride_summary_dto.dart';

/// [RideSummaryRepository] on the Realtime Database.
class RtdbRideSummaryRepository implements RideSummaryRepository {
  RtdbRideSummaryRepository({required FirebaseDatabase database})
    : _database = database;

  final FirebaseDatabase _database;

  @override
  Future<Result<void>> save({
    required String code,
    required RideSummary summary,
  }) async {
    try {
      await _database
          .ref(RideSummaryPaths.summary(code))
          .set(RideSummaryDto.toValue(summary));
      return const Success(null);
    } on FirebaseException catch (e) {
      debugPrint('Saving the ride summary failed (${e.code}): ${e.message}');
      return Failed(
        e.code == 'permission-denied'
            ? const AuthFailure(
                message: 'Your ride could not be saved. Try again.',
              )
            : NetworkFailure(cause: e),
      );
    }
  }

  @override
  Future<RideSummary?> load({required String code}) async {
    try {
      final snapshot = await _database
          .ref(RideSummaryPaths.summary(code))
          .get()
          .timeout(const Duration(seconds: 6));
      return RideSummaryDto.fromValue(code, snapshot.value);
    } on Object catch (e) {
      debugPrint('Reading the ride summary failed: $e');
      return null;
    }
  }

  @override
  Stream<RideSummary?> watch({required String code}) {
    return _database
        .ref(RideSummaryPaths.summary(code))
        .onValue
        .map((event) => RideSummaryDto.fromValue(code, event.snapshot.value));
  }
}
