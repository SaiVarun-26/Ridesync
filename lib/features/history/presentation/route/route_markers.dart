import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Marks where a ride started: a bright dot with a play arrow.
class StartMarker extends StatelessWidget {
  const StartMarker({super.key, this.color = AppColors.neonGreen});

  final Color color;

  static const double size = 30;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        size: 18,
        color: AppColors.background,
      ),
    );
  }
}

/// Marks where a ride finished: a chequered flag on a pole. The pole's foot is
/// at the bottom centre of the widget.
class FinishFlagMarker extends StatelessWidget {
  const FinishFlagMarker({super.key});

  static const double width = 44;
  static const double height = 46;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _FlagPainter()),
    );
  }
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final poleX = size.width / 2;
    const top = 3.0;
    final bottom = size.height - 2;

    // Soft shadow under the flag so it reads on any map.
    canvas.drawCircle(
      Offset(poleX, bottom),
      4,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Pole.
    canvas.drawLine(
      Offset(poleX, top),
      Offset(poleX, bottom),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    // Chequered cloth, four squares across and three down.
    const columns = 4;
    const rows = 3;
    const cell = 7.0;
    final left = poleX + 1.3;
    final cloth = Rect.fromLTWH(left, top, columns * cell, rows * cell);
    canvas
      ..drawRect(cloth, Paint()..color = Colors.white)
      ..save()
      ..clipRect(cloth);
    final dark = Paint()..color = AppColors.background;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        if ((row + column).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(left + column * cell, top + row * cell, cell, cell),
            dark,
          );
        }
      }
    }
    canvas
      ..restore()
      ..drawRect(
        cloth,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white,
      );
  }

  @override
  bool shouldRepaint(_FlagPainter oldDelegate) => false;
}

/// Marks a place where the rider turned around.
class UTurnMarker extends StatelessWidget {
  const UTurnMarker({super.key, this.color = AppColors.yellow});

  final Color color;

  static const double size = 28;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
        ],
      ),
      child: Icon(Icons.u_turn_left_rounded, size: 16, color: color),
    );
  }
}
