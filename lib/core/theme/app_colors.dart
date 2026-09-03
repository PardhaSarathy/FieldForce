import 'package:flutter/material.dart';

/// Mr Sales colour tokens — Dr.Swift blue and five accents, on white.
///
/// The app is white. The ground is a hair off it ([background], 1.08:1 against
/// a card) because a white card on a pure-white page is 1.0:1 — literally
/// invisible — and the card stack on Home is the product. That single ratio is
/// the whole reason the ground is not `#FFFFFF`.
///
/// The values are **Dr.Swift's own**, taken from the brand sheet published as
/// CSS custom properties on drswift.in — not sampled from screenshots and not
/// invented. Each token below names the variable it came from. Where the site
/// publishes a separate *text* variant of a colour (`--color-green-bright`
/// vs `--color-green-bright-text`) this uses the text one, because that is the
/// variant Dr.Swift themselves darkened to be readable.
///
/// Exactly one hue is off-sheet, and [ModulePalette.hr] documents why.
///
/// Colour arrives through the **modules**, not the chrome: each of the six
/// things a rep opens daily owns a hue, and carries it as a pastel tile, a
/// saturated chip and a label in its own ink. The chrome — buttons, the active
/// tab, progress — stays [brand] blue, so the app has one action colour and
/// six identity colours rather than seven of each.
///
/// Everything here is measured. A rep reads these screens standing in the
/// street at midday, so anything carrying meaning clears **4.5:1** against the
/// surface behind it; glare eats real contrast long before it eats the number.
/// `test/unit/palette_contrast_test.dart` asserts the floors, so a value that
/// drifts fails the suite rather than shipping.
///
/// Do not introduce raw `Color(0x...)` literals anywhere else in the
/// application — add a token here instead, so the palette stays auditable and
/// a future dark theme has a single place to swap.
///
/// Three rules the values encode:
///
///  * **A fill is not a foreground.** [sand] and [star] are light enough to
///    carry dark ink on top of them and nothing else; as an icon or a word they
///    measure under 3:1. Each has a paired deep ink for that job.
///  * **A module hue and a semantic colour may share a value.** [ModulePalette
///    .travel] is [brand] green and [ModulePalette.clients] is [warning] amber.
///    They stay legible because a badge is a pill with a word in it and a tile
///    is a chip with a label under it — never because of hue.
///  * **State is never colour alone.** Every badge and every tier carries text.
abstract final class AppColors {
  // ------------------------------------------------------------- neutrals
  // A stepped grey ramp, tinted a few degrees toward the brand blue so it
  // never looks muddy beside it.
  //
  // The app ran on six neutrals — a ground, a surface, one recessed fill, a
  // border and two inks — which is why colour was doing work that hierarchy
  // should do. Apple's restraint is not the absence of colour, it is having
  // enough greys that colour is never needed for structure. Every token below
  // is one of these, so the ramp is the palette's spine rather than a second
  // set of values to keep in step.
  static const grey50 = Color(0xFFF9FAFC);
  static const grey100 = Color(0xFFF1F4F8);
  static const grey200 = Color(0xFFE6EAF1);
  static const grey300 = Color(0xFFD5DBE6);

  /// 2.0:1 — a disabled glyph, a divider that must be seen. Never text.
  static const grey400 = Color(0xFFAFB8C8);

  /// 3.1:1 — placeholder text and inactive icons, the floor for anything a
  /// reader is not required to read.
  static const grey500 = Color(0xFF8792A6);

  /// 5.2:1 — secondary text. Dr.Swift's own `--color-muted`.
  static const grey600 = Color(0xFF636E81);

  /// 7.6:1.
  static const grey700 = Color(0xFF4A5468);

  /// 11.9:1.
  static const grey800 = Color(0xFF2E3749);

  /// 16.3:1 — body text. Dr.Swift's own `--color-ink`.
  static const grey900 = Color(0xFF162033);

