import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'brand_mark.dart';

/// The RideSync mark with its name beside it.
///
/// "Ride" in white, "Sync" in light violet, set in the app's display face with
/// room to breathe. Sized by [height], the height of the mark.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.height = BrandMark.header,
    this.breathing = false,
  });

  final double height;
  final bool breathing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: height, breathing: breathing),
        SizedBox(width: height * 0.38 + AppSpacing.xs),
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'Ride'),
              TextSpan(
                text: 'Sync',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: height * 0.82,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1,
          ),
        ),
      ],
    );
  }
}
