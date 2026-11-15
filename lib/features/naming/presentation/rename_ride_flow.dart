import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../history/presentation/providers/ride_details_providers.dart';
import '../../history/presentation/providers/ride_history_providers.dart';
import '../../insights/presentation/providers/insights_providers.dart';
import 'naming_providers.dart';
import 'ride_name_dialog.dart';

/// Lets the rider rename their own copy of ride [code], from its details.
///
/// Opens the rename dialog; on saving, the new name is stored on their history
/// entry and everything that shows the ride is brought up to date at once:
/// the history list, the ride details, the recap (and so the share card) and
/// the device's saved copies. Resolves to the new name, or `null` when
/// cancelled.
Future<String?> renameRideFlow(
  BuildContext context,
  WidgetRef ref, {
  required String code,
  required String currentName,
}) async {
  final uid = ref.read(authStateChangesProvider).value?.uid;
  if (uid == null) return null;
  String? renamed;
  final saved = await showRideNameDialog(
    context,
    title: 'Rename Ride',
    confirmLabel: 'Save',
    initialName: currentName,
    barrierDismissible: true,
    onSave: (name) async {
      final result = await ref
          .read(rideNamingServiceProvider)
          .renameMyRide(uid: uid, code: code, name: name);
      switch (result) {
        case Success(:final value):
          renamed = value;
          ref.read(rideHistoryProvider.notifier).applyName(code, value);
          // The recap holds the ride's title, so it is built again.
          ref.read(rideRecapServiceProvider).forget(code);
          ref
            ..invalidate(rideDetailsProvider(code))
            ..invalidate(rideRecapProvider(code));
          return null;
        case Failed(:final failure):
          return failure.message;
      }
    },
  );
  return saved ? renamed : null;
}