  // ---------------------------------------------------------------- surfaces
  /// Page ground. Neutral, and barely off white — see the class doc.
  static const background = Color(0xFFF6F8FB); // --color-soft

  /// Cards, sheets, elevated content.
  static const surface = Color(0xFFFFFFFF);

  /// Recessed rows, disabled fields, subtle fills.
  static const surfaceSecondary = grey100;

  /// The ground is a wash, not a flat fill — but a very quiet one now.
  ///
  /// On the old green ground the wash did heavy lifting. On white it only has
  /// to keep the page from looking like paper: the tint gathers under the app
  /// bar and gives way to pure white at the thumb, so the screen has somewhere
  /// to recede to. Body text holds at 16.1:1 against the darkest stop and
  /// 17.9:1 against the lightest, so nothing changes as the eye travels down.
  static const backgroundTop = Color(0xFFEEF2F9);
  static const backgroundMid = Color(0xFFF6F8FB);
  static const backgroundBottom = Color(0xFFFFFFFF);

  /// A soft highlight over the wash, as if light fell from the top right.
  static const backgroundGlow = Color(0x66FFFFFF);

  // ------------------------------------------------------------------- ink
  /// Body text. Dr.Swift's own ink. 15.1:1 on the ground, 16.3:1 on a card.
  static const textPrimary = grey900;

  /// Secondary text — captions, metadata, helper lines. Dr.Swift's own.
  /// 4.8:1 on the ground, 5.2:1 on a card.
  ///
  /// Secondary text is half the words on a list screen, so it is held well
  /// above the AA floor rather than at it.
  static const textSecondary = grey600;

  /// Text on top of [brand] fills. 5.9:1 on [brand].
  static const textOnBrand = Color(0xFFFFFFFF);

  /// Hairline borders. Faint: cards carry a soft shadow for depth, and the
  /// border is there so the edge survives sunlight, where a shadow washes out.
  static const border = Color(0xFFDCE3EE); // --color-line, between grey200 and grey300

  // ----------------------------------------------------------------- brand
  /// The action colour. Primary buttons, the active tab, the quick-add button,
  /// progress. Deliberately *not* one of the six module hues' jobs: the app
  /// has one colour that means "press this".
  ///
  /// Dr.Swift's primary, unchanged. White sits on it at 5.9:1, so it carries
  /// a filled button without help.
  static const brand = Color(0xFF1E5BD7); // --color-blue

  /// The light end of the brand gradient. Not the site's own lighter blue,
  /// which measures 4.47:1 — a hair under the floor, and a button's label sits
  /// on the lightest point of its gradient.
  static const brandLight = Color(0xFF2C68DD);

  /// The dark end.
  static const brandDark = Color(0xFF123F9B); // --color-blue-dark

  /// Tinted brand background for selected chips, verified badges, soft fills.
  static const brandSoft = Color(0xFFEDF4FF); // --color-blue-soft

  /// The coloured shadow under a lit brand element.
  static const brandGlow = Color(0x8C1E5BD7);

  /// Neutral lift for cards and tiles.
  ///
  /// Two layers make the lift, and they are doing different jobs: a tight
  /// 1pt contact shadow that says the card is resting on something, and a wide
  /// soft one that says how far above it. Raised from 0x14 after the card
  /// stack read as flat on a phone in daylight — the review said "increase the
  /// background shadow" three times about three different cards, which is a
  /// verdict on the elevation, not on any one of them.
  static const shadow = Color(0x1F111C2E);

  /// The wide ambient layer. Lighter than [shadow] because it is spread over
  /// four times the area; at the same alpha it turns the ground grey.
  static const shadowAmbient = Color(0x22111C2E);

  // -------------------------------------------------------------- progress
  /// The light end of the day bar's fill.
  ///
  /// The bar ramps light → deep across whatever it has filled, at 5% as much
  /// as at 100%, so the ramp itself reads as travel. That needs a genuinely
  /// light start — [brandLight] is a hair off [brand] and the ramp vanished —
  /// so this is brand lifted halfway to white. It is a fill and carries no
  /// text, so it has no contrast floor of its own.
  static const progressStart = Color(0xFF6E9BE8);

