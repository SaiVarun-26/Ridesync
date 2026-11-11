import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/display_name_rules.dart';

/// The required display name input.
///
/// Built to be impossible to miss: a large field with a strong outline that
/// glows while it is empty, turns bright when focused, warns when the name is
/// not acceptable and confirms when it is. A message under it always says what
/// is needed.
class DisplayNameField extends StatefulWidget {
  const DisplayNameField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  State<DisplayNameField> createState() => _DisplayNameFieldState();
}

class _DisplayNameFieldState extends State<DisplayNameField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode();

  /// Drives the soft glow that invites the rider to type while it is empty.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool get _isEmpty => widget.controller.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
    _syncPulse();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onChanged() {
    _syncPulse();
    setState(() {});
  }

  /// Pulses only while there is nothing typed, so a filled-in screen is still.
  void _syncPulse() {
    if (_isEmpty && !_focus.hasFocus) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;
    final error = DisplayNameRules.validate(text);
    // Nothing typed at all. Spaces only is not empty: it is wrong, and says so.
    final empty = text.isEmpty;
    final focused = _focus.hasFocus;

    final Color accent;
    if (empty) {
      accent = focused ? AppColors.route : AppColors.neonGreen;
    } else if (error != null) {
      accent = AppColors.warning;
    } else {
      accent = AppColors.neonGreen;
    }

    final message = empty
        ? 'Required. This is how your group will see you.'
        : (error ?? 'Looks good.');
    final messageColor = empty
        ? AppColors.textSecondary
        : (error != null ? AppColors.warning : AppColors.neonGreen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_pulse.value);
            final glow = empty && !focused ? 0.12 + 0.2 * t : (focused ? 0.28 : 0.2);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: accent.withValues(alpha: focused || !empty ? 1 : 0.55 + 0.3 * t),
                  width: focused ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: glow),
                    blurRadius: focused ? 26 : 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(DisplayNameRules.maxLength),
                  ],
                  onSubmitted: (_) {
                    if (DisplayNameRules.isValid(widget.controller.text)) {
                      widget.onSubmitted();
                    }
                  },
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
                  cursorColor: accent,
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    hintStyle: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      color: AppColors.textTertiary,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xl,
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: !empty && error == null
                    ? const Padding(
                        key: ValueKey('valid'),
                        padding: EdgeInsets.only(right: AppSpacing.lg),
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.neonGreen,
                        ),
                      )
                    : const SizedBox(key: ValueKey('none'), width: 0),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Padding(
            key: ValueKey(message),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: messageColor),
            ),
          ),
        ),
      ],
    );
  }
}
