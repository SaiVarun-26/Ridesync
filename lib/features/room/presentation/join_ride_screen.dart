import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/glow_button.dart';
import '../data/room_code_generator.dart';
import '../domain/room_preview.dart';
import 'providers/room_providers.dart';
import 'room_flow.dart';
import 'widgets/room_open_pill.dart';

/// Join-ride screen: validates a 6-character code, shows what the rider is
/// about to join, and joins the room.
///
/// Once the code is complete the room is looked at (name, riders, open or
/// started), so the rider knows before pressing Join. A room that has already
/// started cannot be joined, and says so. On success the rider is taken to the
/// room's current stage (the lobby for a new rider).
class JoinRideScreen extends ConsumerStatefulWidget {
  const JoinRideScreen({super.key});

  @override
  ConsumerState<JoinRideScreen> createState() => _JoinRideScreenState();
}

class _JoinRideScreenState extends ConsumerState<JoinRideScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;

  /// Why the last join attempt failed, shown under the code.
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController
      ..removeListener(_onCodeChanged)
      ..dispose();
    super.dispose();
  }

  String get _code => _codeController.text.trim().toUpperCase();

  bool get _hasFullCode => RoomCodeGenerator.isValid(_code);

  void _onCodeChanged() {
    setState(() => _error = null);
  }

  Future<void> _join() async {
    if (_isSubmitting) return;
    if (!_hasFullCode) {
      setState(() => _error = 'Enter the full 6-character code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result =
        await ref.read(roomRepositoryProvider).joinRoom(code: _code);

    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        // A new rider lands in the lobby; a rider coming back lands wherever
        // the room has got to.
        context.go(roomFlowPath(value));
      case Failed(:final failure):
        setState(() {
          _isSubmitting = false;
          _error = failure.message;
        });
        // The room's state may have changed since it was looked at.
        ref.invalidate(roomPreviewProvider(_code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview =
        _hasFullCode ? ref.watch(roomPreviewProvider(_code)) : null;
    final blocked = preview?.value != null && !preview!.value!.canJoin;

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
              const SizedBox(height: AppSpacing.lg),
              AnimatedSize(
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: AppMotion.normal,
                  child: _error != null
                      ? _Message(
                          key: ValueKey(_error),
                          text: _error!,
                          color: AppColors.warning,
                          icon: Icons.error_outline,
                        )
                      : _PreviewView(
                          key: ValueKey(preview?.value?.code ?? preview.hashCode),
                          preview: preview,
                        ),
                ),
              ),
              const Spacer(),
              GlowButton(
                label: 'Join',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting || blocked ? null : _join,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({super.key, required this.preview});

  final AsyncValue<RoomPreview>? preview;

  @override
  Widget build(BuildContext context) {
    final state = preview;
    if (state == null) return const SizedBox(width: double.infinity);
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, _) => _Message(
        text: error is Failure ? error.message : 'Could not look up that ride.',
        color: AppColors.warning,
        icon: Icons.error_outline,
      ),
      data: (room) => _RoomCard(room: room),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final RoomPreview room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room.name,
            style: theme.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          RoomOpenPill(isOpen: room.isOpen, riders: room.riderCount),
          if (!room.canJoin) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'The host has already started this ride, so it is not taking '
              'new riders. Ask them to create a new one.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (room.isMember && !room.isOpen) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'You are already in this ride. Join to get back in.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
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
