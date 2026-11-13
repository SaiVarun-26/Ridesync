import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's backdrop: near-black with one very faint, very wide wash of the
/// brand purple in a corner, only enough to tell the page from a flat fill.
///
/// The wash is a single solid circle softened by an enormous blur and painted
/// once on its own layer, so it costs nothing per frame. No gradients.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.alignment = Alignment.topLeft,
  });

  final Widget child;

  /// Which corner the wash sits in.
  final Alignment alignment;

  static const double _diameter = 260;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Align(
                alignment: alignment,
                child: Transform.translate(
                  // Pushed partly off the corner, so only its soft edge shows.
                  offset: Offset(
                    -alignment.x * _diameter * 0.35,
                    -alignment.y * _diameter * 0.35,
                  ),
                  child: Container(
                    width: _diameter,
                    height: _diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          blurRadius: 220,
                          spreadRadius: 70,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
