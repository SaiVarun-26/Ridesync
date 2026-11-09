import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Builds the invite message shared from the lobby, with [code] filled in.
String buildRideInviteText(String code) => '''
🏍 Join my RideSync ride!

Ride Code:
$code

Open RideSync
Tap "Join Ride"
Enter the code

See you there.''';

/// Opens the platform's native share sheet with the invite for [code].
///
/// [anchorContext] should be the share button's context: iPad presents the
/// share sheet as a popover and needs the button's on-screen position.
Future<void> shareRideInvite({
  required BuildContext anchorContext,
  required String code,
}) async {
  final box = anchorContext.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  await SharePlus.instance.share(
    ShareParams(
      text: buildRideInviteText(code),
      subject: 'Join my RideSync ride',
      sharePositionOrigin: origin,
    ),
  );
}
