import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// 4-point spacing scale. Use these tokens instead of raw numbers so spacing
/// stays consistent across the app.
@immutable
abstract final class AppSpacing {
  /// A hairline gap: a unit beside its number, a label under a value.
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Inside every status pill and badge.
  static const EdgeInsets pill = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xs + xxs,
  );

  const AppSpacing._();
}

/// Corner radii, by the size of what they round.
@immutable
abstract final class AppRadius {
  /// Small chips and tags.
  static const double sm = 8;

  /// Blocks inside a card, colour tiles, snackbars.
  static const double md = 12;

  /// Standard cards, text fields, route thumbnails.
  static const double card = 16;

  /// Feature cards (history, ride mode), floating panels, dialogs, sheets.
  static const double lg = 24;

  /// Buttons, pills, handles and bars: fully round ends.
  static const double pill = 999;

  const AppRadius._();
}

/// The RideSync motion system. Every animation in the app takes its timing,
/// curve and spring from here, so every screen moves the same way.
///
/// Durations, by what is moving:
/// - [micro]: colour and tint under a finger, a thumb snapping home.
/// - [fast]: small swaps in place (an icon, a line of text).
/// - [normal]: the default: fades, switches, borders, sizes.
/// - [slow]: large content: page transitions, dialogs, overlays, the map
///   appearing, section entrances.
/// - [springDuration]: anything using [spring], and the container transform.
///
/// Curves, by direction:
/// - [curve]: things arriving or changing (decelerate).
/// - [exit]: things leaving (accelerate away).
/// - [move]: things travelling or being drawn from one place to another.
/// - [emphasized]: a surface growing into a page.
/// - [spring]: pop-ins with a touch of overshoot (checks, sheets, markers).
/// - [ambient]: slow loops that breathe (pulses, skeletons, the logo).
@immutable
abstract final class AppMotion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  /// How long arrivals that use [spring] take to settle.
  static const Duration springDuration = Duration(milliseconds: 520);

  /// A one-off brand entrance: the splash and full-screen loaders.
  static const Duration entrance = Duration(milliseconds: 600);

  /// Gap between items entering one after another.
  static const Duration stagger = Duration(milliseconds: 60);

  /// How long a success check stays on a button before the app moves on:
  /// long enough to register, short enough to feel instant.
  static const Duration successHold = Duration(milliseconds: 220);

  /// Half of one breath of an [ambient] loop (in, then out).
  static const Duration breath = Duration(milliseconds: 1600);

  /// The invalid-input shake.
  static const Duration shake = Duration(milliseconds: 400);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve move = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve ambient = Curves.easeInOut;

  /// A gentle spring: overshoots a touch and settles. For things that arrive
  /// (sheets, checks, pop-ins), never for things that merely fade.
  static const Curve spring = SpringCurve();

  /// The scale things start from when they fade and grow in.
  static const double enterScale = 0.92;

  /// Touch physics: pressing in is quick and firm; letting go is looser, so
  /// the control overshoots a little on its way back.
  static final SpringDescription pressIn = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 900,
  );
  static final SpringDescription pressOut = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.5,
  );

  /// Something let go after a drag (a slider thumb, a sheet) gliding back to
  /// rest: softer than [pressOut] because it travels further.
  static final SpringDescription settle = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 320,
    ratio: 0.78,
  );

  /// Sideways offset of the invalid-input shake at progress [t] (0 to 1):
  /// three quick swings that die away.
  static double shakeOffset(double t) =>
      math.sin(t * math.pi * 6) * (1 - t) * _shakeDistance;

  static const double _shakeDistance = 8;

  const AppMotion._();
}

/// A curve that follows a damped spring from 0 to 1.
///
/// The spring is lightly damped, so it passes 1 slightly and settles back,
/// which reads as weight rather than bounce.
class SpringCurve extends Curve {
  const SpringCurve({this.dampingRatio = 0.7, this.stiffness = 220});

  final double dampingRatio;
  final double stiffness;

  /// Seconds of spring motion mapped onto the curve's 0 to 1.
  static const double _seconds = 0.55;

  @override
  double transformInternal(double t) {
    final spring = SpringSimulation(
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: stiffness,
        ratio: dampingRatio,
      ),
      0,
      1,
      0,
    );
    return spring.x(t * _seconds);
  }
}
