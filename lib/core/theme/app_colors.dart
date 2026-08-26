import 'package:flutter/material.dart';

/// PharmaConnect color tokens.
///
/// These values are the authoritative palette from the master specification
/// (§10). Do not introduce raw `Color(0x...)` literals anywhere else in the
/// application — add a token here instead, so the palette stays auditable and
/// a future dark theme has a single place to swap.
///
/// Semantic intent (§11):
///   * [brand] communicates ACTION / ACTIVE / SELECTED / IMPORTANT / VERIFIED.
///   * [sand] communicates SECONDARY / PLANNED / CONTEXTUAL.
///   * [success] / [warning] / [error] / [info] communicate real states only,
///     never decoration.
abstract final class AppColors {
  // ---------------------------------------------------------------- surfaces
  /// Primary application background. Warm ivory, never pure white.
  static const background = Color(0xFFF7F5F0);

  /// Cards, sheets, elevated content.
  static const surface = Color(0xFFFFFFFF);

  /// Recessed rows, disabled fields, subtle fills.
  static const surfaceSecondary = Color(0xFFEFEEE9);

  // ------------------------------------------------------------------- ink
  static const textPrimary = Color(0xFF182027);
  static const textSecondary = Color(0xFF5F6870);

  /// Text on top of [brand] / [brandDark] fills.
  static const textOnBrand = Color(0xFFFFFFFF);

  static const border = Color(0xFFDDDCD6);

  // ----------------------------------------------------------------- brand
  static const brand = Color(0xFF075E63);
  static const brandDark = Color(0xFF06484C);

  /// Tinted brand background for selected chips, verified badges, soft fills.
  static const brandSoft = Color(0xFFE2F0EF);

  // ------------------------------------------------------------------ sand
  static const sand = Color(0xFFD8C5A3);
  static const sandSoft = Color(0xFFF3EDE2);

  /// Readable accent for the sand family. [sand] itself is a fill: at 4.5:1 it
  /// fails against [sandSoft], so icons and labels on a sand tile use this.
  /// Introduced so decorative tinting never has to borrow a semantic colour
  /// like [warning], which must keep meaning "something needs attention".
  static const sandDeep = Color(0xFF8A6E45);

  // -------------------------------------------------------------- semantic
  static const success = Color(0xFF287A55);
  static const warning = Color(0xFFA56A16);
  static const error = Color(0xFFB94A48);
  static const info = Color(0xFF416B86);

  /// Semantic colors at ~12% over ivory, for badge and banner backgrounds.
  /// Pre-computed rather than using `withOpacity` so they composite correctly
  /// over any surface, including white cards.
  static const successSoft = Color(0xFFE4EFEA);
  static const warningSoft = Color(0xFFF6EDDF);
  static const errorSoft = Color(0xFFF7E7E6);
  static const infoSoft = Color(0xFFE6EDF2);

  // ----------------------------------------------------------------- misc
  /// Scrim behind modal sheets and dialogs.
  static const scrim = Color(0x66182027);

  /// Skeleton loading base and shimmer highlight.
  static const skeletonBase = Color(0xFFEAE8E2);
  static const skeletonHighlight = Color(0xFFF4F2EE);
}
