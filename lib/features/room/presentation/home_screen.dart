import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/glow_button.dart';

/// Landing screen offering the two entry points: create a ride or join one.
///
/// Milestone 1 renders the layout and navigation. Create/join logic lands in
/// Milestone 3.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('RideSync', style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Start a ride or join your group.',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              GlowButton(
                label: 'Create Ride',
                icon: Icons.add,
                onPressed: () => context.push(AppRoutes.create),
              ),
              const SizedBox(height: AppSpacing.md),
              GlowButton(
                label: 'Join Ride',
                icon: Icons.group_add,
                variant: GlowButtonVariant.secondary,
                accent: AppColors.neonGreen,
                onPressed: () => context.push(AppRoutes.join),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
