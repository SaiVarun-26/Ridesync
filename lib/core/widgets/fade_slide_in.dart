import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Fades and lifts its child in once, the first time it is built.
///
/// [delay] staggers several entrances (e.g. a list of cards). Give each
/// instance a stable key when it sits in a changing list, so only new items
/// animate.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// Time before this child starts animating in.
  final Duration delay;

  /// Vertical distance the child rises while fading in.
  static const double _offsetY = 8;

  @override
  Widget build(BuildContext context) {
    final total = delay + AppMotion.slow;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: AppMotion.curve),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * _offsetY),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Fades and grows its child in once, from [AppMotion.enterScale], coming out
/// of a light blur: the app's entrance for things that appear on their own in
/// the middle of a screen (the splash, a full-screen loader).
class FadeScaleIn extends StatelessWidget {
  const FadeScaleIn({
    super.key,
    required this.child,
    this.duration = AppMotion.entrance,
    this.blur = true,
  });

  final Widget child;
  final Duration duration;

  /// Whether the child also comes into focus from a light blur.
  final bool blur;

  static const double _maxBlur = 6;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: AppMotion.curve,
      builder: (context, t, child) {
        Widget content = Opacity(
          opacity: t,
          child: Transform.scale(
            scale: AppMotion.enterScale + (1 - AppMotion.enterScale) * t,
            child: child,
          ),
        );
        final sigma = (1 - t) * _maxBlur;
        // The filter is dropped once in focus, so a settled child costs
        // nothing extra to draw.
        if (blur && sigma > 0.05) {
          content = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: content,
          );
        }
        return content;
      },
      child: child,
    );
  }
}
