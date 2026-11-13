import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_icon.dart';

/// Shows a dialog that arrives with the app's shared-axis motion: it scales
/// and fades in from slightly smaller and leaves the same way, over a dimmed
/// backdrop.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.scrim,
    transitionDuration: AppMotion.slow,
    pageBuilder: (context, _, _) =>
        SafeArea(child: Center(child: builder(context))),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.scaled,
        // The dialog sits over the dimmed screen, not over a fill.
        fillColor: Colors.transparent,
        child: child,
      );
    },
  );
}

/// Shows a bottom sheet that rises with a gentle spring, settling a touch past
/// its resting place, and leaves with a quick ease.
///
/// The sheet is the app's surface colour with rounded top corners and a drag
/// handle.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    sheetAnimationStyle: const AnimationStyle(
      curve: AppMotion.spring,
      duration: AppMotion.springDuration,
      reverseCurve: AppMotion.exit,
      reverseDuration: AppMotion.normal,
    ),
    builder: builder,
  );
}

/// Shows a short message at the bottom of the screen in the app's style: a
/// rounded solid card with a hairline border and a small status icon. It
/// replaces whatever message is already showing.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = true,
}) {
  final color = isError ? AppColors.error : AppColors.success;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: AppIconSize.medium,
              color: color,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
