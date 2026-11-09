import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/glow_button.dart';
import 'providers/room_providers.dart';

/// Create-ride screen: names a ride and creates a room with a unique code.
///
/// On success the user is taken to the lobby for the generated code. Room
/// state is live data and is created in the Realtime Database by the
/// repository; this screen holds no Firebase logic.
class CreateRideScreen extends ConsumerStatefulWidget {
  const CreateRideScreen({super.key});

  @override
  ConsumerState<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends ConsumerState<CreateRideScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_isSubmitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give your ride a name.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final result =
        await ref.read(roomRepositoryProvider).createRoom(name: name);

    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        context.go(AppRoutes.lobbyPath(value.code));
      case Failed(:final failure):
        setState(() => _isSubmitting = false);
        _showError(failure.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Ride')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Name your ride', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: 40,
                onSubmitted: (_) => _create(),
                decoration: const InputDecoration(
                  hintText: 'Sunday Run',
                  counterText: '',
                ),
              ),
              const Spacer(),
              GlowButton(
                label: 'Create',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _create,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
