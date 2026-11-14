import 'package:flutter/material.dart';

import '../../domain/achievements/achievement.dart';
import '../../domain/analysis/ride_insights.dart';
import '../../domain/weather/weather_snapshot.dart';

/// The icon for each kind of achievement, insight and weather, so every
/// screen draws the same thing for the same idea. All from the rounded set.
abstract final class InsightVisuals {
  static IconData achievement(AchievementKind kind) => switch (kind) {
    AchievementKind.longestRide => Icons.route_rounded,
    AchievementKind.topSpeedRecord => Icons.speed_rounded,
    AchievementKind.bestFinish => Icons.military_tech_rounded,
    AchievementKind.distanceLeader => Icons.emoji_events_rounded,
    AchievementKind.groupLeader => Icons.flag_rounded,
    AchievementKind.fastestSprint => Icons.bolt_rounded,
    AchievementKind.longestContinuous => Icons.all_inclusive_rounded,
    AchievementKind.smoothestRide => Icons.waves_rounded,
    AchievementKind.consistentPace => Icons.timeline_rounded,
    AchievementKind.nightRide => Icons.nightlight_rounded,
  };

  /// Short names for a chip: "Longest Ride".
  static String achievementTitle(AchievementKind kind) => switch (kind) {
    AchievementKind.longestRide => 'Longest Ride',
    AchievementKind.topSpeedRecord => 'Top Speed PB',
    AchievementKind.bestFinish => 'Best Finish',
    AchievementKind.distanceLeader => 'Distance Leader',
    AchievementKind.groupLeader => 'Group Leader',
    AchievementKind.fastestSprint => 'Fastest Sprint',
    AchievementKind.longestContinuous => 'Non-stop',
    AchievementKind.smoothestRide => 'Smoothest Ride',
    AchievementKind.consistentPace => 'Steady Pace',
    AchievementKind.nightRide => 'Night Ride',
  };

  static IconData weather(WeatherCondition condition, {bool? isDay}) =>
      switch (condition) {
        WeatherCondition.clear =>
          isDay == false ? Icons.nightlight_rounded : Icons.wb_sunny_rounded,
        WeatherCondition.partlyCloudy => Icons.wb_cloudy_rounded,
        WeatherCondition.cloudy => Icons.cloud_rounded,
        WeatherCondition.fog => Icons.blur_on_rounded,
        WeatherCondition.drizzle => Icons.grain_rounded,
        WeatherCondition.rain => Icons.water_drop_rounded,
        WeatherCondition.showers => Icons.umbrella_rounded,
        WeatherCondition.snow => Icons.ac_unit_rounded,
        WeatherCondition.thunderstorm => Icons.thunderstorm_rounded,
      };

  static IconData insight(InsightKind kind) => switch (kind) {
    InsightKind.smoothness => Icons.waves_rounded,
    InsightKind.consistency => Icons.timeline_rounded,
    InsightKind.intensity => Icons.local_fire_department_rounded,
    InsightKind.fastestSegment => Icons.bolt_rounded,
    InsightKind.slowestSegment => Icons.hourglass_bottom_rounded,
    InsightKind.mostActive => Icons.directions_bike_rounded,
    InsightKind.closestPair => Icons.compare_arrows_rounded,
    InsightKind.paceStability => Icons.groups_rounded,
  };
}
