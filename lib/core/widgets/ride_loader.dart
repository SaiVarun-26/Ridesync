import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'fade_slide_in.dart';

/// RideSync's loading animation: a route being drawn.
///
/// A short S-shaped road sits faintly on the screen. A line is drawn along it
/// from start to finish with a rider at its head, then the tail catches up and
/// clears it, and it begins again. One solid colour, no glow, and it costs one
/// small path per frame.
///
/// Use it everywhere something is in progress, in place of a stock spinner.
class RideLoader extends StatefulWidget {
  const RideLoader({
    super.key,
    this.size = defaultSize,
    this.color = AppColors.primary,
  });

  /// Inside a button or a control.
  static const double inline = 22;

  /// A section or list that is loading.
  static const double defaultSize = 28;

  /// A whole screen that is loading.
  static const double hero = 40;

  /// Width and height of the animation.
  final double size;

  final Color color;

  @override
  State<RideLoader> createState() => _RideLoaderState();
}

class _RideLoaderState extends State<RideLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();

  /// One draw-and-clear of the route.
  static const Duration _cycle = Duration(milliseconds: 1500);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _LoaderPainter(progress: _controller, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  /// The line is drawn over this share of each cycle; the rest is the tail
  /// catching up.
  static const double _drawShare = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final road = Path()
      ..moveTo(s * 0.12, s * 0.82)
      ..cubicTo(s * 0.12, s * 0.10, s * 0.88, s * 0.90, s * 0.88, s * 0.18);
    final stroke = (s * 0.11).clamp(1.8, 4.0);

    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.border,
    );

    final metric = road.computeMetrics().first;
    final t = progress.value;
    final head = AppMotion.move.transform((t / _drawShare).clamp(0.0, 1.0));
    final tail = AppMotion.move.transform(
      ((t - _drawShare) / (1 - _drawShare)).clamp(0.0, 1.0),
    );
    final from = metric.length * tail;
    final to = metric.length * head;
    if (to - from > 0.5) {
      canvas.drawPath(
        metric.extractPath(from, to),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }

    // The rider at the head of the line, while there is a line.
    if (tail < 0.999) {
      final at =
          metric.getTangentForOffset(to) ?? metric.getTangentForOffset(0);
      if (at != null) {
        canvas
          ..drawCircle(
            at.position,
            stroke * 1.25,
            Paint()..color = AppColors.textPrimary,
          )
          ..drawCircle(at.position, stroke * 0.6, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_LoaderPainter old) => old.color != color;
}

/// A [RideLoader] with a line of text beneath, centred: the standard way to
/// show that a whole screen or section is loading.
class RideLoaderMessage extends StatelessWidget {
  const RideLoaderMessage({
    super.key,
    this.message,
    this.size = RideLoader.hero,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Arrives softly: fades in, settles from slightly small, and comes out of
    // a light blur, so a quick load never flashes a hard-edged spinner.
    return Center(
      child: FadeScaleIn(
        duration: AppMotion.slow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RideLoader(size: size),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
