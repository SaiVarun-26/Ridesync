import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/glow_button.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/room.dart';
import '../domain/room_member.dart';
import '../domain/room_status.dart';
import 'providers/room_providers.dart';
import 'room_flow.dart';
import 'share_ride_invite.dart';
import 'widgets/color_picker_sheet.dart';
import 'widgets/lobby_action_bar.dart';
import 'widgets/rider_color_picker.dart';
import 'widgets/room_exit_scope.dart';
import 'widgets/room_open_pill.dart';
import 'widgets/room_state_views.dart';
import 'widgets/rider_tile.dart';

/// The pre-ride lobby for the room identified by [roomCode].
///
/// Riders claim a unique color and mark themselves ready; the host watches the
/// ready count and continues once everyone is set. Continue moves the room to
/// ride-type selection, and every rider's lobby follows that status change, so
/// no rider navigates manually.
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.roomCode});

  final String roomCode;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _isClaiming = false;
  bool _isActing = false;

  String get _code => widget.roomCode;

  // --- Color ---------------------------------------------------------------

  /// Claims [colorId] and returns an error message, or `null` on success.
  Future<String?> _claimColor(String colorId) async {
    if (_isClaiming) return null;
    setState(() => _isClaiming = true);
    final result = await ref
        .read(roomRepositoryProvider)
        .claimColor(code: _code, colorId: colorId);
    if (mounted) setState(() => _isClaiming = false);
    return switch (result) {
      Success() => null,
      Failed(:final failure) => failure.message,
    };
  }

  Future<void> _selectFeaturedColor(String colorId) async {
    final error = await _claimColor(colorId);
    if (error != null) _showMessage(error);
  }

  Future<void> _openColorSheet() {
    return showColorPickerSheet(
      context: context,
      roomCode: _code,
      onClaim: _claimColor,
    );
  }

  // --- Ready / continue ----------------------------------------------------

  Future<void> _toggleReady(RoomMember me) async {
    await _runAction(
      () => ref
          .read(roomRepositoryProvider)
          .setReady(code: _code, ready: !me.isReady),
    );
  }

  Future<void> _continue() async {
    // Navigation happens in the room-flow listener, for the host and every
    // rider alike.
    await _runAction(
      () => ref.read(roomRepositoryProvider).continueToRideMode(code: _code),
    );
  }

  Future<void> _runAction(Future<Result<void>> Function() action) async {
    if (_isActing) return;
    setState(() => _isActing = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _isActing = false);
    if (result case Failed(:final failure)) _showMessage(failure.message);
  }

  // --- Share ---------------------------------------------------------------

  Future<void> _share(BuildContext anchorContext) async {
    try {
      await shareRideInvite(anchorContext: anchorContext, code: _code);
    } on Exception catch (e) {
      debugPrint('Share failed: $e');
      _showMessage('Could not open the share sheet.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(_code));
    final myUid = ref.watch(authStateChangesProvider).value?.uid;
    // Keeps this rider marked online across reconnects while the lobby is open.
    ref.watch(roomPresenceProvider(_code));
    listenToRoomFlow(
      ref,
      context,
      code: _code,
      currentPath: AppRoutes.lobbyPath(_code),
    );

    return RoomExitScope(
      roomCode: _code,
      builder: (context, requestLeave, isLeaving) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'Leave ride',
              onPressed: isLeaving ? null : requestLeave,
              icon: const Icon(Icons.logout, color: AppColors.warning),
            ),
          ],
        ),
        body: roomAsync.when(
          loading: () => const RoomLoadingView(),
          error: (_, _) =>
              const RoomMessageView(message: RoomMessageView.loadError),
          data: (room) {
            if (room == null) {
              return const RoomMessageView(
                message: RoomMessageView.unavailable,
              );
            }
            final me = myUid == null ? null : room.memberByUid(myUid);
            return Column(
              children: [
                Expanded(
                  child: _LobbyContent(
                    room: room,
                    me: me,
                    canPickColor:
                        me != null && !me.isReady && !_isClaiming && !_isActing,
                    onShare: _share,
                    onSelectColor: _selectFeaturedColor,
                    onMoreColors: _openColorSheet,
                  ),
                ),
                LobbyActionBar(
                  room: room,
                  me: me,
                  isBusy: _isActing,
                  onToggleReady: () {
                    if (me != null) _toggleReady(me);
                  },
                  onContinue: _continue,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LobbyContent extends StatelessWidget {
  const _LobbyContent({
    required this.room,
    required this.me,
    required this.canPickColor,
    required this.onShare,
    required this.onSelectColor,
    required this.onMoreColors,
  });

  final Room room;
  final RoomMember? me;
  final bool canPickColor;
  final ValueChanged<BuildContext> onShare;
  final ValueChanged<String> onSelectColor;
  final VoidCallback onMoreColors;

  @override
  Widget build(BuildContext context) {
    final isHost = me?.isHost ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        _LobbyHeader(room: room, isHost: isHost, onShare: onShare),
        const SizedBox(height: AppSpacing.xxxl),
        SectionLabel('RIDERS  ·  ${room.members.length}'),
        const SizedBox(height: AppSpacing.md),
        for (final member in room.members)
          Padding(
            key: ValueKey<String>(member.uid),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: FadeSlideIn(
              child: RiderTile(member: member, isMe: member.uid == me?.uid),
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
        const SectionLabel('YOUR COLOR'),
        const SizedBox(height: AppSpacing.md),
        RiderColorPicker(
          claimedByOthers: room.colorsClaimedByOthers(me?.uid),
          mySelection: me?.colorId,
          enabled: canPickColor,
          onSelected: onSelectColor,
          onMore: onMoreColors,
        ),
        if (me?.isReady ?? false) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tap ✓ Ready to change your color.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ],
    );
  }
}

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({
    required this.room,
    required this.isHost,
    required this.onShare,
  });

  final Room room;
  final bool isHost;
  final ValueChanged<BuildContext> onShare;

  static const double _codeLetterSpacing = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          room.name,
          style: theme.textTheme.displaySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: RoomOpenPill(
            isOpen: room.status == RoomStatus.lobby,
            riders: room.members.length,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('RIDE CODE'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    room.code,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: _codeLetterSpacing,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (isHost)
              Builder(
                builder: (buttonContext) => GlowButton(
                  label: 'Share Ride',
                  icon: Icons.ios_share,
                  variant: GlowButtonVariant.secondary,
                  expand: false,
                  onPressed: () => onShare(buttonContext),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
