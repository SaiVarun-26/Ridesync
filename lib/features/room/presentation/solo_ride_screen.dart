import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/ride_loader.dart';
import '../../../core/widgets/section_label.dart';
import '../../ride/presentation/widgets/ride_mode_card.dart';
import '../domain/ride_mode.dart';
import 'ride_launcher.dart';

/// Where a solo ride begins: a choice between a guided ride and free roam.
///
/// Both start the existing flows: the choice creates a one-rider ride and
/// opens its initialization, after which guided rides plan a route and free
/// roam goes straight to the map. Nothing about the rides themselves lives
/// here.
class SoloRideScreen extends ConsumerStatefulWidget {
  const SoloRideScreen({super.key});

  @override
  ConsumerState<SoloRideScreen> createState() => _SoloRideScreenState();
}

class _SoloRideScreenState extends ConsumerState<SoloRideScreen> {
  /// The ride type being set up, while it is.
  RideMode? _starting;

  Future<void> _start(RideMode mode) async {
    if (_starting != null) return;
    setState(() => _starting = mode);
    final result = await ref.read(rideLauncherProvider).startSoloRide(mode);
    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        // The room is now initializing; every later stage follows the room.
        context.go(AppRoutes.initializingPath(value.code));
      case Failed(:final failure):
        setState(() => _starting = null);
        showAppSnackBar(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _starting != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Solo Ride')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const FadeSlideIn(child: SectionLabel('RIDE BY YOURSELF')),
            const SizedBox(height: AppSpacing.sm),
            FadeSlideIn(
              delay: AppMotion.stagger,
              child: Text(
                'How do you want to ride?',
                style: theme.textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FadeSlideIn(
              delay: AppMotion.stagger * 2,
              child: RideModeCard(
                index: '01',
                title: 'Guided Ride',
                subtitle: 'Navigate to a destination with turn-by-turn guidance.',
                points: const [],
                selected: _starting == RideMode.guided,
                onTap: busy ? null : () => _start(RideMode.guided),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: AppMotion.stagger * 3,
              child: RideModeCard(
                index: '02',
                title: 'Free Roam',
                subtitle: 'Ride anywhere without a destination.',
                points: const [],
                selected: _starting == RideMode.free,
                onTap: busy ? null : () => _start(RideMode.free),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              alignment: Alignment.topCenter,
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxl),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const RideLoader(size: RideLoader.inline),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Setting up your ride…',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
