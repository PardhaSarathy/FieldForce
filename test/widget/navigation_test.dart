import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/providers/app_providers.dart';
import 'package:pharmaconnect/core/routing/app_router.dart';
import 'package:pharmaconnect/core/theme/app_theme.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/models/organization.dart';
import 'package:pharmaconnect/shared/widgets/primitives.dart';

/// Navigation tests that drive the real router.
///
/// The smoke suite renders screens in isolation, which cannot catch the one
/// mistake this app's shell is prone to: a tab or a menu item that resolves to
/// a branch the indexed stack is not showing. Nothing throws, nothing is
/// logged — the tap simply does nothing, and it is only visible by looking.
/// So these tests tap, then assert on what is on screen.
void main() {
  final store = MockStore.instance;

  Session sessionFor(String code) {
    final employee =
        store.seed.employees.firstWhere((e) => e.employeeCode == code);
    return Session(employee: employee, loginAt: DateTime(2026, 8, 26));
  }

  /// Drains the mock repositories' chained latency without tripping the
  /// binding's pending-timer check.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Boots the real app, already signed in as [code].
  /// [size] defaults to a phone. Tests that tap something far down the page
  /// pass a taller viewport: scrolling a target into the *viewport* is not
  /// enough when the bottom bar sits over the last 60pt of it, and a tap that
  /// lands on the bar instead is silently a no-op.
  Future<void> pumpApp(
    WidgetTester tester, {
    String code = 'MR1001',
    Size size = const Size(420, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_TestAuthController.new),
      ],
    );
    addTearDown(container.dispose);

    (container.read(authControllerProvider.notifier) as _TestAuthController)
        .seed(sessionFor(code));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await settle(tester);
  }

  group('a field rep can reach every tab', () {
    testWidgets('the bar shows Home, To-Do, Resources and Reports',
        (tester) async {
      await pumpApp(tester);

      // Only the selected tab carries its label — the rest are icon-only, so
      // the icons are what identify them.
      expect(find.byIcon(Icons.home), findsOneWidget); // active
      for (final icon in [
        Icons.checklist_outlined,
        Icons.library_books_outlined,
        Icons.bar_chart_outlined,
      ]) {
        expect(find.byIcon(icon), findsOneWidget, reason: '$icon tab missing');
      }
      // Activity moved off the bar for a rep.
      expect(find.byIcon(Icons.event_note_outlined), findsNothing);
    });

    testWidgets('the selected tab is the only one that carries a label',
        (tester) async {
      await pumpApp(tester);

      // The bar labels the tab you are on and lets the other three be icons.
      // Five equal labels compete; this says where you are without being read.
      expect(find.text('Home'), findsOneWidget);
      for (final label in ['To-Do', 'Resources', 'Reports']) {
        expect(find.text(label), findsNothing,
            reason: '$label should be icon-only while unselected');
      }
    });

    testWidgets('each tab opens its own screen', (tester) async {
      await pumpApp(tester);

      // The tab label is the only reliable handle: the destination screens
      // have their own titles, which is exactly what we want to assert on.
      Future<void> tapTab(IconData icon) async {
        await tester.tap(find.byIcon(icon).last);
        await settle(tester);
      }

      await tapTab(Icons.checklist_outlined);
      expect(find.text('To-Do'), findsWidgets);

      await tapTab(Icons.library_books_outlined);
      expect(find.text('All'), findsWidgets);
      expect(find.text('All'), findsWidgets); // the resource category filter

      await tapTab(Icons.bar_chart_outlined);
      expect(find.text('Reports'), findsWidgets);

      await tapTab(Icons.home_outlined);
      expect(find.textContaining('Good'), findsOneWidget);
    });
  });

  group('quick actions open real screens', () {
    testWidgets('My Day Activity reaches the activity list', (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.text('My Activity'));
      await settle(tester);

      // Activity is a shell branch a rep has no tab for; tapping the tile has
      // to switch branches, not push onto the one already showing.
      expect(find.text('My Activity'), findsOneWidget);
    });

    testWidgets('My Activity offers Add New Activity, and it opens the form',
        (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.text('My Activity'));
      await settle(tester);
      expect(find.text('Add New Activity'), findsOneWidget);

      await tester.tap(find.text('Add New Activity'));
      await settle(tester);

      // It opens on the client question. The three steps — Location, Call
      // report, Review — only mean anything once there is a client, so the
      // picker comes before the step header rather than being step one.
      expect(find.text('Who did you call on?'), findsOneWidget);
      expect(find.text('Client'), findsWidgets);
      // The step header is not up yet, and neither is Submit: there is
      // nothing to measure a geo-fence against until a client is chosen.
      expect(find.text('Call report'), findsNothing);
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('My Day Plan opens the intimation form', (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.text('My Day Plan'));
      await settle(tester);

      // The day plan declares where you will be — it is not the activity form
      // and holds no client or visit purpose.
      expect(find.text('Work type'), findsOneWidget);
      expect(find.text('HQ'), findsOneWidget);
      expect(find.text('Cluster'), findsOneWidget);
      expect(find.text('Remarks'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);

      expect(find.text('Visit purpose'), findsNothing);
    });

    testWidgets('Sales opens, pushed above the shell', (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.text('Sales'));
      await settle(tester);

      // Business is pushed above the shell now, so Home is gone from view and
      // the user has a back button rather than a tab to return by.
      expect(find.textContaining('Good'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('travel forks into plans and expenses', () {
    testWidgets('the Travel tile offers both, and each opens',
        (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.text('Travel'));
      await settle(tester);
      expect(find.text('Tour Plan'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);

      // The name must survive the tap. It did not: the tile said Tour Plan and
      // the screen it opened was headed "Travel Plans", which reads as having
      // landed somewhere else.
      await tester.tap(find.text('Tour Plan'));
      await settle(tester);
      expect(find.text('Tour Plan'), findsWidgets);
      expect(find.text('Travel Plans'), findsNothing);
    });
  });

  group('claiming a day', () {
    testWidgets('Travel → Expenses opens the month of declared days',
        (tester) async {
      await pumpApp(tester, size: const Size(430, 1800));

      await tester.tap(find.text('Travel'));
      await settle(tester);
      await tester.tap(find.text('Expenses'));
      await settle(tester);

      expect(find.text('Expenses'), findsWidgets);
      // The month, not a flat list of receipts.
      expect(find.textContaining('claimed this month'), findsOneWidget);
      expect(find.textContaining('No cut-off'), findsOneWidget);
    });

    testWidgets('a day row opens that day, addressed by its date',
        (tester) async {
      // The row pushes `/expenses/day/<iso>`, and the screen loads the day
      // from the date rather than from anything handed down the stack — so a
      // deep link lands on the same screen a tap does.
      await pumpApp(tester, size: const Size(430, 2400));

      await tester.tap(find.text('Travel'));
      await settle(tester);
      await tester.tap(find.text('Expenses'));
      await settle(tester);

      final row = find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_DayRow')
          .first;
      await tester.tap(row, warnIfMissed: false);
      await settle(tester);

      expect(find.textContaining('Claim for'), findsOneWidget);
      expect(find.text('Territory'), findsOneWidget);
      expect(find.text('Add to claim'), findsOneWidget);
    });

    testWidgets('the + sheet lands on the month, not a blank form',
        (tester) async {
      // A claim hangs off a declared day, so "add an expense" has to start by
      // choosing which day — and that list is the month screen. The sheet
      // used to open a standalone form that could write an orphan record.
      await pumpApp(tester, size: const Size(430, 1800));

      await tester.tap(find.byTooltip('Add'));
      await settle(tester);
      expect(find.text('Claim a day'), findsOneWidget);

      await tester.tap(find.text('Claim a day'));
      await settle(tester);
      expect(find.textContaining('claimed this month'), findsOneWidget);
    });
  });

  group('the Home header', () {
    testWidgets('carries notifications and chat, not search or profile',
        (tester) async {
      await pumpApp(tester);

      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byTooltip('Chat'), findsOneWidget);
      // By tooltip, not by icon: these name the *controls* in the header. A
      // global icon search fails the moment an unrelated tile on the page
      // happens to use the same glyph — which is exactly what a person icon
      // in the quick-action grid did to the old version of this test.
      expect(find.byTooltip('Search'), findsNothing);
      // Profile moved to the side menu, where tapping your photo opens it.
      expect(find.byTooltip('Profile'), findsNothing);
    });

    testWidgets("the arrow on a row opens that visit", (tester) async {
      // The square at the end of each row on Home. It is the only control on
      // the row now — the Start-visit button that used to sit under the next
      // call was cut, so if this stops resolving, Home becomes a list you can
      // read and not act on.
      await pumpApp(tester, size: const Size(430, 1500));

      await tester.tap(find.byTooltip('Open visit').first);
      await settle(tester);

      expect(find.text('Activity Detail'), findsOneWidget);
    });

    testWidgets('the Sales tile opens a Sales page with figures on it',
        (tester) async {
      // Reported as "no sales page is there". The route and the screen both
      // exist, so a render-only smoke test passes — an ErrorState lays out
      // perfectly well. This taps the tile and asserts on a figure, which is
      // the only thing that separates a working screen from a broken one.
      await pumpApp(tester, size: const Size(430, 1500));

      await tester.tap(find.text('Sales'));
      await settle(tester);

      expect(find.text('Something went wrong'), findsNothing,
          reason: 'the Sales report must actually load');
      expect(find.text('TOTAL SALES'), findsOneWidget);
    });

    testWidgets('chat opens from the top bar', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Chat'));
      await settle(tester);

      expect(find.text('Chats'), findsOneWidget);
    });

    testWidgets('the side menu photo opens My Profile', (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.byIcon(Icons.menu).first);
      await settle(tester);

      // The header row *is* the profile — tapping your own name and photo is
      // where people look for it. Scoped to the Drawer: Home's next-action
      // card has an avatar too, and it comes first in the tree.
      await tester.tap(find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(AppAvatar),
      ));
      await settle(tester);

      expect(find.text('My Profile'), findsWidgets);
    });

    testWidgets('search is still reachable from the side menu',
        (tester) async {
      // Home's header was the only route to it; dropping the button without
      // rehoming the entry point would have orphaned the screen.
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.byIcon(Icons.menu));
      await settle(tester);

      await tester.scrollUntilVisible(
        find.text('Search'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Search'));
      await settle(tester);

      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('the side menu reaches tab destinations', () {
    testWidgets('Chat from the menu opens Chat, not a dead tap',
        (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.byIcon(Icons.menu));
      await settle(tester);

      // 'Chat' in the side menu — the bar's Chat tab is icon-only while
      // unselected, so this text can only be the menu item.
      await tester.tap(find.text('Chat').last);
      await settle(tester);

      expect(find.text('Chats'), findsOneWidget);
    });
  });

  group('going back', () {
    testWidgets('back from another tab returns to Home, it does not exit',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byIcon(Icons.checklist_outlined).last);
      await settle(tester);
      expect(find.text('To-Do'), findsWidgets);

      // What the OS back gesture does. Switching branches uses `go`, so there
      // is nothing to pop — without the shell's PopScope this closed the app.
      final popped = await tester.binding.handlePopRoute();
      await settle(tester);

      expect(popped, isTrue, reason: 'the app must handle back itself');
      expect(find.textContaining('Good'), findsOneWidget,
          reason: 'back from a tab must land on Home');
    });

    testWidgets('back from a pushed screen returns to where it opened from',
        (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.text('Sales'));
      await settle(tester);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.textContaining('Good'), findsOneWidget);
    });

    testWidgets('a real tab root offers the menu in place of a back arrow',
        (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));
      // Home is a tab for every role, so there is nothing to pop and the slot
      // holds the app's index.
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets("a screen that is not this role's tab gets a back arrow",
        (tester) async {
      // My Activity is a *manager's* tab; a rep reaches it from the module
      // grid. It used to be entered with `go`, which put the rep on a branch
      // outside their own bar: no tab lit, no back arrow, and nothing to pop.
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.text('My Activity'));
      await settle(tester);

      expect(find.text('My Activity'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget,
          reason: 'a pushed screen must offer a way back');
    });

    testWidgets('back from My Activity returns to Home, it does not exit',
        (tester) async {
      // The reported bug. `indexWhere` answers -1 for a branch that is not
      // one of this role's tabs, which the shell read as "first tab" — so
      // `canPop` was true and the OS back gesture closed the app from a
      // screen the rep had navigated into.
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.text('My Activity'));
      await settle(tester);
      expect(find.text('My Activity'), findsOneWidget);

      final popped = await tester.binding.handlePopRoute();
      await settle(tester);

      expect(popped, isTrue, reason: 'the app must handle back itself');
      expect(find.textContaining('Good'), findsOneWidget,
          reason: 'back must land on Home, not close the app');
    });

    testWidgets('back from Reports returns to Home, it does not exit',
        (tester) async {
      await pumpApp(tester, size: const Size(420, 1800));

      await tester.tap(find.byIcon(Icons.bar_chart_outlined).last);
      await settle(tester);
      expect(find.text('Reports'), findsWidgets);

      final popped = await tester.binding.handlePopRoute();
      await settle(tester);

      expect(popped, isTrue);
      expect(find.textContaining('Good'), findsOneWidget,
          reason: 'back from a tab must land on Home');
    });
  });

  group('a manager keeps the tabs they had', () {
    testWidgets('Home, Activity, Team and Reports', (tester) async {
      await pumpApp(tester, code: 'ASM201');

      for (final icon in [
        Icons.event_note_outlined,
        Icons.groups_outlined,
        Icons.bar_chart_outlined,
      ]) {
        expect(find.byIcon(icon), findsOneWidget, reason: '$icon tab missing');
      }

      await tester.tap(find.byIcon(Icons.groups_outlined).last);
      await settle(tester);
      expect(find.text('My Team'), findsWidgets);

      await tester.tap(find.byIcon(Icons.event_note_outlined).last);
      await settle(tester);
      expect(find.text('My Activity'), findsOneWidget);
    });
  });

  group('an administrator lands on the admin tabs', () {
    testWidgets('Dashboard, Users, Master Data and Reports', (tester) async {
      await pumpApp(tester, code: 'ADM001');

      // Each admin tab is its own branch now: tapping Users used to switch to
      // the branch at position 1 and land on the rep's activity list.
      await tester.tap(find.byIcon(Icons.people_outline).last);
      await settle(tester);
      expect(find.text('My Activity'), findsNothing);

      await tester.tap(find.byIcon(Icons.storage_outlined).last);
      await settle(tester);
      expect(find.text('My Activity'), findsNothing);
    });
  });
}

class _TestAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();

  void seed(Session session) => state = AuthAuthenticated(session);
}
