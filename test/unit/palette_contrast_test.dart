import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/theme/app_colors.dart';
import 'package:pharmaconnect/core/theme/app_glow.dart';

/// The palette's floors, asserted.
///
/// Every ratio in `app_colors.dart`'s documentation was computed by hand at
/// design time, and hand-computed numbers rot the moment someone nudges a hex.
/// This recomputes them from the tokens themselves, so a value that drifts
/// below the floor fails the suite instead of shipping to a rep who reads the
/// screen in direct sun.
///
/// 4.5:1 is the AA floor for text. It is applied here to icons as well: a
/// module glyph is the only thing inside its chip, and if it washes out the
/// chip says nothing.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const floor = 4.5;

  group('module palette', () {
    for (final m in ModulePalette.values) {
      test('${m.name}: ink is readable on white, on the ground and on its tile',
          () {
        expect(contrast(m.ink, AppColors.surface), greaterThanOrEqualTo(floor),
            reason: '${m.name} label on a white card');
        expect(contrast(m.ink, AppColors.background),
            greaterThanOrEqualTo(floor),
            reason: '${m.name} ink on the page ground');
        expect(contrast(m.ink, m.tile), greaterThanOrEqualTo(floor),
            reason: '${m.name} label on its own tile');
      });

      test('${m.name}: the glyph survives the light end of its well', () {
        // The well is a gradient from the ink to a darkened copy. Its *light*
        // end is the tight one — that is the whole reason the gradient runs
        // deep-to-deeper rather than from a mid-tone fill.
        expect(contrast(AppGlow.glyphOn(m.ink), m.ink),
            greaterThanOrEqualTo(floor),
            reason: '${m.name} glyph at the top of its well');
      });
    }

    test('the six hues are distinguishable from one another', () {
      // Not a contrast rule — a separation one. Two modules whose inks are
      // within a few points of each other are two tiles a rep cannot tell
      // apart at arm's length, which is the failure mode that killed the
      // previous multi-colour palette.
      final inks = ModulePalette.values.map((m) => m.ink).toList();
      for (var i = 0; i < inks.length; i++) {
        for (var j = i + 1; j < inks.length; j++) {
          final delta = (_luminance(inks[i]) - _luminance(inks[j])).abs();
          final hueApart = (inks[i].r - inks[j].r).abs() +
              (inks[i].g - inks[j].g).abs() +
              (inks[i].b - inks[j].b).abs();
          expect(delta > 0.02 || hueApart > 0.35, isTrue,
              reason: '${ModulePalette.values[i].name} and '
                  '${ModulePalette.values[j].name} are too close to separate');
        }
      }
    });
  });

  group('game tiers', () {
    for (final t in GameTier.values) {
      test('${t.name}: its label is readable on its own pill', () {
        expect(contrast(t.ink, t.soft), greaterThanOrEqualTo(floor));
        expect(contrast(t.ink, AppColors.surface), greaterThanOrEqualTo(floor));
      });
    }

    test('the ladder climbs in the order the rungs are declared', () {
      expect(GameTier.of(0), GameTier.started);
      expect(GameTier.of(49.9), GameTier.started);
      expect(GameTier.of(50), GameTier.onPace);
      expect(GameTier.of(74.9), GameTier.onPace);
      expect(GameTier.of(75), GameTier.ahead);
      expect(GameTier.of(99.9), GameTier.ahead);
      expect(GameTier.of(100), GameTier.met);
      // Over-performance is the same rung, not a fifth one.
      expect(GameTier.of(250), GameTier.met);
    });
  });

  group('chrome', () {
    test('body and secondary text clear the floor on ground and card', () {
      for (final ground in [AppColors.background, AppColors.surface]) {
        expect(contrast(AppColors.textPrimary, ground), greaterThanOrEqualTo(7));
        expect(
            contrast(AppColors.textSecondary, ground), greaterThanOrEqualTo(floor));
      }
    });

    test('white sits on every brand fill', () {
      for (final fill in [AppColors.brand, AppColors.brandDark]) {
        expect(contrast(AppColors.textOnBrand, fill),
            greaterThanOrEqualTo(floor));
      }
    });

    test('semantic inks are readable on their own soft backgrounds', () {
      // A list of pairs, not a map: Color has no primitive equality, so a
      // const map keyed by one does not compile.
      const pairs = [
        (AppColors.success, AppColors.successSoft),
        (AppColors.warning, AppColors.warningSoft),
        (AppColors.error, AppColors.errorSoft),
        (AppColors.info, AppColors.infoSoft),
      ];
      for (final (ink, soft) in pairs) {
        expect(contrast(ink, soft), greaterThanOrEqualTo(floor));
      }
    });

    test('a white card still separates from the ground', () {
      // The reason the ground is not #FFFFFF. Below about 1.04 the card stops
      // reading as a card.
      expect(contrast(AppColors.surface, AppColors.background),
          greaterThan(1.04));
    });

    test('fills are never mistaken for foregrounds', () {
      // `sand` and `star` exist to be sat on, not read. If either ever clears
      // the floor on white someone has quietly redefined them as inks.
      for (final fill in [AppColors.sand, AppColors.star]) {
        expect(contrast(fill, AppColors.surface), lessThan(floor));
      }
      expect(contrast(AppColors.sandDeep, AppColors.sandSoft),
          greaterThanOrEqualTo(floor));
    });
  });

  group('the neutral ramp', () {
    test('it steps monotonically from lightest to darkest', () {
      // A ramp whose steps are not ordered is not a ramp — a designer reaching
      // for "one step darker" would get something lighter.
      const ramp = [
        AppColors.grey50,
        AppColors.grey100,
        AppColors.grey200,
        AppColors.grey300,
        AppColors.grey400,
        AppColors.grey500,
        AppColors.grey600,
        AppColors.grey700,
        AppColors.grey800,
        AppColors.grey900,
      ];

      for (var i = 1; i < ramp.length; i++) {
        expect(_luminance(ramp[i]), lessThan(_luminance(ramp[i - 1])),
            reason: 'step $i is not darker than step ${i - 1}');
      }
    });

    test('the steps that carry text clear their floors', () {
      // 600 is secondary text, 900 is body. 500 is the floor for anything a
      // reader is not required to read, and must stay under the text floor so
      // nobody reaches for it as an ink.
      expect(contrast(AppColors.grey900, AppColors.surface),
          greaterThanOrEqualTo(7));
      expect(contrast(AppColors.grey600, AppColors.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.grey500, AppColors.surface), lessThan(4.5));
    });

    test('the calendar palette is four colours that cannot be confused', () {
      // Every calendar in the app draws from this set and nothing else. They
      // had grown to six hues between them, with the same colour meaning
      // different things on different screens.
      const set = {
        'planned': AppColors.calendarPlanned,
        'done': AppColors.calendarDone,
        'off': AppColors.calendarOff,
        'problem': AppColors.calendarProblem,
      };

      for (final entry in set.entries) {
        expect(contrast(entry.value, AppColors.surface),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} carries the day number and its own dot');
      }

      // And each has to be told from the others at 5pt across, which is the
      // size of the dot. Channel distance, not luminance: two hues can share a
      // luminance and still be obviously different.
      final names = set.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final a = set[names[i]]!;
          final b = set[names[j]]!;
          final delta = (_luminance(a) - _luminance(b)).abs();
          final hueApart = (a.r - b.r).abs() +
              (a.g - b.g).abs() +
              (a.b - b.b).abs();
          expect(delta > 0.02 || hueApart > 0.35, isTrue,
              reason: '${names[i]} and ${names[j]} are too close to separate');
        }
      }
    });

    test('the named tokens are the ramp, not a second set of values', () {
      // The whole point: one spine. If these drift apart the app has two
      // greys that are nearly the same and no rule for choosing between them.
      expect(AppColors.textPrimary, AppColors.grey900);
      expect(AppColors.textSecondary, AppColors.grey600);
      expect(AppColors.surfaceSecondary, AppColors.grey100);
    });
  });
}

