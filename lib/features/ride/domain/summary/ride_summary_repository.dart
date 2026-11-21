import '../../../../core/errors/result.dart';
import 'ride_summary.dart';

/// Contract for the finished ride's summary.
///
/// The host writes the summary exactly once, when ending the ride; every rider
/// then reads it for the results screens. Summaries are permanent: they are
/// not removed when riders leave the room.
abstract interface class RideSummaryRepository {
  /// Saves [summary] for room [code], replacing the last snapshot. Written by
  /// each rider when they finish their own ride.
  Future<Result<void>> save({
    required String code,
    required RideSummary summary,
  });

  /// The summary for room [code] as it is now; `null` when there is none yet
  /// or it cannot be read.
  Future<RideSummary?> load({required String code});

  /// The summary for room [code], live. Emits `null` until it is written.
  Stream<RideSummary?> watch({required String code});
}
