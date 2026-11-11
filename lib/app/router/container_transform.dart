import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A page that grows out of the card it was opened from.
///
/// The card's rectangle expands to fill the screen while its corners square
/// off, the screen behind darkens, and the page's content fades in once the
/// card is mostly open. Closing plays it in reverse, back into the card. The
/// page is laid out at full size from the first frame, so anything heavy on it
/// (a map, say) is already getting ready while the card opens.
///
/// With no [origin] the page simply fades in.
CustomTransitionPage<void> containerTransformPage({
  required GoRouterState state,
  required Widget child,
  required Rect? origin,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 380),
    transitionsBuilder: (context, animation, secondaryAnimation, page) {
      if (origin == null) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: page,
        );
      }
      return _ContainerTransform(
        animation: animation,
        origin: origin,
        child: page,
      );
    },
  );
}

class _ContainerTransform extends StatefulWidget {
  const _ContainerTransform({
    required this.animation,
    required this.origin,
    required this.child,
  });

  final Animation<double> animation;
  final Rect origin;
  final Widget child;

  @override
  State<_ContainerTransform> createState() => _ContainerTransformState();
}

class _ContainerTransformState extends State<_ContainerTransform> {
  late final CurvedAnimation _shape = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeInOutCubicEmphasized,
    reverseCurve: Curves.easeInOutCubic,
  );
  late final CurvedAnimation _content = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    reverseCurve: const Interval(0, 0.5, curve: Curves.easeIn),
  );

  @override
  void dispose() {
    _shape.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final full = Offset.zero & screen;
    // The page is laid out at full size once; only the clip around it moves.
    final page = FadeTransition(opacity: _content, child: widget.child);

    return AnimatedBuilder(
      animation: _shape,
      child: page,
      builder: (context, page) {
        final t = _shape.value.clamp(0.0, 1.0);
        final rect = Rect.lerp(widget.origin, full, _shape.value)!;
        final radius = BorderRadius.circular(
          lerpDouble(AppRadius.card + 4, 0, t)!,
        );
        return Stack(
          children: [
            // The screen behind darkens as the card opens.
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.6 * t)),
            ),
            Positioned.fromRect(
              rect: rect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: radius,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: screen.width,
                    maxWidth: screen.width,
                    minHeight: screen.height,
                    maxHeight: screen.height,
                    child: page,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
