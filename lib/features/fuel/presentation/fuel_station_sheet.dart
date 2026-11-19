import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_icon.dart';
import '../../ride/domain/geo_point.dart';
import '../../ride/domain/live/ride_format.dart';
import '../domain/fuel_station.dart';
import 'fuel_station_layer.dart';

/// Opens the sheet for [station]: its name, how far it is from [from] (this
/// rider), about how long riding there takes, where it is, and a button that
/// hands it to Google Maps. RideSync's own guidance is never changed.
Future<void> showFuelStationSheet(
  BuildContext context, {
  required FuelStation station,
  required GeoPoint? from,
  double? speedMps,
}) {
  AppHaptics.selection();
  return showAppSheet<void>(
    context: context,
    builder: (_) =>
        FuelStationSheet(station: station, from: from, speedMps: speedMps),
  );
}

/// The Google Maps link for [station]: a search for its exact position, which
/// opens the Google Maps app when installed and the website otherwise.
Uri googleMapsUri(FuelStation station) {
  final at =
      '${station.point.latitude.toStringAsFixed(6)},'
      '${station.point.longitude.toStringAsFixed(6)}';
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': at,
  });
}

class FuelStationSheet extends StatelessWidget {
  const FuelStationSheet({
    super.key,
    required this.station,
    required this.from,
    this.speedMps,
    this.launcher,
  });

  final FuelStation station;
  final GeoPoint? from;
  final double? speedMps;

  /// Opens a link outside the app; the platform's by default.
  final Future<bool> Function(Uri uri)? launcher;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _open(BuildContext context) async {
    AppHaptics.light();
    var opened = false;
    try {
      opened = await (launcher ?? _launch)(googleMapsUri(station));
    } on Object {
      opened = false;
    }
    if (!context.mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      showAppSnackBar(context, 'Could not open Google Maps.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = from;
    final straight = origin?.distanceMetersTo(station.point);
    final p = station.point;
    return SafeArea(
      top: false,
      child: Padding(
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: FuelStationLayer.color,
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    size: AppIconSize.medium,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    station.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: _Fact(
                    label: 'DISTANCE',
                    value: straight == null
                        ? '—'
                        : RideFormat.distance(straight),
                    detail: 'In a straight line',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Fact(
                    label: 'RIDING TIME',
                    value: straight == null
                        ? '—'
                        : RideFormat.eta(
                            FuelEstimates.ridingTime(
                              straight,
                              speedMps: speedMps,
                            ),
                          ),
                    detail: 'Estimated',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _Fact(
              label: 'COORDINATES',
              value:
                  '${p.latitude.toStringAsFixed(5)}, '
                  '${p.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Open in Google Maps',
              icon: Icons.open_in_new_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => _open(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Opens outside RideSync. Your ride carries on as it is.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: theme.textTheme.titleMedium),
          if (detail != null)
            Text(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
