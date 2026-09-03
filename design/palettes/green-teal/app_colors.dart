import 'package:flutter/material.dart';

/// Mr Sales colour tokens — deep teal on a green ground.
///
/// The brand colour is [brand], a deep saturated teal. Depth is what reads as
/// considered rather than merely colourful, and the ground is tinted toward the
/// same hue so the screen sits in one family instead of arguing with itself.
///
/// Everything here is measured. A rep reads these screens standing in the
/// street at midday, so anything carrying meaning clears **4.5:1** against the
/// surface behind it and most clear 7:1 — glare eats real contrast long before
/// it eats the number. The ratios quoted below are against [background] unless
/// stated otherwise.
///
/// Do not introduce raw `Color(0x...)` literals anywhere else in the
/// application — add a token here instead, so the palette stays auditable and
/// a future dark theme has a single place to swap.
///
/// Two rules the values encode, and which are easy to break by accident:
///
///  * **A fill is not a foreground.** [sand] and [star] are light enough to
///    carry dark ink on top of them and nothing else; as an icon or a word they
///    measure under 3:1. Each has a paired deep ink for that job.
///  * **Semantic colours are a closed set.** [success], [warning], [error] and
///    [info] mean real states. Decoration draws from the brand family — the
///    icon wells below — and never borrows one of these to tint a tile.
abstract final class AppColors {
  // ---------------------------------------------------------------- surfaces
  /// Page ground. A green-tinted near-white: bright enough that glare has room
  /// to eat before text suffers, and in the brand's own hue family so the teal
  /// looks chosen rather than dropped on.
  static const background = Color(0xFFECF4F1);

  /// Cards, sheets, elevated content.
  static const surface = Color(0xFFFFFFFF);

  /// Recessed rows, disabled fields, subtle fills.
  static const surfaceSecondary = Color(0xFFE3EDEA);

  /// The page ground is a wash, not a flat fill.
  ///
  /// A single colour behind every screen is the flattest thing an app can do,
  /// and it is most of what separates this from the references: theirs fades,
  /// so the screen has somewhere to recede to and the white cards look like
  /// they are floating on something. These three stops run top to bottom —
  /// tint gathered under the app bar, light gathering toward the thumb.
  ///
  /// The tint at the top is deliberate and visible — the first pass was too
  /// timid to read as anything but off-white, which is the whole problem it
  /// was meant to solve. This is the reference's own depth of mint.
  ///
  /// Body text still holds at 12.1:1 against the darkest stop and 15.0:1
  /// against the lightest, and secondary text at 5.7:1, so nothing about
  /// legibility changes as the eye travels down the page. The white cards gain
  /// too: at the top of the screen they now separate from the ground at
  /// 1.29:1 rather than 1.18:1, so they read as floating rather than merged.
  static const backgroundTop = Color(0xFFD3E6E6);
  static const backgroundMid = Color(0xFFE2F0EF);
  static const backgroundBottom = Color(0xFFF4FAF9);

  /// A soft highlight laid over the wash, as if light were falling from the
  /// top right. What stops the gradient reading as a flat ramp.
  static const backgroundGlow = Color(0x66FFFFFF);

  // ------------------------------------------------------------------- ink
  /// Body text. 14.0:1.
  static const textPrimary = Color(0xFF14262A);

  /// Secondary text — captions, metadata, helper lines. 6.6:1.
  ///
  /// Secondary text is half the words on a list screen, so it is held well
  /// above the AA floor rather than at it.
  static const textSecondary = Color(0xFF46595E);

  /// Text on top of [brand] / [brandDark] fills. 7.5:1 on [brand].
  static const textOnBrand = Color(0xFFFFFFFF);

  /// Hairline borders. Deliberately faint: cards carry a soft shadow for
  /// depth, and the border is there so the edge survives sunlight, where a
  /// shadow washes out completely.
  static const border = Color(0xFFDCE7E3);

  // ----------------------------------------------------------------- brand
  /// Deep teal. Icons, links, selected state, the progress ring, active tab.
  static const brand = Color(0xFF075E63);

  /// The light end of the brand gradient — the top of a filled button, the
  /// bright side of the glow.
  static const brandLight = Color(0xFF0A7A80);

  /// The dark end. 9.4:1 on [background].
  static const brandDark = Color(0xFF04474B);

  /// Tinted brand background for selected chips, verified badges, soft fills.
  static const brandSoft = Color(0xFFDCEEEC);

