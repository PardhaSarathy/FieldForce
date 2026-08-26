import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for PharmaConnect.
///
/// Font choice: we deliberately use the *platform* UI face (SF Pro on iOS,
/// Roboto on Android) rather than a webfont. This is an offline-first field
/// application (§8) — `google_fonts` resolves faces over the network on first
/// use, which is exactly wrong for a rep standing in a hospital basement. To
/// adopt a bundled brand face later, drop the .ttf files into `assets/fonts/`,
/// declare them in pubspec.yaml, and set [fontFamily] — nothing else changes.
abstract final class AppTypography {
  static const String? fontFamily = null;

  /// Tabular figures keep numeric columns (amounts, targets, distances) from
  /// jittering as values change. Applied to metrics and money, not prose.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ---------------------------------------------------------------- display
  /// Large greeting / hero number. Used sparingly.
  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    height: 1.20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  // -------------------------------------------------------------- headings
  static const h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 1.30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Card / row title.
  static const titleMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const titleSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ------------------------------------------------------------------ body
  static const bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const bodySm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.40,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ----------------------------------------------------------- supporting
  /// Metadata under a title: specialty, area, timestamps.
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Section headers and eyebrow labels. Always uppercase at call site.
  static const overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 1.30,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  /// Status badge text.
  static const badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 1.20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  // -------------------------------------------------------------- numerics
  /// Hero metric on a MetricCard.
  static const metric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const metricSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Currency and quantities inside dense rows and tables.
  static const numeric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );
}
