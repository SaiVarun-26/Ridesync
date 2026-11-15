import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/section_label.dart';
import '../../domain/live/ride_format.dart';

/// The moment a ride is over.
///
/// The map behind it has already eased out to show the whole ride. A dim veil
/// settles over it, a ring sweeps closed and a check draws itself, a single
/// burst of small pieces rises and falls, "Ride complete" arrives, and the
/// rider's own numbers climb into place one after another. Then the results
/// open (or sooner, when the rider asks).
///
/// Everything is one flat colour: no gradients, no glow. A single controller
/// drives all of it, and it is painted in two small layers.
class RideCompleteOverlay extends StatefulWidget {
  const RideCompleteOverlay({
    super.key,
    required this.rideName,
    required this.distanceMeters,
    required this.duration,
    required this.averageSpeedMps,
    required this.accent,
    required this.onContinue,
    this.continueLabel = 'View results',
  });

  /// The label of the button that moves on.
  final String continueLabel;

  final String rideName;

  /// This rider's final figures.
  final double distanceMeters;
  final Duration duration;
  final double averageSpeedMps;

  /// The rider's own colour, used for part of the burst.
  final Color accent;

  /// Opens the results now.
  final VoidCallback onContinue;

  @override
  State<RideCompleteOverlay> createState() => _RideCompleteOverlayState();
}

