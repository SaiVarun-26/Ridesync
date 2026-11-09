import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A selectable rider accent: a stable [id] (persisted to the database) paired
/// with a display [label] and the neon [color] used for the rider's dot and
/// trail.
///
/// The [id] is what gets written to the Realtime Database during color
/// claiming, never the raw color value. This keeps the wire format stable even
/// if we retune a hex value later.
@immutable
class RiderColor {
  const RiderColor({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RiderColor && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// The fixed pool of rider colors. This is the single source of truth for what
/// riders can claim in a lobby; a rider's color is their only identity in V1
/// (no icons), so every color must read clearly as a glowing dot on black.
///
/// Curation rules:
/// - No reds: red is reserved for warnings.
/// - No deep blues: Electric Blue (#2E6BFF) is reserved for the planned route,
///   so neighbouring blues are excluded to keep trails distinct from it.
/// - No dull or dark tones: every entry is a bright neon that holds up on
///   #050505.
/// - No near-duplicates: tones that would be confused on a map were dropped,
///   which is why the pool stops at 21 rather than a round number.
@immutable
abstract final class RiderPalette {
  /// Number of colors shown inline in the lobby before the "more" tile.
  static const int featuredCount = 5;

  /// All rider colors, in display order. The first [featuredCount] entries are
  /// the featured picks shown inline. Existing ids (`green`, `orange`,
  /// `purple`, `cyan`, `pink`, `yellow`) are preserved so previously stored
  /// claims still resolve.
  static const List<RiderColor> colors = <RiderColor>[
    // Featured.
    RiderColor(id: 'green', label: 'Neon Green', color: AppColors.neonGreen),
    RiderColor(id: 'orange', label: 'Orange', color: AppColors.orange),
    RiderColor(id: 'purple', label: 'Purple', color: AppColors.purple),
    RiderColor(id: 'cyan', label: 'Cyber Cyan', color: AppColors.cyan),
    RiderColor(id: 'pink', label: 'Hot Pink', color: AppColors.pink),
    // Extended.
    RiderColor(id: 'yellow', label: 'Volt', color: AppColors.yellow),
    RiderColor(id: 'lime', label: 'Lime', color: Color(0xFFB6FF3B)),
    RiderColor(id: 'mint', label: 'Mint', color: Color(0xFF7CFFB2)),
    RiderColor(id: 'aqua', label: 'Aqua', color: Color(0xFF00FFD5)),
    RiderColor(id: 'chartreuse', label: 'Chartreuse', color: Color(0xFFDFFF00)),
    RiderColor(id: 'amber', label: 'Amber', color: Color(0xFFFFC233)),
    RiderColor(id: 'peach', label: 'Peach', color: Color(0xFFFFB38A)),
    RiderColor(id: 'coral', label: 'Coral', color: Color(0xFFFF7A59)),
    RiderColor(id: 'rose', label: 'Rose', color: Color(0xFFFF8FC7)),
    RiderColor(id: 'magenta', label: 'Magenta', color: Color(0xFFFF3DF2)),
    RiderColor(id: 'orchid', label: 'Orchid', color: Color(0xFFE36BFF)),
    RiderColor(id: 'violet', label: 'Violet', color: Color(0xFFC77DFF)),
    RiderColor(id: 'lavender', label: 'Lavender', color: Color(0xFFB8A6FF)),
    RiderColor(id: 'sky', label: 'Sky', color: Color(0xFF5CC8FF)),
    RiderColor(id: 'ice', label: 'Ice', color: Color(0xFFA8F0FF)),
    RiderColor(id: 'pearl', label: 'Pearl', color: Color(0xFFF2F2F2)),
  ];

  /// The featured colors shown inline in the lobby picker.
  static List<RiderColor> get featured => colors.sublist(0, featuredCount);

  /// Resolves a persisted color id back to its [RiderColor], or `null` if the
  /// id is unknown (e.g. a palette entry removed in a future version).
  static RiderColor? colorById(String? id) {
    if (id == null) return null;
    for (final c in colors) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Whether [id] is one of the featured colors.
  static bool isFeatured(String? id) =>
      id != null && featured.any((c) => c.id == id);

  const RiderPalette._();
}
