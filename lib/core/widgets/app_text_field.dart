import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_icon.dart';

/// The app's text input: a solid card-coloured field with a floating label.
///
/// The [label] rests inside the field like a placeholder and floats up to
/// the top edge, shrinking, as soon as the field is focused or has text. The
/// border eases to the RideSync purple while focused, to the error colour
/// when something is wrong (with a short shake and a haptic), and to a quiet
/// purple with a check once the input is good to go ([isValid]).
///
/// Every motion takes its timing from `AppMotion`, and the field never
/// changes height as it animates, so typing never shifts the layout.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.enabled = true,
    this.errorText,
    this.helperText,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.done,
    this.inputFormatters,
    this.maxLength,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.textStyle,
    this.autofocus = false,
    this.isValid = false,
  });

  final TextEditingController controller;

  /// What the field is for. Floats above the text once the field is in use,
  /// and is what screen readers announce.
  final String? label;

  /// An example of the input, shown once the label has floated out of the
  /// way (or always, when there is no label).
  final String? hintText;

  final bool enabled;

  /// Something is wrong with the input; shown under the field in the error
  /// colour, and the border turns to match.
  final String? errorText;

  /// Quiet guidance under the field when there is no error.
  final String? helperText;

  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final TextStyle? textStyle;
  final bool autofocus;

  /// The input is complete and good to go: a check springs in at the right
  /// and, when the field is not focused, the border settles to a soft purple.
  final bool isValid;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
    with TickerProviderStateMixin {
  final FocusNode _focus = FocusNode();

  /// Drives the sideways shake when a new error appears.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: AppMotion.shake,
  );

  /// 0 with the label resting inside the field, 1 floated to the top.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: _shouldFloat ? 1 : 0,
  );

  /// Padding inside the field, and on the side the success check sits.
  static const double _inset = AppSpacing.lg + 2;
  static const double _checkInset = _inset + AppIconSize.medium + AppSpacing.sm;

  /// Extra room above the text for the floated label.
  static const double _labelSpace = FloatingLabel.space;

  bool get _hasLabel => widget.label != null;

  bool get _shouldFloat => _focus.hasFocus || widget.controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onChanged);
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    final error = widget.errorText;
    if (error != null && error != oldWidget.errorText) {
      HapticFeedback.lightImpact();
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _shake.dispose();
    _float.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final target = _shouldFloat ? 1.0 : 0.0;
    if (_float.value != target) {
      _float.animateTo(target, curve: AppMotion.curve);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;
    final valid = widget.isValid && !hasError;
    final borderColor = hasError
        ? AppColors.error
        : focused
        ? AppColors.primary
        : valid
        ? AppColors.success.withValues(alpha: 0.55)
        : AppColors.border;
    final message = widget.errorText ?? widget.helperText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(AppMotion.shakeOffset(_shake.value), 0),
            child: child,
          ),
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            // The border is drawn over the field rather than around it, so
            // thickening it on focus never nudges the text.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: borderColor,
                width: focused || hasError ? 1.6 : 1,
              ),
            ),
            decoration: BoxDecoration(
              color: focused ? AppColors.surfaceRaised : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              // A faint, wide lift in the field's colour while typing.
              boxShadow: [
                BoxShadow(
                  color: (hasError ? AppColors.error : AppColors.primary)
                      .withValues(alpha: focused ? 0.14 : 0),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            // One semantics node: the label is read as the field's name.
            child: MergeSemantics(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  _field(theme),
                  if (_hasLabel) _label(theme, focused, hasError),
                  _check(valid),
                ],
              ),
            ),
          ),
        ),
        _message(theme, message, hasError),
      ],
    );
  }

  Widget _field(ThemeData theme) {
    final style = widget.textStyle ?? theme.textTheme.titleMedium;
    final centred = widget.textAlign == TextAlign.center;
    // With a label, the example only shows once the label is out of the way.
    final showHint = !_hasLabel || _shouldFloat;
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      onSubmitted: widget.onSubmitted,
      textAlign: widget.textAlign,
      style: style,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: showHint ? widget.hintText : null,
        hintStyle: style?.copyWith(color: AppColors.textTertiary),
        counterText: '',
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        // Room on the right for the check; centred text reserves the same on
        // the left so it stays centred. A label adds room on top.
        contentPadding: EdgeInsets.fromLTRB(
          centred ? _checkInset : _inset,
          _hasLabel ? _inset + _labelSpace : _inset,
          _checkInset,
          _hasLabel ? _inset - AppSpacing.xs : _inset,
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, bool focused, bool hasError) {
    final centred = widget.textAlign == TextAlign.center;
    return FloatingLabel(
      text: widget.label!,
      progress: _float,
      floated: _shouldFloat,
      centred: centred,
      color: hasError
          ? AppColors.error
          : focused
          ? AppColors.primary
          : AppColors.textSecondary,
      textArea: EdgeInsets.fromLTRB(
        centred ? _checkInset : _inset,
        _inset + _labelSpace,
        _checkInset,
        _inset - AppSpacing.xs,
      ),
    );
  }

  /// Springs in over the field's right edge, so it appears without moving the
  /// text.
  Widget _check(bool valid) {
    return Padding(
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
              size: AppIconSize.medium,
              color: AppColors.success,
              semanticLabel: 'Looks good',
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(ThemeData theme, String? message, bool hasError) {
    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.exit,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(message),
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  left: AppSpacing.xs,
                ),
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasError ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ),
      ),
    );
  }
}

/// A text field's label that rests on the text line like a placeholder and
/// floats to the field's top edge, shrinking, once the field is in use.
///
/// Lay it over the field in a `Stack`. [textArea] is the field's content
/// padding, so the resting label sits exactly where the text will be; the
/// field should reserve [space] above its text for the floated label.
/// [progress] runs from 0 (resting) to 1 (floated).
class FloatingLabel extends StatelessWidget {
  const FloatingLabel({
    super.key,
    required this.text,
    required this.progress,
    required this.floated,
    required this.color,
    required this.textArea,
    this.centred = false,
    this.style,
  });

  final String text;
  final Animation<double> progress;

  /// Whether the label is (heading to be) floated; picks its colour and
  /// weight.
  final bool floated;

  /// The floated label's colour; at rest it is placeholder grey.
  final Color color;

  final EdgeInsets textArea;
  final bool centred;

  /// The resting style; defaults to `titleMedium`.
  final TextStyle? style;

  /// Room a field reserves above its text for the floated label.
  static const double space = AppSpacing.md;

  /// Distance of the floated label from the field's top edge.
  static const double floatedTop = AppSpacing.sm + 2;

  /// The floated label's size relative to its resting size.
  static const double floatedScale = 0.75;

  @override
  Widget build(BuildContext context) {
    final x = centred ? 0.0 : -1.0;
    final base =
        style ?? Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, child) {
            final t = progress.value;
            return Padding(
              padding: textArea.copyWith(
                top: lerpDouble(textArea.top, floatedTop, t),
              ),
              child: Align(
                alignment: Alignment(x, lerpDouble(0, -1, t)!),
                child: Transform.scale(
                  scale: lerpDouble(1, floatedScale, t),
                  alignment: Alignment(x, -1),
                  child: child,
                ),
              ),
            );
          },
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            style: base.copyWith(
              color: floated ? color : AppColors.textTertiary,
              fontWeight: floated ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