class _RideCompleteOverlayState extends State<RideCompleteOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 3400);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  )..forward();

  Timer? _haptic;

  // Where each part of the sequence sits on the controller's 0 to 1.
  static const Interval _veil = Interval(0, 0.16, curve: AppMotion.curve);
  static const Interval _ring = Interval(0.07, 0.27, curve: AppMotion.curve);
  static const Interval _check = Interval(0.2, 0.36, curve: AppMotion.curve);
  static const Interval _title = Interval(0.27, 0.42, curve: AppMotion.curve);
  static const Interval _burst = Interval(0.2, 1);
  static const Interval _button = Interval(0.62, 0.8, curve: AppMotion.curve);

  /// The three figures start one after another.
  static const List<Interval> _stats = [
    Interval(0.34, 0.58, curve: AppMotion.curve),
    Interval(0.4, 0.64, curve: AppMotion.curve),
    Interval(0.46, 0.7, curve: AppMotion.curve),
  ];

  @override
  void initState() {
    super.initState();
    // The success tap lands as the check completes.
    _haptic = Timer(
      Duration(milliseconds: (_total.inMilliseconds * 0.28).round()),
      AppHaptics.success,
    );
  }

  /// The rider asked the system for less motion: everything shows at once.
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) _controller.value = 1;
  }

  @override
  void dispose() {
    _haptic?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static double _at(Animation<double> a, Interval i) => i.transform(a.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = _reduce;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final veil = _at(_controller, _veil);
        final title = _at(_controller, _title);
        final button = _at(_controller, _button);
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.background.withValues(alpha: 0.74 * veil),
            ),
            if (!reduce)
              RepaintBoundary(
                child: CustomPaint(
                  painter: _BurstPainter(
                    progress: _burst.transform(_controller.value),
                    colors: [
                      widget.accent,
                      Colors.white,
                      AppColors.primary,
                      Color.lerp(widget.accent, Colors.white, 0.5)!,
                    ],
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    RepaintBoundary(
                      child: SizedBox.square(
                        dimension: _checkSize,
                        child: CustomPaint(
                          painter: _CheckPainter(
                            ring: _at(_controller, _ring),
                            check: _at(_controller, _check),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - title)),
                        child: Column(
                          children: [
                            Text(
                              'Ride Complete',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (widget.rideName.isNotEmpty)
                              Text(
                                widget.rideName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      children: [
                        _Figure(
                          label: 'DISTANCE',
                          t: _at(_controller, _stats[0]),
                          format: (t) =>
                              RideFormat.distance(widget.distanceMeters * t),
                        ),
                        _Figure(
                          label: 'TIME',
                          t: _at(_controller, _stats[1]),
                          format: (t) => RideFormat.duration(
                            Duration(
                              milliseconds:
                                  (widget.duration.inMilliseconds * t).round(),
                            ),
                          ),
                        ),
                        _Figure(
                          label: 'AVG SPEED',
                          t: _at(_controller, _stats[2]),
                          format: (t) =>
                              RideFormat.speed(widget.averageSpeedMps * t),
                        ),
                      ],
                    ),
                    const Spacer(flex: 4),
                    Opacity(
                      opacity: button,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - button)),
                        child: IgnorePointer(
                          ignoring: button < 0.6,
                          child: AppButton(
                            label: widget.continueLabel,
                            onPressed: widget.onContinue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static const double _checkSize = 112;
}

/// One of the three climbing figures.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.t, required this.format});

  final String label;

  /// 0 to 1: how far the figure has climbed.
  final double t;
  final String Function(double t) format;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(format(t), style: AppTypography.stat(fontSize: 26)),
              ),
              const SizedBox(height: AppSpacing.xs),
              SectionLabel(label),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ring sweeping closed around the check, and the check drawing itself.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.ring, required this.check});

  final double ring;
  final double check;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;

    // The disc fills softly as the ring closes, and settles with a touch of
    // overshoot as the check lands.
    final pop = 1 + 0.05 * math.sin(check * math.pi);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(pop)
      ..translate(-center.dx, -center.dy)
      ..drawCircle(
        center,
        radius,
        Paint()..color = AppColors.primary.withValues(alpha: 0.16 * ring),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.border.withValues(alpha: ring),
      )
      ..drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary,
      );

    if (check > 0) {
      final s = radius * 0.46;
      final path = Path()
        ..moveTo(center.dx - s, center.dy + s * 0.05)
        ..lineTo(center.dx - s * 0.2, center.dy + s * 0.75)
        ..lineTo(center.dx + s, center.dy - s * 0.65);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * check),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.textPrimary,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.ring != ring || old.check != check;
}

/// One burst of small flat pieces that rises from the check, arcs over and
/// falls away, fading as it goes. Forty-two pieces, each a circle or a thin
/// bar, in the rider's colour, white and the brand colour; deterministic, so
/// it looks the same every time and costs one pass over a short list.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.colors}) {
    _pieces ??= _makePieces();
  }

  /// 0 to 1 across the burst's lifetime.
  final double progress;
  final List<Color> colors;

  static List<_Piece>? _pieces;

  static const int _count = 42;
  static const double _lifeSeconds = 2.4;
  static const double _gravity = 780;

  static List<_Piece> _makePieces() {
    final random = math.Random(11);
    return [
      for (var i = 0; i < _count; i++)
        _Piece(
          // A fan opening upward, wider than tall.
          angle: -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 0.95,
          speed: 300 + random.nextDouble() * 360,
          spin: (random.nextDouble() - 0.5) * 9,
          size: 3.2 + random.nextDouble() * 3.4,
          bar: random.nextBool(),
          color: random.nextInt(4),
          delay: random.nextDouble() * 0.08,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final origin = Offset(size.width / 2, size.height * _originHeight);
    final seconds = progress * _lifeSeconds;
    final paint = Paint();
    for (final p in _pieces!) {
      final t = seconds - p.delay * _lifeSeconds;
      if (t <= 0) continue;
      final x = origin.dx + math.cos(p.angle) * p.speed * t;
      final y =
          origin.dy + math.sin(p.angle) * p.speed * t + 0.5 * _gravity * t * t;
      final life = t / (_lifeSeconds * (1 - p.delay));
      // Full strength early, gone by the end.
      final alpha = life < 0.55 ? 1.0 : (1 - (life - 0.55) / 0.45);
      if (alpha <= 0) continue;
      paint.color = colors[p.color].withValues(alpha: alpha);
      if (p.bar) {
        canvas
          ..save()
          ..translate(x, y)
          ..rotate(p.spin * t)
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size * 2.4,
                height: p.size * 0.8,
              ),
              const Radius.circular(1),
            ),
            paint,
          )
          ..restore();
      } else {
        canvas.drawCircle(Offset(x, y), p.size * 0.5, paint);
      }
    }
  }

  /// Where the burst starts, as a share of the height: from the check.
  static const double _originHeight = 0.36;

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.bar,
    required this.color,
    required this.delay,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final bool bar;
  final int color;
  final double delay;
}
