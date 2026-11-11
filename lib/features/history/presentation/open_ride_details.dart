import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import 'providers/ride_transition_providers.dart';

/// Opens the details of the ride in room [code], growing out of the card that
/// sits at [origin] on the screen.
void openRideDetails(
  BuildContext context,
  WidgetRef ref, {
  required String code,
  required Rect origin,
}) {
  ref.read(rideTransitionOriginProvider.notifier).set(origin);
  context.push(AppRoutes.historyDetailsPath(code));
}
