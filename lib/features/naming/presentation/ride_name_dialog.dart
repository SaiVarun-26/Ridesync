import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/ride_naming_service.dart';
import '../domain/ride_title_generator.dart';

/// Saves a name. Returns a message to show when it could not be saved, or
/// `null` when it was.
typedef SaveRideName = Future<String?> Function(String name);

/// Asks for a ride's name, in the app's dialog (which scales and fades in).
///
/// One dialog for naming a ride after it ends and for renaming it later. With
/// a [suggestion] the field fills itself when the suggestion arrives, unless
/// the rider has already started typing. Resolves to `true` once a name was
/// saved, and `false` when the rider cancelled.
Future<bool> showRideNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required SaveRideName onSave,
  String? message,
  String? initialName,
  Future<String>? suggestion,
  bool barrierDismissible = false,
}) async {
  final saved = await showAppDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _RideNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      message: message,
      initialName: initialName,
      suggestion: suggestion,
      onSave: onSave,
    ),
  );
  return saved ?? false;
}

class _RideNameDialog extends StatefulWidget {
  const _RideNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.onSave,
    this.message,
    this.initialName,
    this.suggestion,
  });

  final String title;
  final String confirmLabel;
  final String? message;
  final String? initialName;
  final Future<String>? suggestion;
  final SaveRideName onSave;

  @override
  State<_RideNameDialog> createState() => _RideNameDialogState();
}

class _RideNameDialogState extends State<_RideNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName ?? '',
  );
  bool _saving = false;
  bool _waiting = false;
  bool _typed = false;
  String? _error;

  static const double _width = 340;

  @override
  void initState() {
    super.initState();
    final suggestion = widget.suggestion;
    if (suggestion != null && _controller.text.isEmpty) {
      _waiting = true;
      suggestion.then((name) {
        if (!mounted) return;
        setState(() {
          _waiting = false;
          // The rider's own words always win over a late suggestion.
          if (!_typed && _controller.text.isEmpty) {
            _controller.text = name;
            _controller.selection = TextSelection.collapsed(
              offset: name.length,
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && RideNamingService.clean(_controller.text) != null;

  Future<void> _save() async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(_controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedPadding(
      // Rises with the keyboard instead of hiding behind it.
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _width),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: const BorderSide(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title, style: theme.textTheme.titleLarge),
                  if (widget.message != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(widget.message!, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => AppTextField(
                      controller: _controller,
                      enabled: !_saving,
                      label: 'Ride Name',
                      hintText: _waiting ? 'Finding a name…' : 'Name your ride',
                      textCapitalization: TextCapitalization.words,
                      maxLength: RideNames.maxLength,
                      errorText: _error,
                      onSubmitted: (_) => _save(),
                      isValid:
                          RideNamingService.clean(_controller.text) != null,
                      inputFormatters: [_MarkTyped(() => _typed = true)],
                    ),
                  ),
                  if (widget.suggestion != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Suggested from where you finished · © OpenStreetMap '
                      'contributors',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => AppButton(
                      label: widget.confirmLabel,
                      isLoading: _saving,
                      onPressed: _canSave ? _save : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.secondary,
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Notes that the rider has typed, so a suggestion that arrives late does not
/// overwrite their words. Changes nothing about the text.
class _MarkTyped extends TextInputFormatter {
  _MarkTyped(this.onTyped);

  final VoidCallback onTyped;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text != newValue.text) onTyped();
    return newValue;
  }
}
