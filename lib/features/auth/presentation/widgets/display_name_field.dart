import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/display_name_rules.dart';

/// The required display name input.
///
/// Built to be impossible to miss: a large field with a strong outline that
/// breathes softly while it is empty, brightens when focused, turns to the
/// warning colour and shakes when the name is not acceptable, and confirms
/// with a check when it is. A message under it always says what is needed.
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
    with TickerProviderStateMixin {
  final FocusNode _focus = FocusNode();

  /// Drives the soft breathing that invites the rider to type while empty.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.breath,
  );

  /// Plays when the rider tries to continue with a name that is not valid.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: AppMotion.shake,
  );

  /// 0 with the label resting in the field, 1 floated to the top.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: _shouldFloat ? 1 : 0,
  );

  static const double _inset = AppSpacing.xl;

  bool get _isEmpty => widget.controller.text.trim().isEmpty;

  bool get _shouldFloat => _focus.hasFocus || widget.controller.text.isNotEmpty;

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
    _shake.dispose();
    _float.dispose();
    super.dispose();
  }

  void _onChanged() {
    _syncPulse();
    final target = _shouldFloat ? 1.0 : 0.0;
    if (_float.value != target) {
      _float.animateTo(target, curve: AppMotion.curve);
    }
    setState(() {});
  }

  /// Breathes only while there is nothing typed, so a filled-in screen is
  /// still.
  void _syncPulse() {
    if (_isEmpty && !_focus.hasFocus) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  void _submit() {
    if (DisplayNameRules.isValid(widget.controller.text)) {
      widget.onSubmitted();
      return;
    }
    HapticFeedback.lightImpact();
    _shake.forward(from: 0);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;
    final error = DisplayNameRules.validate(text);
    // Nothing typed at all. Spaces only is not empty: it is wrong, and says so.
    final empty = text.isEmpty;
    final focused = _focus.hasFocus;
    final valid = !empty && error == null;

    final accent = !empty && error != null
        ? AppColors.error
        : AppColors.primary;
    final textStyle = theme.textTheme.titleLarge?.copyWith(
      fontSize: AppTypeScale.title,
    );
    // Room on the right for the check and on top for the floated label.
    const textArea = EdgeInsets.fromLTRB(
      _inset,
      _inset + FloatingLabel.space,
      _inset + AppIconSize.large + AppSpacing.sm,
      _inset - AppSpacing.xs,
    );

    final message = empty
        ? 'Required. This is how your group will see you.'
        : (error ?? 'Looks good.');
    final messageColor = empty
        ? AppColors.textSecondary
        : (error != null ? AppColors.error : AppColors.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_pulse, _shake]),
          builder: (context, child) {
            final t = AppMotion.ambient.transform(_pulse.value);
            return Transform.translate(
              offset: Offset(AppMotion.shakeOffset(_shake.value), 0),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                // Drawn over the field, so the thicker focused border never
                // nudges the text.
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: accent.withValues(
                      alpha: focused || !empty ? 0.95 : 0.5 + 0.3 * t,
                    ),
                    width: focused ? 1.8 : 1.4,
                  ),
                ),
                child: child,
              ),
            );
          },
          // One semantics node: the label is read as the field's name.
          child: MergeSemantics(
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      DisplayNameRules.maxLength,
                    ),
                  ],
                  onSubmitted: (_) => _submit(),
                  style: textStyle,
                  cursorColor: accent,
                  decoration: InputDecoration(
                    // The example shows once the label has floated away.
                    hintText: _shouldFloat ? 'Enter your name' : null,
                    hintStyle: textStyle?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: textArea,
                  ),
                ),
                FloatingLabel(
                  text: 'Your name',
                  progress: _float,
                  floated: _shouldFloat,
                  color: focused ? accent : AppColors.textSecondary,
                  textArea: textArea,
                  style: textStyle,
                ),
                // Springs in over the right edge without moving the text.
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: valid ? 1 : 0,
                      duration: AppMotion.normal,
                      curve: AppMotion.curve,
                      child: AnimatedScale(
                        scale: valid ? 1 : 0.6,
                        duration: AppMotion.springDuration,
                        curve: AppMotion.spring,
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: AppIconSize.large,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: AppMotion.fast,
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.exit,
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
