import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's light. Two kinds, and they are not interchangeable.
///
/// The rule this encodes: **a deep fill glows, a pale fill does not.** Anything
/// carrying the thick brand green — a filled button, the active tab, a selected
/// day, a module's icon well — casts a coloured halo and lights its own glyph.
/// Anything pale keeps a plain neutral shadow, because light coming off a
/// near-white chip reads as a smudge rather than as light.
///
/// A coloured shadow is the difference between *raised* and *lit*, so it is
/// spent only where the fill has earned it. Once everything glows, nothing does.
abstract final class AppGlow {
  /// **Halo** — the light a filled surface casts on the page around it.
  ///
  /// Scales with the element: a 46pt well and a 56pt button want the same
  /// *proportion* of spill, not the same blur, or the small one looks fogged
  /// and the large one looks unlit. [ink] is the fill's own colour, so a green
  /// button spills green and an amber one spills amber.
  static List<BoxShadow> halo(Color ink, double size, {double strength = 1}) {
    return [
      BoxShadow(
        color: ink == AppColors.brand
            ? AppColors.wellHalo.withValues(
                alpha: AppColors.wellHalo.a * strength,
              )
            : ink.withValues(alpha: 0.35 * strength),
        blurRadius: size * 0.30,
        spreadRadius: -size * 0.065,
        offset: Offset(0, size * 0.11),
      ),
    ];
  }

  /// **Bloom** — the light coming off a glyph's own strokes, for
  /// `Icon(shadows:)` and `TextStyle(shadows:)`.
  ///
  /// One tight stop, hugging the strokes. It was two — a tight aura plus a
  /// wide falloff at 0.70 of the glyph — and on a 21pt mark in a 42pt chip the
  /// wide one is larger than the glyph itself, so it stopped reading as light
  /// coming off the strokes and started reading as the mark being out of
  /// focus. The review's words for it were that the white "is not clear
  /// white", which is exactly what a haze over white looks like.
  ///
  /// The tight stop is what the eye reads as emission; the wide one was only
  /// ever stopping the tight one from looking like an outline, and at this
  /// radius it does not.
  ///
  /// Only ever on a **dark** fill. On a pale one it fogs the surface and
  /// washes the mark out — that dead end is documented on [AppColors.wellTop].
  static List<Shadow> bloom(Color ink, double glyphSize) {
    final aura = ink == AppColors.brand
        ? AppColors.iconGlow
        : Color.lerp(ink, Colors.white, 0.55)!.withValues(alpha: 0.80);
    return [
      Shadow(
        color: aura.withValues(alpha: aura.a * 0.75),
        blurRadius: glyphSize * 0.22,
      ),
    ];
  }

  /// The gradient a deep fill is painted with — lightest where the light falls.
  ///
  /// Square fills take the default diagonal. A long thin one overrides it to
  /// run along its own length, so the light travels the bar instead of across
  /// its 12pt face, where a diagonal would be invisible.
  static LinearGradient fill(
    Color ink, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: ink == AppColors.brand
          ? const [AppColors.wellTop, AppColors.wellBottom]
          : [ink, Color.lerp(ink, Colors.black, 0.42)!],
    );
  }

  /// **Sheen** — the light catching the top lip of a filled control.
  ///
  /// Laid over [fill] as a second gradient: a whisper of white along the top
  /// edge, gone by 40% of the height. It is what separates a control that
  /// looks like glass catching light from one that looks like a flat block of
  /// colour, and it costs nothing — no extra layer, no shadow, no repaint.
  ///
  /// Only on controls tall enough to have a lip. On a 22pt badge the band
  /// covers most of the pill and reads as a gradient fault rather than light.
  static const sheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x2BFFFFFF), Color(0x00FFFFFF)],
    stops: [0, 0.42],
  );

  /// The mark drawn on [fill]: **pure white**.
  ///
  /// It used to be near-white with the ink's own hue lerped into it at 0.94,
  /// on the argument that a tinted glyph reads as lit rather than as
  /// white-on-a-dark-chip. At 42pt with the bloom over it, what it actually
  /// read as was a white that had gone slightly grey — the review asked for
  /// "clear white", and it was right: the tint and the haze were compounding.
  ///
  /// The direction of the old rule still holds and is now trivially satisfied:
  /// 0.88 put the tightest inks at 4.25:1 against the light end of their own
  /// well, 0.94 cleared 4.5:1, and white is the maximum available. The floor
  /// is still a test — `palette_contrast_test.dart` recomputes it.
  static Color glyphOn(Color ink) => Colors.white;
}
