import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/glow_button.dart';
import '../data/room_code_generator.dart';
import 'providers/room_providers.dart';

/// Join-ride screen: validates a 6-character code and joins the room.
///
/// On success the user is taken to the room's lobby. The code field is
/// uppercased and restricted to the room-code alphabet to reduce entry errors.
class JoinRideScreen extends ConsumerStatefulWidget {
  const JoinRideScreen({super.key});

  @override
  ConsumerState<JoinRideScreen> createState() => _JoinRideScreenState();
}

class _JoinRideScreenState extends ConsumerState<JoinRideScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_isSubmitting) return;
    final code = _codeController.text.trim().toUpperCase();
    if (!RoomCodeGenerator.isValid(code)) {
      _showError('Enter the full 6-character code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final result =
        await ref.read(roomRepositoryProvider).joinRoom(code: code);

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
      appBar: AppBar(title: const Text('Join Ride')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enter room code', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _codeController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.characters,
                maxLength: RoomCodeGenerator.codeLength,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _join(),
                inputFormatters: [
                  UpperCaseTextFormatter(),
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                ],
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '______',
                  counterText: '',
                ),
              ),
              const Spacer(),
              GlowButton(
                label: 'Join',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _join,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Forces text input to uppercase so room codes are entered consistently.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
