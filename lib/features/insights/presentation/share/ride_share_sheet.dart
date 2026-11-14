import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/feedback/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/fade_slide_in.dart';

import '../../../../core/widgets/ride_loader.dart';
import '../../domain/share/share_card.dart';
import '../providers/insights_providers.dart';
import 'ride_card_sharer.dart';
import 'ride_share_card.dart';

/// Opens the share sheet for ride [code]: a preview of its ride card and a
/// button that shares it as an image.
Future<void> showRideShareSheet(BuildContext context, {required String code}) {
  AppHaptics.selection();
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RideShareSheet(code: code),
  );
}

class _RideShareSheet extends ConsumerStatefulWidget {
  const _RideShareSheet({required this.code});

  final String code;

  @override
  ConsumerState<_RideShareSheet> createState() => _RideShareSheetState();
}

class _RideShareSheetState extends ConsumerState<_RideShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  /// Why the last share failed, if it did.
  String? _error;

  /// How much of the screen the card preview may take.
  static const double _previewShare = 0.62;

  Future<void> _share(ShareCardData data) async {
    final boundary = _cardKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || _sharing) return;
    setState(() => _sharing = true);
    try {
      await RideCardSharer.share(
        boundary: boundary,
        code: widget.code,
        pixelRatio: RideShareCard.exportPixelRatio,
        text: '${data.title} · ${data.distance} on RideSync',
      );
      AppHaptics.success();
      if (mounted) setState(() => _error = null);
    } on Object {
      // Shown in the sheet: a snackbar would sit behind its barrier.
      AppHaptics.error();
      if (mounted) setState(() => _error = 'Could not share this ride.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recap = ref.watch(rideRecapProvider(widget.code));
    final maxHeight = MediaQuery.sizeOf(context).height * _previewShare;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: AnimatedSize(
          duration: AppMotion.slow,
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppMotion.slow,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.exit,
            child: recap.when(
              loading: () => const SizedBox(
                key: ValueKey('loading'),
                height: 240,
                child: RideLoaderMessage(message: 'Preparing your ride card…'),
              ),
              error: (error, _) => SizedBox(
                key: const ValueKey('error'),
                height: 200,
                child: Center(
                  child: Text(
                    error is Failure
                        ? error.message
                        : 'This ride could not be loaded.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
              data: (value) {
                final data = ShareCardBuilder.fromRecap(value);
                return Column(
                  key: const ValueKey('card'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Share your ride',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FadeScaleIn(
                      duration: AppMotion.springDuration,
                      spring: true,
                      blur: false,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: FittedBox(
                          // The card keeps its own size; only the preview
                          // is scaled, so the image is always 1080 × 1920.
                          child: RepaintBoundary(
                            key: _cardKey,
                            child: RideShareCard(data: data),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Share image',
                      icon: Icons.ios_share_rounded,
                      isLoading: _sharing,
                      onPressed: () => _share(data),
                    ),
                    AnimatedSize(
                      duration: AppMotion.normal,
                      curve: AppMotion.curve,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                              ),
                              child: Text(
                                _error!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.error),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
