import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialogs.dart';
import '../../../../../core/widgets/app_icon.dart';
import '../../../../../core/widgets/pressable_scale.dart';
import '../../../../../core/widgets/ride_loader.dart';
import '../../../../../core/widgets/section_label.dart';
import '../../../../room/presentation/providers/room_providers.dart';
import '../../../domain/safety/ride_signal.dart';
import '../../../domain/safety/ride_status_report.dart';
import '../../providers/guidance_providers.dart';
import '../../providers/ride_map_providers.dart';
import '../../ride_map_controller.dart';
import '../../safety/safety_controller.dart';
import '../slide_to_confirm.dart';

/// Opens the ride's safety tools for room [code].
Future<void> showSafetySheet(
  BuildContext context, {
  required String code,
  required bool guided,
}) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafetySheet(code: code, guided: guided),
  );
}

/// Quick, calm safety actions during a ride: check in, ask to regroup, lead
/// the way, share a live status with someone outside the ride, and (behind a
/// slide, so it cannot go off in a pocket) call the group's attention.
class SafetySheet extends ConsumerWidget {
  const SafetySheet({super.key, required this.code, required this.guided});

  final String code;
  final bool guided;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final safety = ref.watch(safetyControllerProvider(code));
    final map = ref.watch(rideMapControllerProvider(code));
    final room = ref.watch(roomStreamProvider(code)).value;
    final controller = ref.read(safetyControllerProvider(code).notifier);
    final online = room?.connectedMembers.length ?? 0;
    final total = room?.members.length ?? 0;

    ref.listen<SafetyState>(safetyControllerProvider(code), (previous, next) {
      final result = next.lastResult;
      if (result == null || result.id == previous?.lastResult?.id) return;
      if (result.error != null) {
        showAppSnackBar(context, result.error!);
        return;
      }
      showAppSnackBar(context, _sentMessage(result.kind), isError: false);
      if (result.kind != RideSignalKind.attention) Navigator.of(context).pop();
    });

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ride safety', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            _RideStateRow(
              isConnected: map.isConnected,
              gps: map.gps,
              online: online,
              total: total,
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('TELL THE GROUP'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final (kind, label, icon) in const [
                  (RideSignalKind.ok, "I'm OK", Icons.check_rounded),
                  (RideSignalKind.regroup, 'Regroup', Icons.groups_rounded),
                  (RideSignalKind.followMe, 'Follow me', Icons.near_me_rounded),
                ]) ...[
                  if (kind != RideSignalKind.ok)
                    const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ActionTile(
                      label: label,
                      icon: icon,
                      busy: safety.sending == kind,
                      onTap: safety.sending == null
                          ? () => controller.send(kind)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Share my ride status',
              icon: Icons.ios_share_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => _shareStatus(context, ref),
            ),
            const SizedBox(height: AppSpacing.xl),
            AnimatedSwitcher(
              duration: AppMotion.normal,
              switchInCurve: AppMotion.curve,
              switchOutCurve: AppMotion.exit,
              child: safety.needsAttention
                  ? Column(
                      key: const ValueKey('alert-on'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Your alert is showing to everyone in the ride.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: "I'm OK, clear my alert",
                          icon: Icons.check_rounded,
                          isLoading: safety.sending == RideSignalKind.ok,
                          onPressed: safety.sending == null
                              ? controller.clearAttention
                              : null,
                        ),
                      ],
                    )
                  : SlideToConfirm(
                      key: const ValueKey('alert-off'),
                      label: 'Slide to alert the group',
                      icon: Icons.priority_high_rounded,
                      isBusy: safety.sending == RideSignalKind.attention,
                      onConfirmed: () =>
                          controller.send(RideSignalKind.attention),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Alerts reach the riders in this ride only. In an emergency, '
              'call your local emergency number.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sentMessage(RideSignalKind? kind) => switch (kind) {
    RideSignalKind.attention => 'Alert sent to the group.',
    RideSignalKind.regroup => 'Asked the group to regroup.',
    RideSignalKind.followMe => 'Told the group to follow you.',
    RideSignalKind.ok || null => 'Checked in with the group.',
  };

  Future<void> _shareStatus(BuildContext context, WidgetRef ref) async {
    final map = ref.read(rideMapControllerProvider(code));
    final room = ref.read(roomStreamProvider(code)).value;
    RouteStatus? route;
    if (guided) {
      final guidance = ref.read(guidanceControllerProvider(code));
      final snapshot = guidance.snapshot;
      final guide = guidance.guide;
      if (snapshot != null && guide != null) {
        route = RouteStatus(
          destinationName: guide.route.destinationName,
          remainingMeters: snapshot.remainingMeters,
          fraction: snapshot.fraction,
          remainingTime: snapshot.remainingTime,
          hasArrived: snapshot.hasArrived,
        );
      }
    }
    final now = DateTime.now();
    final text = RideStatusReport.compose(
      rideName: room?.name ?? 'Group ride',
      now: now,
      at: map.myFix?.point,
      speedMps: map.myFix?.speedMps,
      distanceMeters: map.myStats?.distanceMeters ?? 0,
      elapsed: map.myStats?.elapsed(now.millisecondsSinceEpoch) ?? Duration.zero,
      route: route,
    );
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'My RideSync ride status',
        sharePositionOrigin: origin,
      ),
    );
  }
}

class _RideStateRow extends StatelessWidget {
  const _RideStateRow({
    required this.isConnected,
    required this.gps,
    required this.online,
    required this.total,
  });

  final bool isConnected;
  final GpsStatus gps;
  final int online;
  final int total;

  @override
  Widget build(BuildContext context) {
    final (gpsLabel, gpsColor) = switch (gps) {
      GpsStatus.locked => ('GPS locked', AppColors.success),
      GpsStatus.weak => ('GPS weak', AppColors.textSecondary),
      GpsStatus.searching => ('Searching GPS', AppColors.textTertiary),
    };
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _StatePill(
          label: isConnected ? 'Sharing live' : 'Reconnecting',
          color: isConnected ? AppColors.success : AppColors.error,
        ),
        _StatePill(label: gpsLabel, color: gpsColor),
        _StatePill(
          label: '$online of $total online',
          color: online == total ? AppColors.success : AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.pill,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedOpacity(
            duration: AppMotion.normal,
            opacity: enabled || busy ? 1 : 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: busy ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: AppIconSize.large,
                    child: busy
                        ? const RideLoader(size: RideLoader.inline)
                        : Icon(
                            icon,
                            size: AppIconSize.large,
                            color: AppColors.primary,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
