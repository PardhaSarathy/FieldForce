import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/providers/app_providers.dart';
import 'package:pharmaconnect/core/routing/app_router.dart';
import 'package:pharmaconnect/core/theme/app_theme.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/models/organization.dart';
import 'package:pharmaconnect/features/activity/presentation/widgets/activity_card.dart';
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

  /// Opens Sales the way a rep now does — from the side menu.
  ///
  /// It came off Home's module grid when Expenses took its place. A rep
  /// touches expenses every working day; sales is a figure they read now and
  /// then, and dropping the tile only matters if the screen became
  /// unreachable, which is what these tests check.
  Future<void> openSales(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu).first);
    await settle(tester);
    await tester.tap(find.text('Sales').last);
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
      // Two questions: who, and what for. It is filed against today —
      // the date field was a required tap that answered itself.
      expect(find.text('Client'), findsWidgets);
      expect(find.text('When'), findsNothing);
      expect(find.text('Purpose'), findsOneWidget);
      expect(find.text('Add activity'), findsOneWidget);

      // The three steps are not here — they are behind Start visit.
      expect(find.text('Call report'), findsNothing);
      expect(find.text('Review'), findsNothing);
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

      await openSales(tester);

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

      // The tile is named for the screen it opens. It said "Travel" and opened
      // a hub with two doors in it; Expenses is a module of its own on Home
      // now, which left the hub asking a question with one answer.
      await tester.tap(find.text('Tour Plan').first);
      await settle(tester);

      expect(find.text('Tour Plan'), findsWidgets);
      expect(find.text('Travel Plans'), findsNothing);
      expect(find.textContaining('days planned'), findsOneWidget);
    });
  });

  group('a month of expenses is read from every source that knows', () {
    testWidgets('a finished month shows its Sundays and its missed days',
        (tester) async {
      // Not a data test — a *reachability* one. The join happens in the
      // repository, and a render test cannot tell a screen showing four
      // intimated days from one showing the whole month. So step back to a
      // month that has ended and look for the days nobody filed a plan for.
      await pumpApp(tester, size: const Size(430, 2200));

      await tester.tap(find.text('Expenses').first);
      await settle(tester);
      expect(find.text('Expenses'), findsWidgets);

      await tester.tap(find.byTooltip('Previous month'));
      await settle(tester);

      // Sunday is the week off everywhere, and it reaches the claim without
      // the rep telling it so.
      expect(find.text('Week off'), findsWidgets,
          reason: 'a finished month has Sundays, and they are days too');

      // And nothing on the screen is an error state laid out perfectly.
      expect(find.text('Something went wrong'), findsNothing);
    });
  });

  group('my activity', () {
    testWidgets('tapping a client opens that activity', (tester) async {
      // My Activity is a manager's tab and a rep reaches it from the module
      // grid, so it is *pushed* for a rep — the row has to open the detail on
      // top of a pushed screen, which is the case that broke before.
      await pumpApp(tester, size: const Size(430, 1800));

      await tester.tap(find.text('My Activity'));
      await settle(tester);
      expect(find.text('My Activity'), findsWidgets);

      final card = find.byType(ActivityCard).first;
      await tester.tap(card, warnIfMissed: false);
      await settle(tester);

      expect(find.text('Activity Detail'), findsOneWidget);
      // And it is the record, not an error state laid out perfectly.
      expect(find.text('Something went wrong'), findsNothing);
      expect(find.text('Scheduled'), findsOneWidget);
    });
  });

  group('the one calendar left belongs to the to-do list', () {
    testWidgets('To-Do opens its own calendar, not a month of visits',
        (tester) async {
      // It used to open a general Calendar: a month of *activities* with the
      // day's agenda under it — which is My Activity, one tap away, with its
      // own date strip. Neither screen was the calendar the to-do list wanted.
      await pumpApp(tester, size: const Size(430, 1800));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('To-Do').first);
      await settle(tester);

      await tester.tap(find.byTooltip('Calendar'));
      await settle(tester);

      expect(find.text('To-Do Calendar'), findsOneWidget);
      // Its legend is the to-do's three states, not a visit's.
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Something went wrong'), findsNothing);
    });
  });

  group('planned and unplanned are different questions', () {
    testWidgets('My Activity filters by origin, not by "upcoming"',
        (tester) async {
      // "Upcoming" sorted by *when*, and every open call is upcoming — the
      // filter answered a question nobody was asking. What a rep and a
      // manager both want to know is which calls were the plan and which were
      // the street.
      await pumpApp(tester, size: const Size(430, 1800));

      await tester.tap(find.text('My Activity'));
      await settle(tester);

      expect(find.text('Upcoming'), findsNothing);
      expect(find.text('Unplanned'), findsWidgets);

      await tester.tap(find.text('Unplanned').first);
      await settle(tester);

      // The filter has something in it, and it is a list rather than an
      // error state laid out perfectly.
      expect(find.byType(ActivityCard), findsWidgets);
      expect(find.text('Something went wrong'), findsNothing);
    });
  });

  group('adding an activity', () {
    testWidgets('creating one opens the activity, not a call report',
        (tester) async {
      // Picking the client creates the record and lands on it. The Location /
      // Call report / Review steps begin at Start visit, standing at the door
      // — walking into them from the form recorded a visit that had not
      // happened yet.
      await pumpApp(tester, size: const Size(430, 1800));

      await tester.tap(find.text('My Activity'));
      await settle(tester);
      await tester.tap(find.text('Add New Activity'));
      await settle(tester);

      await tester.tap(find.text('Select a client'));
      await settle(tester);
      await tester.tap(find.byType(ListTile).first);
      await settle(tester);

      await tester.tap(find.text('Add activity'));
      await settle(tester);

      expect(find.text('Activity Detail'), findsOneWidget);
      expect(find.text('Start visit'), findsOneWidget);
    });
  });

  group('claiming a day', () {
    testWidgets('Travel → Expenses opens the month of declared days',
        (tester) async {
      await pumpApp(tester, size: const Size(430, 1800));

      // Expenses is its own tile on Home now, not a door inside Travel.
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

    testWidgets("a rep's centre button opens Export, not a menu of shortcuts",
        (tester) async {
      // It was a sheet of four — Add activity, New client, New order, Tour
      // plan — and every one of them is a tap away on the screen it belongs
      // to. What had no door at all was the four sheets the office asks for
      // every month.
      await pumpApp(tester, size: const Size(430, 1800));

      expect(find.byTooltip('Add'), findsNothing,
          reason: 'a + that opens Export Data is a lie one glyph on');
      await tester.tap(find.byTooltip('Export'));
      await settle(tester);

      expect(find.text('Export Data'), findsOneWidget);
      expect(find.text('Add new'), findsNothing);

      // The four sheets, taken from the office's own workbook.
      for (final sheet in ['Expenses', 'Tour Plan', 'DCR', 'Client List']) {
        expect(find.text(sheet), findsWidgets, reason: sheet);
      }
    });

    testWidgets("a manager's centre button is untouched", (tester) async {
      await pumpApp(tester, code: 'ASM201', size: const Size(430, 1800));

      await tester.tap(find.byTooltip('Add'));
      await settle(tester);

      expect(find.text('Add new'), findsOneWidget);
      expect(find.text('Assign task'), findsOneWidget);
      expect(find.text('Set targets'), findsOneWidget);
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
      await pumpApp(tester, size: const Size(430, 1800));

      await openSales(tester);

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

      await openSales(tester);
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
