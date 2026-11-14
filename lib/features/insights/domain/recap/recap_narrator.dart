import '../analysis/route_profile.dart';
import '../weather/weather_snapshot.dart';

/// The facts a recap sentence is written from. Kept separate from the
/// sentence itself, so a different narrator (an AI model, say) can be given
/// exactly the same facts later.
class RecapFacts {
  const RecapFacts({
    required this.startedAt,
    required this.riderCount,
    required this.distanceMeters,
    required this.durationMs,
    required this.averageSpeedMps,
    this.smoothness,
    this.consistency,
    this.paceStability,
    this.topSpeedFraction,
    this.route,
    this.weather,
  });

  final DateTime startedAt;
  final int riderCount;

  /// This rider's distance (or the group's, when they did not ride).
  final double distanceMeters;
  final int durationMs;
  final double averageSpeedMps;

  final double? smoothness;
  final double? consistency;

  /// 0–100 for a group ride; `null` solo.
  final double? paceStability;

  /// Where the top speed came, 0 (start) to 1 (end).
  final double? topSpeedFraction;

  final RouteProfile? route;
  final WeatherSnapshot? weather;

  bool get isSolo => riderCount <= 1;
}

/// Writes a short, human recap of a ride.
abstract interface class RecapNarrator {
  String narrate(RecapFacts facts);
}

/// The built-in narrator: a few sentences assembled from rules, so the same
/// ride always reads the same.
class RuleBasedRecapNarrator implements RecapNarrator {
  const RuleBasedRecapNarrator();

  @override
  String narrate(RecapFacts f) {
    final sentences = <String>[_opening(f)];
    final pace = _pace(f);
    if (pace != null) sentences.add(pace);
    final setting = _setting(f);
    if (setting != null) sentences.add(setting);
    return sentences.join(' ');
  }

  /// "A smooth evening ride with 4 riders." / "A steady solo morning ride."
  String _opening(RecapFacts f) {
    final feel = switch (f.smoothness) {
      null => f.averageSpeedMps * 3.6 >= 25 ? 'brisk' : 'relaxed',
      >= 80 => 'smooth',
      >= 60 => 'steady',
      >= 40 => 'lively',
      _ => 'stop-and-go',
    };
    final when = _timeOfDay(f.startedAt.hour);
    final article = _startsWithVowel(feel) ? 'An' : 'A';
    return f.isSolo
        ? '$article $feel solo $when ride.'
        : '$article $feel $when ride with ${f.riderCount} riders.';
  }

  /// "The group kept a steady pace, with a top speed burst near the end."
  String? _pace(RecapFacts f) {
    final String? base;
    if (!f.isSolo && f.paceStability != null) {
      base = switch (f.paceStability!) {
        >= 75 => 'The group kept a steady pace',
        >= 50 => 'The group rode at a fairly even pace',
        _ => 'The group spread out along the way',
      };
    } else if (f.consistency != null) {
      base = f.consistency! >= 70
          ? 'You held a steady pace'
          : 'You mixed easy stretches with quicker ones';
    } else {
      base = null;
    }
    final burst = switch (f.topSpeedFraction) {
      null => null,
      < 0.25 => 'early on',
      < 0.7 => 'midway',
      _ => 'near the end',
    };
    if (base == null) {
      return burst == null ? null : 'The top speed came $burst.';
    }
    return burst == null ? '$base.' : '$base, with a top speed burst $burst.';
  }

  /// Weather and the shape of the route, when known.
  String? _setting(RecapFacts f) {
    final parts = <String>[];
    final weather = f.weather;
    if (weather != null) {
      final sky = switch (weather.condition) {
        WeatherCondition.clear => 'clear skies',
        WeatherCondition.partlyCloudy => 'partly cloudy skies',
        WeatherCondition.cloudy => 'cloudy skies',
        WeatherCondition.fog => 'fog',
        WeatherCondition.drizzle => 'light drizzle',
        WeatherCondition.rain => 'rain',
        WeatherCondition.showers => 'passing showers',
        WeatherCondition.snow => 'snow',
        WeatherCondition.thunderstorm => 'thunderstorms',
      };
      parts.add('$sky at ${weather.temperatureLabel}C');
    }
    final route = f.route;
    if (route != null && route.distanceMeters >= 2000) {
      parts.add(switch (route.shape) {
        RouteShape.loop => 'a loop back to the start',
        RouteShape.outAndBack => 'out and back the same way',
        RouteShape.pointToPoint =>
          'mostly ${route.character.label.toLowerCase()}',
      });
    }
    if (parts.isEmpty) return null;
    final text = parts.join(', ');
    return '${text[0].toUpperCase()}${text.substring(1)}.';
  }

  static String _timeOfDay(int hour) => switch (hour) {
    >= 5 && < 12 => 'morning',
    >= 12 && < 17 => 'afternoon',
    >= 17 && < 20 => 'evening',
    _ => 'night',
  };

  static bool _startsWithVowel(String word) =>
      word.isNotEmpty && 'aeiou'.contains(word[0]);
}
