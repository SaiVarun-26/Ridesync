import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../room/presentation/providers/room_providers.dart';
import '../../../room/presentation/room_flow.dart';
import '../../../room/presentation/widgets/room_exit_scope.dart';

/// A room-flow screen that shows a short, centred title block for a ride stage.
///
/// It keeps the rider in sync with the room exactly like the other flow
/// screens: presence stays live, the screen follows status changes made by the
/// host, and back routes through the confirmed leave flow.
class RideStageScreen extends ConsumerWidget {
  const RideStageScreen({
    super.key,
    required this.roomCode,
    required this.currentPath,
    required this.title,
    required this.subtitle,
    required this.caption,
    this.leading,
    this.actions = const [],
  });

  /// Shown above the title, for example an animated badge.
  final Widget? leading;

  /// Buttons shown below the caption.
  final List<Widget> actions;

  final String roomCode;

  /// This screen's own route path, used to detect stage changes.
  final String currentPath;

  final String title;
  final String subtitle;
  final String caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(roomPresenceProvider(roomCode));
    listenToRoomFlow(ref, context, code: roomCode, currentPath: currentPath);
    final theme = Theme.of(context);

    return RoomExitScope(
      roomCode: roomCode,
      builder: (context, _, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: FadeSlideIn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      ...actions,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
