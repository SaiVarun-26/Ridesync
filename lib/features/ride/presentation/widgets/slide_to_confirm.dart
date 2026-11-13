import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/ride_loader.dart';

/// A power-off style slider: drag the thumb all the way across to confirm.
///
/// Nothing happens on a tap. Releasing early springs the thumb back; reaching
/// the end confirms with a firm haptic. While [isBusy] the thumb stays at the
/// end and shows progress; if the work then fails (busy turns off without the
/// widget being removed) the thumb springs back so the rider can try again.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.isBusy = false,
    this.accent = AppColors.error,
    this.icon = Icons.power_settings_new_rounded,
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool isBusy;

  /// Colour of the thumb and the trail it leaves.
  final Color accent;

  /// Icon on the thumb.
  final IconData icon;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  static const double _height = 64;
  static const double _thumbSize = 56;
  static const double _inset = (_height - _thumbSize) / 2;

  /// Fraction of the track at which the slide counts as complete.
  static const double _confirmAt = 0.98;

  /// The thumb ticks lightly as it passes each of these steps.
  static const int _hapticSteps = 4;

  static final SpringDescription _spring = AppMotion.settle;

  // Unbounded so the spring may overshoot slightly; the view clamps it.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
  );

  double _travel = 1;
  bool _dragging = false;
  bool _confirmed = false;
  int _lastStep = 0;

  @override
  void didUpdateWidget(SlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBusy && !widget.isBusy && _confirmed) {
      // The work finished without leaving this screen, so it failed: let the
      // rider slide again.
      _confirmed = false;
      _springBack(0);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  bool get _locked => _confirmed || widget.isBusy;

  void _onDragStart(DragStartDetails details) {
    if (_locked) return;
    _position.stop();
    _dragging = true;
    _lastStep = (_position.value.clamp(0.0, 1.0) * _hapticSteps).floor();
    HapticFeedback.selectionClick();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final next = (_position.value + details.delta.dx / _travel).clamp(0.0, 1.0);
    _position.value = next;

    final step = (next * _hapticSteps).floor();
    if (step != _lastStep) {
      _lastStep = step;
      HapticFeedback.selectionClick();
    }
    if (next >= _confirmAt) _confirm();
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    HapticFeedback.lightImpact();
    _springBack(details.velocity.pixelsPerSecond.dx / _travel);
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _springBack(0);
  }

  void _springBack(double velocity) {
    _position.animateWith(
      SpringSimulation(_spring, _position.value, 0, velocity),
    );
  }

  void _confirm() {
    if (_confirmed) return;
    _dragging = false;
    _confirmed = true;
    HapticFeedback.heavyImpact();
    _position.animateTo(1, duration: AppMotion.micro, curve: AppMotion.curve);
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _travel = math.max(1, constraints.maxWidth - _thumbSize - 2 * _inset);
        return Semantics(
          container: true,
          label: widget.label,
          // Screen-reader users cannot drag, so offer the action directly.
          customSemanticsActions: {
            CustomSemanticsAction(label: widget.label): () {
              if (!_locked) _confirm();
            },
          },
          child: SizedBox(
            height: _height,
            child: AnimatedBuilder(
              animation: _position,
              builder: (context, _) {
                final progress = _position.value.clamp(0.0, 1.0);
                final thumbLeft = _inset + progress * _travel;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(_height),
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    // The trail the thumb leaves behind.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: thumbLeft + _thumbSize + _inset,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(_height),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      left: _thumbSize + _inset,
                      child: Center(
                        child: Opacity(
                          opacity: (1 - progress * 1.6).clamp(0.0, 1.0),
                          child: Text(
                            widget.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: thumbLeft,
                      top: _inset,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: _onDragStart,
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        onHorizontalDragCancel: _onDragCancel,
                        child: _Thumb(
                          accent: widget.accent,
                          icon: widget.icon,
                          isBusy: widget.isBusy,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.accent,
    required this.icon,
    required this.isBusy,
  });

  final Color accent;
  final IconData icon;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _SlideToConfirmState._thumbSize,
      height: _SlideToConfirmState._thumbSize,
      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
      child: Center(
        child: isBusy
            ? const RideLoader(size: RideLoader.inline, color: Colors.white)
            : Icon(icon, color: Colors.white, size: AppIconSize.large),
      ),
    );
  }
}
