import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/glow_button.dart';
import '../../../core/widgets/pulse_indicator.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../room/domain/ride_mode.dart';
import '../../room/domain/room.dart';
import '../../room/presentation/providers/room_providers.dart';
import '../../room/presentation/room_flow.dart';
import '../../room/presentation/widgets/room_exit_scope.dart';
import '../../room/presentation/widgets/room_state_views.dart';
import 'widgets/ride_mode_card.dart';

/// Ride-type selection for room [roomCode], shown to the whole group once the
/// host continues from the lobby.
///
/// Only the host can choose. Everyone else sees the same two cards, disabled,
/// with a "Waiting for Host" status. When the host confirms, the room status
/// changes in RTDB and every rider's screen follows it automatically.
class RideModeScreen extends ConsumerStatefulWidget {
  const RideModeScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<RideModeScreen> createState() => _RideModeScreenState();
}

class _RideModeScreenState extends ConsumerState<RideModeScreen> {
  RideMode? _selected;
  bool _isSubmitting = false;

  String get _code => widget.roomCode;

  /// Delay between the two cards' entrance animations.
  static const Duration _cardStagger = Duration(milliseconds: 90);

  Future<void> _confirm() async {
    final mode = _selected;
    if (mode == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final result = await ref
        .read(roomRepositoryProvider)
        .chooseRideMode(code: _code, mode: mode);
    if (!mounted) return;
    // On success the room-flow listener navigates every rider, including the
    // host, so the button stays in its loading state until then.
    if (result case Failed(:final failure)) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(_code));
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    ref.watch(roomPresenceProvider(_code));
    listenToRoomFlow(
      ref,
      context,
      code: _code,
      currentPath: AppRoutes.rideModePath(_code),
    );

    return RoomExitScope(
      roomCode: _code,
      builder: (context, _, _) => Scaffold(
        body: SafeArea(
          child: roomAsync.when(
            loading: () => const RoomLoadingView(),
            error: (_, _) =>
                const RoomMessageView(message: RoomMessageView.loadError),
            data: (room) {
              if (room == null) {
                return const RoomMessageView(
                  message: RoomMessageView.unavailable,
                );
              }
              return _buildContent(room, isHost: room.hostUid == myUid);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Room room, {required bool isHost}) {
    final theme = Theme.of(context);
    final canChoose = isHost && !_isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              SectionLabel(room.name.toUpperCase()),
              const SizedBox(height: AppSpacing.sm),
              Text('Choose Ride Type', style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.lg),
              isHost
                  ? Text(
                      'Pick how your group rides today.',
                      style: theme.textTheme.bodyLarge,
                    )
                  : const _WaitingForHost(),
              const SizedBox(height: AppSpacing.xxl),
              FadeSlideIn(
                child: RideModeCard(
                  index: '01',
                  title: 'Guided Ride',
                  subtitle: 'Everyone follows the same destination.',
                  points: const [
                    'Host selects one destination.',
                    'Everyone receives the exact same planned route.',
                    'Perfect for organised rides.',
                  ],
                  selected: _selected == RideMode.guided,
                  onTap: canChoose
                      ? () => setState(() => _selected = RideMode.guided)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: _cardStagger,
                child: RideModeCard(
                  index: '02',
                  title: 'Free Roam',
                  subtitle: 'Ride Anywhere.',
                  points: const [
                    'No destination.',
                    'No navigation.',
                    'Just keep your group together.',
                  ],
                  selected: _selected == RideMode.free,
                  onTap: canChoose
                      ? () => setState(() => _selected = RideMode.free)
                      : null,
                ),
              ),
            ],
          ),
        ),
        if (isHost)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: GlowButton(
              label: switch (_selected) {
                RideMode.guided => 'Start Guided Ride →',
                RideMode.free => 'Start Free Roam →',
                null => 'Select a ride type',
              },
              isLoading: _isSubmitting,
              onPressed: _selected == null ? null : _confirm,
            ),
          ),
      ],
    );
  }
}

/// Status shown to riders while the host decides.
class _WaitingForHost extends StatelessWidget {
  const _WaitingForHost();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const PulseIndicator(),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Waiting for Host…', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Host is choosing the ride type.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
