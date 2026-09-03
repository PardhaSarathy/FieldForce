import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for Mr Sales.
///
/// Font choice: **Plus Jakarta Sans, bundled** — a 172 KB variable TTF in
/// `assets/fonts/`, shipped inside the APK.
///
/// This replaces an earlier rule that said to use the platform UI face and
/// fetch nothing. The offline reasoning was right and the conclusion was
/// wrong: `google_fonts` resolving a face over the network is indeed wrong for
/// a rep in a hospital basement, but a *bundled* font is not a fetch. It works
/// on a plane. The rule was written against the wrong risk, and it cost the app
/// its identity — the platform face is the same one every default Android form
/// uses, and nothing reads as generic faster.
///
/// It is a variable font, so one file covers 200–800 and `FontWeight` works
/// across the whole range without shipping a file per weight.
abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

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
    fontFeatures: _tabular,
  );

  static const titleSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
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
    fontFeatures: _tabular,
  );

  static const bodySm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.40,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontFeatures: _tabular,
  );

  // ----------------------------------------------------------- supporting
  /// Metadata under a title: specialty, area, timestamps.
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontFeatures: _tabular,
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

  // Digits are tabular across the text styles too, not only the metrics.
  //
  // Half the figures in this app sit inside sentences in rows — "3 of 10
  // visits today", "12/16", a money column — and with proportional digits a 1
  // is narrower than a 7, so the numbers shift sideways as the data changes
  // and a column of them never lines up. It is the cheapest thing that
  // separates a data-dense screen that looks considered from one that does
  // not.

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
