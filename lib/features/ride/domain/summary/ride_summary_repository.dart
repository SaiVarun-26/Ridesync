import '../../../../core/errors/result.dart';
import 'ride_summary.dart';

/// Contract for the finished ride's summary.
///
/// The host writes the summary exactly once, when ending the ride; every rider
/// then reads it for the results screens. Summaries are permanent: they are
/// not removed when riders leave the room.
abstract interface class RideSummaryRepository {
  /// Saves [summary] for room [code]. Host only, and only while the room is
  /// ending; a summary cannot be replaced once written.
  Future<Result<void>> save({
    required String code,
    required RideSummary summary,
  });

  /// The summary for room [code], live. Emits `null` until it is written.
  Stream<RideSummary?> watch({required String code});
}
