import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small, widely tracked uppercase label used to title sections (e.g.
/// "RIDERS", "RIDE CODE"). Pass the text already uppercased.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  static const double _letterSpacing = 1.6;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: _letterSpacing,
          ),
    );
  }
}
