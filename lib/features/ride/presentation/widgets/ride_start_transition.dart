import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/brand_mark.dart';

/// The three-second "Ride Starting" sequence played over the planning screen
/// before every rider moves to the ride.
///
/// Timeline (fractions of [duration]):
/// 1. 0.00–0.18 the screen fades to black
/// 2. 0.12–0.34 the RideSync mark appears
/// 3. 0.28–0.62 a glowing route line draws itself
/// 4. 0.46–0.62 "Ride Starting"
/// 5. 0.56–0.72 the destination name
/// 6. 0.70–0.88 a soft neon pulse
/// 7. 0.86–1.00 everything fades, handing off to the ride screen's fade-in
class RideStartTransition extends StatefulWidget {
  const RideStartTransition({
    super.key,
    required this.destinationName,
    required this.onFinished,
  });

  /// Exactly three seconds, start to hand-off.
  static const Duration duration = Duration(seconds: 3);

  final String destinationName;

  /// Called once the sequence has fully played.
  final VoidCallback onFinished;

  @override
  State<RideStartTransition> createState() => _RideStartTransitionState();
}

class _RideStartTransitionState extends State<RideStartTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: RideStartTransition.duration);

  late final Animation<double> _dim = _interval(0, 0.18);
  late final Animation<double> _mark = _interval(0.12, 0.34);
  late final Animation<double> _line = _interval(0.28, 0.62);
  late final Animation<double> _title = _interval(0.46, 0.62);
  late final Animation<double> _destination = _interval(0.56, 0.72);
  late final Animation<double> _pulse = _interval(0.70, 0.88);
  late final Animation<double> _exit = _interval(0.86, 1);

  /// Radius of the neon pulse behind the mark.
  static const double _pulseBlur = BrandMark.defaultSize;
  static const double _lineWidth = 180;
  static const double _lineHeight = 36;
  static const double _rise = 10;
  static const double _pulseScale = 0.12;
  static const double _pulseGlowAlpha = 0.45;

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward().whenComplete(widget.onFinished));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final visible = 1 - _exit.value;
        // The pulse rises then settles: 0 → 1 → 0 across its interval.
        final pulse = 1 - (2 * _pulse.value - 1).abs();
        return ColoredBox(
          color: AppColors.background.withValues(alpha: _dim.value),
          child: Opacity(
            opacity: visible,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Reveal(
                    progress: _mark.value,
                    rise: _rise,
                    child: Transform.scale(
                      scale: 1 + pulse * _pulseScale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.route.withValues(
                                alpha: pulse * _pulseGlowAlpha,
                              ),
                              blurRadius: _pulseBlur,
                            ),
                          ],
                        ),
                        child: const BrandMark(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: _lineWidth,
                    height: _lineHeight,
                    child: CustomPaint(
                      painter: _RouteLinePainter(progress: _line.value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Reveal(
                    progress: _title.value,
                    rise: _rise,
                    child: Text(
                      'Ride Starting',
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Reveal(
                    progress: _destination.value,
                    rise: _rise,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Text(
                        widget.destinationName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.route,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fades a child in while lifting it into place.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.progress,
    required this.rise,
    required this.child,
  });

  final double progress;
  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * rise),
        child: child,
      ),
    );
  }
}

/// A gently curving route line drawn from left to right as [progress] goes
/// from 0 to 1, in Electric Blue with a neon glow.
class _RouteLinePainter extends CustomPainter {
  const _RouteLinePainter({required this.progress});

  final double progress;

  static const double _strokeWidth = 3;
  static const double _glowWidth = 9;
  static const double _glowBlur = 6;
  static const double _glowAlpha = 0.55;
  static const double _headRadius = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final h = size.height;
    final w = size.width;
    final path = Path()
      ..moveTo(0, h * 0.7)
      ..cubicTo(w * 0.25, h * 0.1, w * 0.45, h * 0.95, w * 0.62, h * 0.45)
      ..cubicTo(w * 0.75, h * 0.1, w * 0.88, h * 0.35, w, h * 0.3);

    final metric = path.computeMetrics().first;
    final length = metric.length * progress;
    final drawn = metric.extractPath(0, length);

    canvas
      ..drawPath(
        drawn,
        Paint()
          ..color = AppColors.route.withValues(alpha: _glowAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _glowWidth
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur),
      )
      ..drawPath(
        drawn,
        Paint()
          ..color = AppColors.route
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round,
      );

    final head = metric.getTangentForOffset(length)?.position;
    if (head != null) {
      canvas.drawCircle(head, _headRadius, Paint()..color = AppColors.textPrimary);
    }
  }

  @override
  bool shouldRepaint(_RouteLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
