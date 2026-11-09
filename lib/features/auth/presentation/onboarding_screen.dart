import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/glow_button.dart';
import 'providers/auth_providers.dart';

/// First-run screen: capture an optional display name, then sign in
/// anonymously.
///
/// On success the auth state changes and the router's redirect moves the user
/// to home, so this screen does not navigate imperatively. Failures surface
/// inline without leaving the screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final repository = ref.read(authRepositoryProvider);
    final result = await repository.signInAnonymously(
      displayName: _nameController.text,
    );

    if (!mounted) return;

    switch (result) {
      case Success<Object?>():
        // The router's auth-aware redirect handles navigation to home once the
        // auth stream emits the new user. No imperative navigation here.
        break;
      case Failed(:final failure):
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const BrandMark(),
              const SizedBox(height: AppSpacing.xxl),
              Text('RideSync', style: theme.textTheme.displayMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Never lose your ride.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                'What should your group call you?',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: 40,
                onSubmitted: (_) => _continue(),
                decoration: const InputDecoration(
                  hintText: 'Display name (optional)',
                  counterText: '',
                ),
              ),
              const Spacer(),
              GlowButton(
                label: 'Start',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _continue,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