  /// The knob at the leading edge. Green, not brand: the bar says how far, the
  /// knob says *moving*, and a green light at the front of a blue bar is the
  /// one place in the app where a second colour earns its place on a control.
  /// A white ring keeps it legible over both the deep fill and the light track.
  static const progressKnob = Color(0xFF17A34A);

  // ------------------------------------------------------------- icon wells
  // The well behind an icon: a gradient from the ink to a darkened copy of it,
  // carrying a near-white glyph, blooming into a halo of its own colour.
  //
  // The gradient runs deep → deeper on purpose. The obvious version — a light
  // mid-tone fill with a white glyph, which is what most mockups draw — fails
  // badly: white on a mid amber measures 2.2:1 and on a mid lime 2.0:1. Anchor
  // the *light* end of the gradient at the ink instead and the floor lands at
  // the top of the well, where every hue below clears 4.5:1.
  //
  // These four are the brand's own values; [AppGlow] derives the same set for
  // any other ink, so a module well and a warning well are built identically.
  /// The lit edge of the brand well, top-left. Glyph measures 5.4:1 here.
  static const wellTop = Color(0xFF1E5BD7);

  /// The deep corner, bottom-right.
  static const wellBottom = Color(0xFF123F9B);

  /// The glyph drawn on the well. Pure white — see [AppGlow.glyphOn] for why
  /// the tinted near-white it used to be was making the mark look grey.
  static const wellGlyph = Color(0xFFFFFFFF);

  /// The halo cast under the well. Coloured, not black: that is the difference
  /// between "raised" and "lit".
  static const wellHalo = Color(0x593A72E3);

  /// The aura on the glyph's own strokes.
  static const iconGlow = Color(0xCC8FB8F5);

  // ------------------------------------------------------------------ sand
  // The amber family. `sand` is a fill; `sandDeep` is what draws on it.
  static const sand = Color(0xFFF5A300); // --color-hero-yellow
  static const sandSoft = Color(0xFFFEF5E9);

  /// Readable ink for the amber family. 4.65:1 on [sandSoft] — the wash was
  /// lightened to get there, because amber is the hue with the least room.
  static const sandDeep = Color(0xFFB45309);

  // -------------------------------------------------------------- semantic
  /// Real states only, and all four are Dr.Swift's own.
  static const success = Color(0xFF267C42); // --color-green-bright-text
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFB42318); // --color-error
  static const info = Color(0xFF147885); // --color-teal-text

  /// Semantic colours as badge and banner backgrounds. Pre-computed rather
  /// than using `withValues` so they composite correctly over any surface.
  static const successSoft = Color(0xFFE7F5EB);
  static const warningSoft = Color(0xFFFEF5E9);
  static const errorSoft = Color(0xFFFFF4F2); // --color-error-soft
  static const infoSoft = Color(0xFFE3F5F7);

  // ------------------------------------------------------- fills, not inks
  /// Rating stars. Carries dark ink; never a foreground itself. `--color-star`.
  static const star = Color(0xFFFFB800);

  /// `--color-mint`. A fill.
  static const mint = Color(0xFF7ECDC0);

  // ----------------------------------------------------------------- misc
  /// Scrim behind modal sheets and dialogs.
  static const scrim = Color(0x66162033);

  /// Skeleton loading base and shimmer highlight.
  static const skeletonBase = grey200;
  static const skeletonHighlight = grey50;
}

