import 'dart:async';

import 'package:flutter/services.dart';

/// RideSync's haptic vocabulary. Every vibration in the app goes through here,
/// so strengths stay consistent and nothing buzzes more than it should.
///
/// From lightest to strongest:
/// - [selection]: a touch landing on something (a press, a marker tap, a
///   slider notch).
/// - [light]: a soft nudge (an action cancelled, a field asking for more).
/// - [success]: something worked (room created, joined, saved).
/// - [milestone]: a moment in the ride (the ride starts, the ride ends, the
///   end-ride slider confirms).
/// - [error]: something went wrong. Two light taps, distinct from every
///   success without being harsh.
abstract final class AppHaptics {
  static void selection() => unawaited(HapticFeedback.selectionClick());

  static void light() => unawaited(HapticFeedback.lightImpact());

  static void success() => unawaited(HapticFeedback.mediumImpact());

  static void milestone() => unawaited(HapticFeedback.heavyImpact());

  static void error() {
    unawaited(HapticFeedback.lightImpact());
    Timer(_errorGap, () => unawaited(HapticFeedback.lightImpact()));
  }

  /// The pause between the two taps of [error].
  static const Duration _errorGap = Duration(milliseconds: 90);
}
