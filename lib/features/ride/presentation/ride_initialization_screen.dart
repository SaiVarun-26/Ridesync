import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/glow_button.dart';
import '../../../core/widgets/pulse_indicator.dart';
import '../../room/domain/room.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';
import '../../room/presentation/widgets/room_state_views.dart';
import '../domain/initialization/init_task.dart';
import 'providers/ride_init_providers.dart';
import 'widgets/init_step_row.dart';

/// The cinematic hand-off between choosing a ride type and riding.
///
/// Every rider's device runs its own initialization plan; this screen only
/// renders this device's steps and the group's count. Other riders' progress
/// is never simulated: they appear in the count once their own device reports
/// initialized. When every connected rider has finished, the host's device
/// advances the room and everyone moves on together via the room status.
class RideInitializationScreen extends ConsumerStatefulWidget {
  const RideInitializationScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<RideInitializationScreen> createState() =>
      _RideInitializationScreenState();
}

class _RideInitializationScreenState
    extends ConsumerState<RideInitializationScreen> {
  late final AppLifecycleListener _lifecycle;

  /// The initialization this screen is showing, once the ride type is known.
  RideInitArgs? _args;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Returning from Settings (or any app switch) re-checks a blocked step,
  /// e.g. a location permission granted in Settings.
  void _onResume() {
    final args = _args;
    if (args != null) ref.read(rideInitControllerProvider(args).notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.roomCode;
    final roomAsync = ref.watch(roomStreamProvider(code));
    final connected = ref.watch(roomPresenceProvider(code)).value;
    listenToRoomFlow(
      ref,
      context,
      code: code,
      currentPath: AppRoutes.initializingPath(code),
    );

    return RoomExitScope(
      roomCode: code,
      builder: (context, _, _) => Scaffold(
        body: SafeArea(
          child: roomAsync.when(
            loading: () => const RoomLoadingView(),
            error: (_, _) =>
                const RoomMessageView(message: RoomMessageView.loadError),
            data: (room) {
              final mode = room?.mode;
              if (room == null) {
                return const RoomMessageView(
                  message: RoomMessageView.unavailable,
                );
              }
              if (mode == null) return const RoomLoadingView();
              final args = (code: code, mode: mode);
              _args = args;
              return _InitializationBody(
                args: args,
                room: room,
                isOffline: connected == false,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InitializationBody extends ConsumerWidget {
  const _InitializationBody({
    required this.args,
    required this.room,
    required this.isOffline,
  });

  final RideInitArgs args;
  final Room room;
  final bool isOffline;

  static const double _contentMaxWidth = 300;
  static const double _markSize = 72;
  static const Duration _rowStagger = Duration(milliseconds: 90);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final init = ref.watch(rideInitControllerProvider(args));
    final controller = ref.read(rideInitControllerProvider(args).notifier);
    final blocked = init.blockedStep;

    final Widget status;
    if (isOffline) {
      status = const _StatusLine(
        key: ValueKey<String>('offline'),
        text: 'Reconnecting…',
      );
    } else if (blocked != null) {
      status = _PermissionPanel(
        key: const ValueKey<String>('blocked'),
        blocker: blocked.blocker,
        onGrant: controller.resolveBlocker,
      );
    } else if (init.isComplete) {
      status = _GroupProgress(key: const ValueKey<String>('group'), room: room);
    } else if (init.isSlow) {
      status = const _StatusLine(
        key: ValueKey<String>('slow'),
        text: 'Still preparing…',
        spinner: true,
      );
    } else {
      status = const SizedBox.shrink(key: ValueKey<String>('none'));
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: _markSize, breathing: true),
              const SizedBox(height: AppSpacing.xxl),
              FadeSlideIn(
                child: Text(
                  'Preparing your ride...',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final (index, step) in init.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: FadeSlideIn(
                    key: ValueKey<String>(step.id),
                    delay: _rowStagger * (index + 1),
                    child: InitStepRow(step: step),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              AnimatedSwitcher(
                duration: AppMotion.slow,
                switchInCurve: AppMotion.curve,
                switchOutCurve: AppMotion.curve,
                child: status,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Waiting for riders..." with a live, smoothly counting "3 / 5 Ready".
class _GroupProgress extends StatelessWidget {
  const _GroupProgress({super.key, required this.room});

  final Room room;

  static const double _countSize = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = room.connectedMembers.length;
    final everyone = room.everyoneConnectedInitialized;
    return Column(
      children: [
        Text(
          everyone ? 'Everyone is ready.' : 'Waiting for riders...',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: room.initializedCount.toDouble()),
          duration: AppMotion.slow,
          curve: AppMotion.curve,
          builder: (context, value, _) => Text(
            '${value.round()} / $total Ready',
            style: AppTypography.stat(fontSize: _countSize),
          ),
        ),
      ],
    );
  }
}

/// Explains a denied location permission and offers to grant it.
class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({
    super.key,
    required this.blocker,
    required this.onGrant,
  });

  final InitBlocker? blocker;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viaSettings = blocker == InitBlocker.locationPermissionDeniedForever;
    return Column(
      children: [
        Text(
          'Location Permission Required',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          viaSettings
              ? 'Turn on location for RideSync in Settings, then come back.'
              : 'RideSync uses your location to keep the group together.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        GlowButton(label: 'Grant Permission', onPressed: onGrant),
      ],
    );
  }
}

/// A single calm status line with a pulse or a small spinner.
class _StatusLine extends StatelessWidget {
  const _StatusLine({super.key, required this.text, this.spinner = false});

  final String text;
  final bool spinner;

  static const double _spinnerSize = 14;
  static const double _strokeWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spinner)
          const SizedBox(
            width: _spinnerSize,
            height: _spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: _strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary),
            ),
          )
        else
          const PulseIndicator(),
        const SizedBox(width: AppSpacing.md),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
