import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../insights/presentation/providers/insights_providers.dart';
import 'providers/ride_details_providers.dart';
import 'providers/ride_history_providers.dart';

/// Asks, then removes ride [code] from the rider's history for good: the
/// card, and the ride's own records and saved copies (see
/// `RideHistoryRepository.delete`). Resolves to whether it was deleted.
Future<bool> deleteRideFlow(
  BuildContext context,
  WidgetRef ref, {
  required String code,
}) async {
  final uid = ref.read(authStateChangesProvider).value?.uid;
  if (uid == null) return false;
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (_) => const AppDialog(
      title: 'Delete Ride?',
      message: 'This will permanently remove this ride from your history.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      destructive: true,
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final result = await ref
      .read(rideHistoryRepositoryProvider)
      .delete(uid: uid, code: code);
  if (!context.mounted) return false;
  switch (result) {
    case Success():
      ref.read(rideHistoryProvider.notifier).remove(code);
      ref.read(rideRecapServiceProvider).forget(code);
      ref
        ..invalidate(rideDetailsProvider(code))
        ..invalidate(rideRecapProvider(code));
      showAppSnackBar(context, 'Ride deleted.', isError: false);
      return true;
    case Failed():
      showAppSnackBar(context, 'Could not delete the ride. Try again.');
      return false;
  }
}
