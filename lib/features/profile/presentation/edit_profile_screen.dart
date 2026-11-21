import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/feedback/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/rider_palette.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/domain/display_name_rules.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/widgets/display_name_field.dart';
import '../../room/presentation/ride_launcher.dart';
import '../../room/presentation/widgets/color_tile.dart';
import 'widgets/profile_avatar.dart';

/// Edits the rider name and the solo ride colour. Both sync to every device
/// the rider signs in on. Rides already finished keep the name they were
/// ridden under.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late String _initialName;
  late String _initialColor;
  late String _color;
  bool _saving = false;
  bool _saved = false;

  static const int _colorColumns = 8;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    _initialName = profile?.riderName ?? '';
    _initialColor = RideLauncher.soloColorFor(profile?.soloColorId);
    _color = _initialColor;
    _name = TextEditingController(text: _initialName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _nameChanged => DisplayNameRules.clean(_name.text) != _initialName;
  bool get _colorChanged => _color != _initialColor;
  bool get _canSave =>
      DisplayNameRules.isValid(_name.text) && (_nameChanged || _colorChanged);

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final auth = ref.read(authRepositoryProvider);
    final results = <Result<void>>[
      if (_nameChanged)
        await auth.updateRiderName(DisplayNameRules.clean(_name.text)),
      if (_colorChanged) await auth.updatePreferences(soloColorId: _color),
    ];
    if (!mounted) return;
    for (final result in results) {
      if (result case Failed(:final failure)) {
        setState(() => _saving = false);
        showAppSnackBar(context, failure.message);
        return;
      }
    }
    AppHaptics.success();
    setState(() => _saved = true);
    await Future<void>.delayed(AppMotion.successHold);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = ref.watch(
      userProfileProvider.select((p) => p.value?.photoUrl),
    );
    final selected = RiderPalette.colorById(_color);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: [
                  FadeSlideIn(
                    child: Row(
                      children: [
                        ListenableBuilder(
                          listenable: _name,
                          builder: (context, _) => ProfileAvatar(
                            size: 64,
                            photoUrl: photoUrl,
                            riderName: _name.text,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Text(
                            photoUrl == null
                                ? 'Profile pictures are coming soon.'
                                : 'Your picture comes from your Google '
                                      'account. Choosing your own is coming '
                                      'soon.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const FadeSlideIn(
                    delay: AppMotion.stagger,
                    child: SectionLabel('RIDER NAME'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideIn(
                    delay: AppMotion.stagger,
                    child: DisplayNameField(
                      controller: _name,
                      enabled: !_saving,
                      onSubmitted: _save,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Rides you have already finished keep the name they '
                    'were ridden under.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FadeSlideIn(
                    delay: AppMotion.stagger * 2,
                    child: const SectionLabel('SOLO RIDE COLOUR'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FadeSlideIn(
                    delay: AppMotion.stagger * 2,
                    child: Text(
                      'Your dot, trail and replay on solo rides, and your '
                      'ride cards. Group rides still give every rider '
                      'their own colour.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideIn(
                    delay: AppMotion.stagger * 3,
                    child: GridView.count(
                      crossAxisCount: _colorColumns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      children: [
                        for (final c in RiderPalette.colors)
                          ColorTile(
                            color: c.color,
                            label: c.label,
                            state: c.id == _color
                                ? ColorTileState.mine
                                : ColorTileState.available,
                            onTap: _saving
                                ? null
                                : () => setState(() => _color = c.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (selected != null)
                    AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: Text(
                        selected.label,
                        key: ValueKey(selected.id),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: selected.color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: ListenableBuilder(
                listenable: _name,
                builder: (context, _) => AppButton(
                  label: 'Save',
                  isLoading: _saving,
                  isSuccess: _saved,
                  onPressed: _canSave ? _save : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