  /// The coloured shadow under the three lit elements — the primary button,
  /// the quick-add button and the active tab. A coloured shadow is the
  /// difference between "raised" and "lit"; nothing else in the app gets one,
  /// which is what keeps those three special.
  static const brandGlow = Color(0x8C075E63);

  /// Neutral lift for cards and tiles. Every surface that is not one of the
  /// three lit elements uses this.
  static const shadow = Color(0x14142628);

  // ------------------------------------------------------------- icon wells
  // The square behind a module icon ([IconWell]): a deep teal well with a
  // bright glyph on it, blooming into a mint halo.
  //
  // The well is dark on purpose, and it took a wrong turn to find out why. It
  // began pale, with the deep brand icon on it and a glow painted on the
  // glyph's strokes — which cannot work, because light does not come off a
  // dark line on a pale ground. Every attempt to make that bloom visible only
  // fogged the square and washed the icon out. Inverting it gives the light
  // somewhere to fall: the glyph reads as *emitting* rather than printed, and
  // as a side effect the chip is far stronger in sunlight — 9.6:1 inside the
  // well against 6.3:1 for the pale version it replaced.
  /// The lit edge of the well, top-left. Glyph measures 5.8:1 here — the
  /// tightest point in the gradient, and the one that sets the floor.
  static const wellTop = Color(0xFF086A6F);

  /// The deep corner, bottom-right. 9.6:1.
  static const wellBottom = Color(0xFF04474B);

  /// The glyph drawn on the well. Near-white with the mint in it, so it reads
  /// as lit rather than as white-on-a-dark-chip.
  static const wellGlyph = Color(0xFFE4FAF4);

  /// The halo cast under the well. Mint, not black: a coloured shadow is the
  /// difference between "raised" and "lit".
  static const wellHalo = Color(0x592FBFA8);

  /// The aura on the glyph's own strokes — a blurred copy of the icon painted
  /// behind it, in the brand mark's mint.
  static const iconGlow = Color(0xCC7FD9C6);

  // ----------------------------------------------------------- progress bar
  // The day's progress is a light track with a deep segment and a knob of
  // light at its leading edge. A dark channel with a bright segment in it was
  // tried first and abandoned: it read well on its own, but it made the bar
  // the loudest object on a white card. The knob's glow uses [iconGlow] and
  // [wellHalo], like every other light in the app.

  // ------------------------------------------------------------------ sand
  // The amber family, kept under its old names. `sand` is a fill; `sandDeep`
  // is what draws on it.
  static const sand = Color(0xFFF5A300);
  static const sandSoft = Color(0xFFF8EEDC);

  /// Readable ink for the amber family. 5.2:1 on [sandSoft].
  static const sandDeep = Color(0xFF8A5A05);

  // -------------------------------------------------------------- semantic
  /// Real states only, never decoration.
  static const success = Color(0xFF15734B);
  static const warning = Color(0xFF8A5A05);
  static const error = Color(0xFFC2333E);
  static const info = Color(0xFF1C5878);

  /// Semantic colours as badge and banner backgrounds. Pre-computed rather
  /// than using `withValues` so they composite correctly over any surface.
  static const successSoft = Color(0xFFDAF0E2);
  static const warningSoft = Color(0xFFF8EEDC);
  static const errorSoft = Color(0xFFFBE9EA);
  static const infoSoft = Color(0xFFE1EBF3);

  // ------------------------------------------------------- fills, not inks
  /// Rating stars. Carries dark ink at 9.4:1; never a foreground itself.
  static const star = Color(0xFFFFB800);

  /// The bright mint of the brand mark's node. A fill.
  static const mint = Color(0xFF7FD9C6);

  // ----------------------------------------------------------------- misc
  /// Scrim behind modal sheets and dialogs.
  static const scrim = Color(0x66142628);

  /// Skeleton loading base and shimmer highlight.
  static const skeletonBase = Color(0xFFDFE9E6);
  static const skeletonHighlight = Color(0xFFEFF6F3);
}

/// Decoration used to draw from a four-family `ActionPalette` here — four
/// pale washes that tinted the quick-action chips in pairs. It is gone: the
/// module icons are now one lit green well (`GlowWell`), because the icon and
/// the label already say which module, and four washes competing with the
/// brand green cost the grid its coherence to say it a third time.
///
/// The rule that outlived it still holds: the semantic set — success, warning,
/// error, info — means a real state and is never borrowed to decorate a tile.
