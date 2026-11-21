import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The rider's picture in a circle: their Google photo when there is one,
/// else the first letter of their rider name (or a person glyph). Solid
/// colours, a hairline ring.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.photoUrl,
    this.riderName,
  });

  final double size;
  final String? photoUrl;
  final String? riderName;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceRaised,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? _fallback()
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Offline or a broken link: the letter, never an error box.
              errorBuilder: (context, error, stack) => _fallback(),
              frameBuilder: (context, child, frame, synchronous) =>
                  synchronous || frame != null ? child : _fallback(),
            ),
    );
  }

  Widget _fallback() {
    final name = riderName?.trim() ?? '';
    if (name.isEmpty) {
      return Center(
        child: Icon(
          Icons.person_rounded,
          size: size * 0.55,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Center(
      child: Text(
        String.fromCharCode(name.runes.first).toUpperCase(),
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
