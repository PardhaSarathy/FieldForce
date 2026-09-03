/// Spacing, radius and sizing tokens.
///
/// The specification (§77) asks for high information density without high
/// cognitive load. That means a tight base scale — 4pt grid — with generous
/// *grouping* gaps rather than generous padding everywhere.
abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Standard horizontal inset for screen content.
  static const screenH = 16.0;

  /// Vertical gap between major sections on a screen.
  static const section = 24.0;

  /// Inner padding for cards.
  static const cardPadding = 18.0;

  /// Gap between sibling cards in a list.
  static const cardGap = 12.0;
}

/// Corner radii.
///
/// Raised across the board in the finish pass: sharp corners read as
/// utilitarian, generous ones as considered, and it costs nothing in
/// legibility. Buttons use [pill] — fully rounded, with the icon inside.
abstract final class AppRadius {
  static const sm = 9.0;
  static const md = 13.0;
  static const lg = 17.0;
  static const xl = 22.0;
  static const pill = 999.0;
}

abstract final class AppSizes {
  /// Minimum interactive target (§73 accessibility).
  static const minTouchTarget = 48.0;

  static const buttonHeight = 48.0;
  static const buttonHeightSmall = 36.0;
  static const fieldHeight = 48.0;
  static const appBarHeight = 56.0;
  static const bottomNavHeight = 64.0;

  static const avatarSm = 32.0;
  static const avatarMd = 40.0;
  static const avatarLg = 56.0;

  static const iconSm = 16.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;

  static const borderWidth = 1.0;
  static const borderWidthFocus = 1.5;
}

/// Breakpoints for responsive layout (§74). The primary target is a phone;
/// tablets get wider gutters and, where useful, two-column list/detail.
abstract final class AppBreakpoints {
  static const compact = 400.0; // small phones
  static const medium = 600.0; // large phones / small tablets
  static const expanded = 840.0; // tablets
}
