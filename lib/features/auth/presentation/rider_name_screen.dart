import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../domain/display_name_rules.dart';
import 'providers/auth_providers.dart';
import 'widgets/display_name_field.dart';

/// Shown once, right after the first Google sign-in: the rider chooses the
/// name RideSync uses for them everywhere (group rides, leaderboard,
/// history, share cards). The Google account's name is deliberately not
/// offered.
///
/// Saving updates the profile on the device at once (and in the cloud when
/// online); the router then moves on to Home by itself.
class RiderNameScreen extends ConsumerStatefulWidget {
  const RiderNameScreen({super.key});

  @override
  ConsumerState<RiderNameScreen> createState() => _RiderNameScreenState();
}

class _RiderNameScreenState extends ConsumerState<RiderNameScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isSubmitting || !DisplayNameRules.isValid(_nameController.text)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final result = await ref
        .read(authRepositoryProvider)
        .updateRiderName(DisplayNameRules.clean(_nameController.text));
    if (!mounted) return;
    if (result case Failed(:final failure)) {
      setState(() => _isSubmitting = false);
      showAppSnackBar(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const FadeSlideIn(child: BrandMark()),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: AppMotion.stagger,
                  child: Text(
                    'What should we call you?',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: AppMotion.stagger * 2,
                  child: Text(
                    'Your rider name shows on group rides, the leaderboard '
                    'and your ride cards. You can change it any time.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FadeSlideIn(
                  delay: AppMotion.stagger * 3,
                  child: DisplayNameField(
                    controller: _nameController,
                    enabled: !_isSubmitting,
                    onSubmitted: _continue,
                  ),
                ),
                const Spacer(),
                ListenableBuilder(
                  listenable: _nameController,
                  builder: (context, _) => AppButton(
                    label: 'Continue',
                    isLoading: _isSubmitting,
                    onPressed: DisplayNameRules.isValid(_nameController.text)
                        ? _continue
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
