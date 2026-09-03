import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's motion, in one place.
///
/// The rule: **content arrives, it does not appear.** Before this the app
/// swapped a skeleton for real data in a single frame in sixty-eight places,
/// which is the largest single difference between this and the apps it is
/// measured against — those are defined by continuous motion, not by their
/// colours.
///
/// Everything here is fast. 180–260ms is long enough to be read as movement
/// and short enough that a rep logging a call in fifteen seconds never waits
/// for it. Motion that draws attention to itself is the failure mode: this is
/// meant to make the app feel *quick*, not animated.
abstract final class AppMotion {
  /// A press, a tint, a checkbox — anything the finger is already on.
  static const fast = Duration(milliseconds: 120);

  /// The default: content arriving, a sheet settling, a bar filling.
  static const normal = Duration(milliseconds: 220);

  /// A number counting up, a progress bar crossing the card.
  static const slow = Duration(milliseconds: 420);

  /// Decelerating. Things enter quickly and settle — never linear, which reads
  /// as mechanical, and never bouncy, which reads as a toy.
  static const curve = Curves.easeOutCubic;

  /// For something leaving, which should not linger.
  static const exitCurve = Curves.easeInCubic;

  /// How far a card lifts as it arrives. Small on purpose — a long slide is a
  /// transition, and this is only meant to say "this is new".
  static const rise = 12.0;

  /// The gap between consecutive items in a staggered list.
  ///
  /// Capped in [staggerFor]: at 40ms, the twentieth row would wait 800ms, and
  /// a list that keeps animating after the reader has started reading is worse
  /// than one that never animated.
  static const stagger = Duration(milliseconds: 40);

  static Duration staggerFor(int index) => Duration(
    milliseconds: (stagger.inMilliseconds * index).clamp(0, 240),
  );
}

/// The physical half of the same idea.
///
/// A tick you feel on selection is most of why an expensive app feels
/// expensive, and the app had none at all. Kept to three moments so it stays
/// meaningful: choosing something, finishing something, and failing.
abstract final class AppHaptics {
  /// A tab, a chip, an option in a sheet. The lightest tick there is.
  static void selection() => HapticFeedback.selectionClick();

  /// A record saved, a visit completed.
  static void success() => HapticFeedback.mediumImpact();

  /// A refused action or a failed save. Never used for validation messages —
  /// a form that buzzes as you fill it in is punishing, not premium.
  static void failure() => HapticFeedback.heavyImpact();
}
