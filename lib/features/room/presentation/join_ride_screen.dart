import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/feedback/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/ride_loader.dart';
import '../data/room_code_generator.dart';
import '../domain/room_preview.dart';
import 'providers/room_providers.dart';
import 'room_flow.dart';
import 'widgets/room_open_pill.dart';

/// Join-ride screen: validates a 6-character code, shows what the rider is
/// about to join, and joins the room.
///
/// Once the code is complete the room is looked at (name, riders, whether it
/// is open or already under way), so the rider knows before pressing Join. A
/// ride can be joined at any point until the host ends it, and a rider joining
/// mid-ride lands straight on the live map. A ride that has ended cannot be
/// joined, and says so.
class JoinRideScreen extends ConsumerStatefulWidget {
  const JoinRideScreen({super.key});

  @override
  ConsumerState<JoinRideScreen> createState() => _JoinRideScreenState();
}

class _JoinRideScreenState extends ConsumerState<JoinRideScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;

  /// The join went through; the button shows a check until the room opens.
  bool _joined = false;

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

    final result = await ref.read(roomRepositoryProvider).joinRoom(code: _code);

    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        // A new rider lands in the lobby; a rider coming back lands wherever
        // the room has got to. The button shows a check for a moment first.
        AppHaptics.success();
        setState(() => _joined = true);
        await Future<void>.delayed(AppMotion.successHold);
        if (!mounted) return;
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
    final preview = _hasFullCode ? ref.watch(roomPreviewProvider(_code)) : null;
    final blocked = preview?.value != null && !preview!.value!.canJoin;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Ride')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(
                        child: Text(
                          'Enter room code',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FadeSlideIn(
                        delay: AppMotion.stagger,
                        child: AppTextField(
                          controller: _codeController,
                          enabled: !_isSubmitting,
                          label: 'Room code',
                          hintText: '______',
                          textCapitalization: TextCapitalization.characters,
                          maxLength: RoomCodeGenerator.codeLength,
                          onSubmitted: (_) => _join(),
                          inputFormatters: [
                            UpperCaseTextFormatter(),
                            FilteringTextInputFormatter.allow(
                              RegExp('[A-Za-z0-9]'),
                            ),
                          ],
                          textStyle: theme.textTheme.headlineMedium?.copyWith(
                            letterSpacing: 8,
                          ),
                          textAlign: TextAlign.center,
                          errorText: _error,
                          // A full code for a ride that can be joined.
                          isValid: preview?.value?.canJoin ?? false,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AnimatedSize(
                        duration: AppMotion.normal,
                        curve: AppMotion.curve,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: AppMotion.normal,
                          child: _PreviewView(
                            key: ValueKey(
                              preview?.value?.code ?? preview.hashCode,
                            ),
                            preview: preview,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Available once the whole code is in, and the ride can be
              // joined.
              AppButton(
                label: 'Join',
                isLoading: _isSubmitting,
                isSuccess: _joined,
                onPressed: !_hasFullCode || blocked ? null : _join,
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
        child: Center(child: RideLoader()),
      ),
      error: (error, _) => _Message(
        text: error is Failure ? error.message : 'Could not look up that ride.',
        color: AppColors.error,
        icon: Icons.error_outline_rounded,
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
        border: Border.all(color: AppColors.border),
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
          RoomOpenPill(
            isOpen: room.isOpen,
            isUnderway: room.isUnderway,
            riders: room.riderCount,
          ),
          if (!room.canJoin) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'The host has ended this ride, so it is not taking new riders. '
              'Ask them to create a new one.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (room.isUnderway && !room.isMember) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'This ride is already under way. You will join it live and show '
              'up on everyoneâ€™s map straight away.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (room.isMember && room.isUnderway) ...[
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
  const _Message({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSize.medium, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
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
