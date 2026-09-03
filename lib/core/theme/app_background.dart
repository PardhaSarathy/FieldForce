import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The page ground for every screen in the app.
///
/// Mounted once, in `MaterialApp.builder`, so it sits behind the whole
/// navigator: every route's Scaffold is transparent and this shows through.
/// That is why no screen has to know about it, and why a pushed route does not
/// briefly flash a different colour on the way in.
///
/// Two layers: a vertical wash from [AppColors.backgroundTop] down to
/// [AppColors.backgroundBottom], and a soft radial highlight in the top right.
/// The highlight is the part that matters — a plain linear ramp still reads as
/// flat, and it is the diagonal fall of light that makes the ground look like a
/// surface rather than a fill.
///
/// On a white app the wash is deliberately faint — the darkest stop is 1.1:1
/// off the lightest. It is not there to be seen; it is there so the page does
/// not read as a flat sheet of paper behind the cards.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundTop,
            AppColors.backgroundMid,
            AppColors.backgroundBottom,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.85, -0.95),
            radius: 1.15,
            colors: [AppColors.backgroundGlow, Color(0x00FFFFFF)],
            stops: [0.0, 0.72],
          ),
        ),
        child: child,
      ),
    );
  }
}
