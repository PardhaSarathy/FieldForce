import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/theme/app_colors.dart';
import 'package:pharmaconnect/core/theme/app_theme.dart';
import 'package:pharmaconnect/shared/widgets/primitives.dart';
import 'package:pharmaconnect/core/theme/app_motion.dart';
import 'package:pharmaconnect/shared/widgets/motion.dart';
import 'package:pharmaconnect/shared/widgets/states.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
      );

  group('a spinner never flashes', () {
    testWidgets('nothing is drawn for the first 300ms', (tester) async {
      // Most reads in this app resolve in ~260ms. A spinner that appears and
      // vanishes inside a third of a second reads as a stutter, not progress.
      await pump(tester, const LoadingState(message: 'Loading'));

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Loading'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsOneWidget);
    });
  });

  group('avatar colour', () {
    Color colourOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .descendant(of: find.byType(AppAvatar), matching: find.byType(Container))
            .first,
      );
      return ((container.decoration!) as BoxDecoration).color!;
    }

    testWidgets('the same person is the same colour every time',
        (tester) async {
      await pump(tester, const AppAvatar(name: 'Dr. Anjali Sharma'));
      final first = colourOf(tester);

      await pump(tester, const SizedBox());
      await pump(tester, const AppAvatar(name: 'Dr. Anjali Sharma'));

      expect(colourOf(tester), first,
          reason: 'a client must not change colour between screens');
    });

    testWidgets('different people are not all one colour', (tester) async {
      final seen = <Color>{};
      for (final name in [
        'Dr. Anjali Sharma',
        'Wellness Forever',
        'Mahavir Pharma Distributors',
        'Dr. Meera Joshi',
        'Apollo Clinic',
        'Dr. Suresh Bhatt',
      ]) {
        await pump(tester, const SizedBox());
        await pump(tester, AppAvatar(name: name));
        seen.add(colourOf(tester));
      }

      // The point of deriving the hue from the name: a list of people is a
      // spread of colour, not a column of identical discs.
      expect(seen.length, greaterThan(1));
    });

    testWidgets('an explicit colour still wins', (tester) async {
      await pump(
        tester,
        const AppAvatar(name: 'Anyone', backgroundColor: AppColors.brandSoft),
      );
      expect(colourOf(tester), AppColors.brandSoft);
    });
  });

  group('motion', () {
    testWidgets('content arrives — it is not drawn in place', (tester) async {
      await pump(tester, const Arrive(child: Text('Hello')));

      // First frame: present in the tree, but transparent and displaced.
      await tester.pump();
      final start = tester.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(start, lessThan(0.5));

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('it plays once — a rebuild does not replay it', (tester) async {
      await pump(tester, const Arrive(child: Text('Hello')));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0);

      // Same widget, rebuilt: scrolling a list or changing a filter must not
      // re-animate rows the reader is already looking at.
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0);
    });

    testWidgets('a stagger is capped so late rows are not left behind',
        (tester) async {
      // Row 6 onwards all share the cap: a twentieth row waiting 800ms would
      // still be animating long after the reader started reading row one.
      expect(AppMotion.staggerFor(0), Duration.zero);
      expect(AppMotion.staggerFor(3), const Duration(milliseconds: 120));
      expect(AppMotion.staggerFor(6), const Duration(milliseconds: 240));
      expect(AppMotion.staggerFor(50), const Duration(milliseconds: 240));
    });

    testWidgets('a press shrinks the card', (tester) async {
      await pump(
        tester,
        Pressable(
          onTap: () {},
          // Painted, not an empty SizedBox: a box with no child does not hit
          // test, so the press would never reach the detector.
          child: Container(width: 100, height: 100, color: AppColors.brand),
        ),
      );

      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Container)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        lessThan(1.0),
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
    });
  });
}