/// The six module identities.
///
/// A four-family palette lived here once and was deleted, on the argument that
/// the icon and the word already say which module and the extra colour cost
/// the grid its coherence. That was right for four pale washes fighting one
/// brand green, and wrong as a general rule: with the tile, the chip *and* the
/// label all carrying one hue, a module reads as a place rather than as a row
/// in a list, and six of them read as a set. Do not collapse this to one hue
/// again without re-reading why it came back.
///
/// Each entry carries only the two values that cannot be computed. The well's
/// dark end, its glyph and its halo are all derived from [ink] by [AppGlow],
/// so a module cannot drift out of step with itself.
enum ModulePalette {
  /// Dr.Swift blue — the brand's own colour and its own wash, so the module a
  /// rep opens first is the one wearing the company's colour. 5.9:1 / 5.4:1.
  dayPlan(Color(0xFF1E5BD7), Color(0xFFEDF4FF)),

  /// `--color-hero-purple`, unchanged — it already cleared the floor.
  /// 9.5:1 / 8.1:1.
  activity(Color(0xFF5A2D8F), Color(0xFFF2EAF8)),

  /// The site's `--abnormal` orange, darkened until a white glyph holds.
  /// 5.2:1 / 4.55:1.
  ///
  /// The obvious pick was `--color-hero-yellow`, and gold cannot work: white
  /// on it measures 1.9:1, and pushing gold deep enough to be safe turns it
  /// brown — which this slot was at first, and it read as mud beside five
  /// saturated hues. Orange keeps the warmth and the margin.
  clients(Color(0xFFC2410C), Color(0xFFFEEDE4)),

  /// `--color-green-bright-text` — Dr.Swift's own readable green, which is
  /// what they use where `--color-green-bright` (3.7:1) would be unreadable.
  /// 5.2:1 / 4.6:1. Shares its value with [AppColors.success]; see the note on
  /// [AppColors].
  travel(Color(0xFF267C42), Color(0xFFE7F5EB)),

  /// Indigo. 7.9:1 / 6.8:1.
  ///
  /// **The one colour in this file that is not Dr.Swift's.**
  ///
  /// `--color-teal-text` was the on-brand choice and cannot be used: against
  /// [travel]'s green it fails the separation check in
  /// `palette_contrast_test.dart` (dL 0.008, channel distance 0.35), which
  /// means two module tiles a rep cannot tell apart at arm's length. One hue
  /// off the sheet beats two modules that look identical. The teal is not
  /// wasted — it is [AppColors.info] and [GameTier.met].
  hr(Color(0xFF4338CA), Color(0xFFECEDFD)),

  /// `--concern-accent`. 5.5:1 / 4.8:1.
  sales(Color(0xFFC0267A), Color(0xFFFDEAF3));

  const ModulePalette(this.ink, this.tile);

  /// The chip's fill and the label's colour. Clears 4.5:1 on white, on the
  /// page ground, and on its own [tile].
  final Color ink;

  /// The pastel card the chip and label sit on.
  final Color tile;
}

/// How a target is going, as a ladder that climbs.
///
/// The old mapping painted anything under half of target in **error red**,
/// which tells a rep at 11am that their morning is a failure. A ladder reads
/// as progress: every rung is somewhere to be rather than a verdict, and the
/// top two are worth reaching. The label is not optional — state is never
/// colour alone, so the word ships with the colour everywhere this is used.
enum GameTier {
  /// Under half. Slate, not red: early in the day this is simply *early*.
  started('Getting started', Color(0xFF475569), Color(0xFFEEF1F5)),

  /// Half to three quarters.
  onPace('On pace', AppColors.brand, AppColors.brandSoft),

  /// Three quarters to target. Gold.
  ahead('Ahead', Color(0xFFA16207), Color(0xFFFDF6E4)),

  /// Target met or beaten.
  met('Target met', Color(0xFF147885), Color(0xFFE3F5F7));

  const GameTier(this.label, this.ink, this.soft);

  final String label;
  final Color ink;
  final Color soft;

  /// The rung a percentage lands on. Over-performance stays on the top rung —
  /// 140% is not a different state from 100%, it is the same one, louder.
  static GameTier of(double percent) {
    if (percent >= 100) return met;
    if (percent >= 75) return ahead;
    if (percent >= 50) return onPace;
    return started;
  }
}
