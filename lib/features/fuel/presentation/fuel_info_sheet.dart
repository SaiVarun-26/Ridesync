import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/section_label.dart';
import '../../ride/domain/geo_point.dart';
import '../../ride/domain/live/ride_format.dart';
import '../domain/fuel_brand.dart';
import '../domain/fuel_station.dart';
import 'fuel_layer_preference.dart';
import 'fuel_providers.dart';
import 'fuel_station_controller.dart';
import 'fuel_station_layer.dart';

/// Opens the compact fuel information sheet (long press on the Fuel
/// button).
Future<void> showFuelInfoSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    // Sized to its content, and scrolls rather than overflows on a short
    // screen.
    isScrollControlled: true,
    builder: (_) => const FuelInfoSheet(),
  );
}

/// Fuel at a glance: the on/off switch, what each marker means, how far
/// stations are shown, how many are loaded and when they were last updated.
/// The figures follow the background search live.
class FuelInfoSheet extends ConsumerWidget {
  const FuelInfoSheet({super.key, this.now});

  /// The current time, for "today"; the clock by default.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final on = ref.watch(fuelLayerVisibleProvider) ?? true;
    final fuel = ref.watch(fuelStationControllerProvider);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fuel stations',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                Switch(
                  value: on,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.border,
                  onChanged: (v) {
                    AppHaptics.selection();
                    ref.read(fuelLayerVisibleProvider.notifier).setVisible(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ListenableBuilder(
              listenable: fuel,
              builder: (context, _) => _Status(
                controller: fuel,
                now: (now ?? DateTime.now)(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('MARKERS'),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, box) {
                final width = (box.maxWidth - AppSpacing.md) / 2;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final brand in FuelBrands.all)
                      SizedBox(
                        width: width,
                        child: _LegendRow(
                          station: _sample(brand.name),
                          label: brand.label,
                          name: brand.name,
                        ),
                      ),
                    SizedBox(
                      width: width,
                      child: _LegendRow(
                        station: _sample(null),
                        label: null,
                        name: 'Unknown brand',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tap the fuel button to show or hide stations. '
              'Hold it for this sheet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static FuelStation _sample(String? brand) => FuelStation(
    id: 'legend-${brand ?? 'none'}',
    point: const GeoPoint(latitude: 0, longitude: 0),
    brand: brand,
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.controller, required this.now});

  final FuelStationController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = controller.lastUpdatedAt;
    final count = controller.visible.length;
    final updated = at == null
        ? (controller.state == FuelSearchState.unavailable
              ? 'Not updated yet: offline'
              : 'Not updated yet')
        : 'Updated ${_when(at)}';
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Showing stations within '
          '${(controller.radiusMeters / 1000).round()} km',
          style: muted,
        ),
        Text(
          '$count ${count == 1 ? 'station' : 'stations'} loaded · $updated',
          style: muted,
        ),
      ],
    );
  }

  String _when(DateTime at) {
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay
        ? RideFormat.time(at)
        : '${RideFormat.date(at)}, ${RideFormat.time(at)}';
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.station,
    required this.label,
    required this.name,
  });

  final FuelStation station;
  final String? label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label == null ? '$name marker' : '$label marker: $name',
      excludeSemantics: true,
      child: Row(
        children: [
          FuelBrandBadge(station: station, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
