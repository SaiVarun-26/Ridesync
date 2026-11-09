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
