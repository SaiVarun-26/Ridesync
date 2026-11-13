import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// A calm stand-in for a history card while the rides load. It breathes
/// gently, so loading reads as work in progress, not a broken layout.
class RideHistorySkeleton extends StatefulWidget {
  const RideHistorySkeleton({super.key});

  @override
  State<RideHistorySkeleton> createState() => _RideHistorySkeletonState();
}

class _RideHistorySkeletonState extends State<RideHistorySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.breath,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.ambient)),
      child: Container(
        height: 188,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _block(92, 92, 16),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _block(150, 16, 16),
                      const SizedBox(height: AppSpacing.sm),
                      _block(90, 11, 11),
                      const SizedBox(height: AppSpacing.md),
                      _block(70, 22, 22),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            _block(double.infinity, 40, AppRadius.md),
          ],
        ),
      ),
    );
  }

  Widget _block(double width, double height, double radius) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
