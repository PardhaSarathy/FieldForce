import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/mock/mock_dataset.dart';
import 'package:pharmaconnect/core/providers/app_providers.dart';
import 'package:pharmaconnect/core/routing/routes.dart';
import 'package:pharmaconnect/core/theme/app_spacing.dart';
import 'package:pharmaconnect/shared/widgets/month_calendar.dart';
import 'package:pharmaconnect/shared/widgets/primitives.dart';
import 'package:pharmaconnect/core/theme/app_background.dart';
import 'package:pharmaconnect/core/theme/app_colors.dart';
import 'package:pharmaconnect/core/theme/app_theme.dart';
import 'package:pharmaconnect/core/utils/formatters.dart';
import 'package:pharmaconnect/shared/models/activity.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/core/location/geo_math.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/features/activity/presentation/activity_list_screen.dart';
import 'package:pharmaconnect/features/activity/presentation/add_activity_screen.dart';
import 'package:pharmaconnect/features/activity/presentation/visit_flow_screen.dart';
import 'package:pharmaconnect/features/activity/presentation/widgets/call_report_form.dart';
import 'package:pharmaconnect/features/admin/presentation/admin_screens.dart';
import 'package:pharmaconnect/features/approvals/presentation/approval_screens.dart';
import 'package:pharmaconnect/features/business/presentation/business_screens.dart';
import 'package:pharmaconnect/features/business/presentation/order_screens.dart';
import 'package:pharmaconnect/features/clients/presentation/client_screens.dart';
import 'package:pharmaconnect/features/communication/presentation/communication_screens.dart';
import 'package:pharmaconnect/features/day_plan/presentation/day_plan_screens.dart';
import 'package:pharmaconnect/features/day_plan/presentation/my_day_plan_screen.dart';
import 'package:pharmaconnect/features/expenses/presentation/claim_screens.dart';
import 'package:pharmaconnect/features/expenses/presentation/expense_screens.dart';
import 'package:pharmaconnect/features/home/presentation/home_screen.dart';
import 'package:pharmaconnect/features/hr/presentation/hr_screens.dart';
import 'package:pharmaconnect/features/manager/presentation/assignment_screens.dart';
import 'package:pharmaconnect/features/manager/presentation/manager_dashboard_screen.dart';
import 'package:pharmaconnect/features/manager/presentation/team_screens.dart';
import 'package:pharmaconnect/features/more/presentation/more_screens.dart';
import 'package:pharmaconnect/features/reports/presentation/report_screens.dart';
import 'package:pharmaconnect/features/shell/presentation/app_drawer.dart';
import 'package:pharmaconnect/features/shell/presentation/app_shell.dart';
import 'package:pharmaconnect/features/travel/presentation/travel_screens.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// Render smoke tests for every major screen.
///
/// These exist because unit tests cannot catch a layout error: a widget that
/// throws during layout in release simply renders nothing, taking the rest of
/// the list with it. In a test binding the same error is a hard failure, which
/// is exactly what we want: `testWidgets` fails automatically on any uncaught
/// framework exception during build, layout or paint, so simply pumping each
/// screen and letting it settle is a real assertion, not a formality.
void main() {
  final store = MockStore.instance;

  Session sessionFor(String code) {
    final employee =
        store.seed.employees.firstWhere((e) => e.employeeCode == code);
    return Session(employee: employee, loginAt: DateTime(2026, 8, 26));
  }

  /// Signs in as [code] by seeding the auth controller, then renders [screen].
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    String code = 'MR1001',
    Size size = const Size(420, 900),
    double textScale = 1.0,
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
        child: MaterialApp(
          theme: AppTheme.light,
          home: screen,
          // Mirrors main.dart: every Scaffold is transparent and the ground is
          // painted once behind the navigator. Without this the harness would
          // render screens on a plain white that the app never shows.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: AppBackground(child: child!),
          ),
        ),
      ),
    );

    // Drain the mock repositories' simulated latency. Providers chain — a
    // screen's second query only starts once the first resolves — so a single
    // long pump leaves timers pending and trips the binding's leak check.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  group('field user screens render', () {
    testWidgets('Home', (tester) async {
      await pumpScreen(tester, const HomeScreen());
      expect(find.textContaining('Good'), findsOneWidget);
      // The regression this suite was written for: the day's list and
      // everything above it must actually be in the tree.
      expect(find.text("TODAY'S PLANNED VISITS"), findsOneWidget);
      // Both headings are gone on purpose. "Next action" was a card repeating
      // the first row of the list below it; "Quick actions" named the widget
      // rather than the content, which is the thing that made the screen read
      // as assembled rather than written.
      expect(find.text('NEXT ACTION'), findsNothing);
      expect(find.text('QUICK ACTIONS'), findsNothing);
      // The module tiles are still there, they simply have no label of their
      // own any more.
      expect(find.text('My Day Plan'), findsOneWidget);
    });

    testWidgets('My day plan', (tester) async {
      await pumpScreen(tester, const MyDayPlanScreen());
      expect(find.text('My Day Plan'), findsOneWidget);
      expect(find.text('Work type'), findsOneWidget);
    });

    testWidgets('Activity list', (tester) async {
      await pumpScreen(tester, const ActivityListScreen());
      expect(find.text('My Activity'), findsOneWidget);
      expect(find.text('Add New Activity'), findsOneWidget);
    });

    testWidgets('Add new activity', (tester) async {
      await pumpScreen(tester, const AddActivityScreen());
      expect(find.text('Add New Activity'), findsOneWidget);

      // One short form: who, when, what for. Adding an activity *plans* a
      // call — recording one is the visit flow, which begins from the
      // activity once the rep is standing at the door.
      expect(find.text('Client'), findsWidgets);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('Purpose'), findsOneWidget);
      expect(find.text('Add activity'), findsOneWidget);

      // Cut at the review's request, along with the travel plan's version.
      expect(find.text('Joint work'), findsNothing);
    });

    testWidgets('correcting a call freezes the position, not the reason',
        (tester) async {
      // The two halves of the Location step are frozen differently, and the
      // difference is the whole rule. The captured position is *evidence* and
      // never moves — re-measuring at a desk would have the record claim the
      // rep was standing at the clinic. The reason is the rep's own account of
      // that position, and improving a hurried one is what a correction is
      // for; freezing that half left the step with nothing to act on.
      final client = MockStore.instance.clients
          .firstWhere((c) => c.ownerEmployeeId == 'emp-1');

      final outOfRange = Activity(
        id: 'act-correction-probe',
        employeeId: 'emp-1',
        employeeName: 'Rahul Sharma',
        clientId: client.id,
        clientName: client.name,
        scheduledStart: DateTime.now(),
        status: ActivityStatus.completed,
        outOfRangeReason: 'Met at the OPD block',
        geoResult: const GeoFenceResult(
          verification: GeoVerification.outOfRange,
          radiusMeters: 50,
          distanceMeters: 340,
        ),
      );

      await pumpScreen(tester, AddActivityScreen(existing: outOfRange),
          size: const Size(420, 1600));

      // The client is restored from the record. It used to come only from
      // `presetClientId`, which a correction never carries — so this opened
      // with an empty picker and nothing stopped the rep re-saving the call
      // against a different doctor.
      expect(find.text(client.name), findsWidgets);
      expect(find.text('Who did you call on?'), findsNothing);

      // Frozen: no way to take a fresh fix.
      expect(find.text('Refresh location'), findsNothing);
      expect(find.text('Capture location'), findsNothing);

      // Live: the explanation is on screen and editable.
      expect(find.text('Met at the OPD block'), findsOneWidget);
    });

    testWidgets('the live visit uses the shared call report', (tester) async {
      await pumpScreen(tester, const VisitFlowScreen(activityId: 'act-1'),
          size: const Size(430, 2200));

      // Step two is where the report lives; step one is the geo-fence.
      await tester.tap(find.text('Continue'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(CallReportForm), findsOneWidget);
    });

    testWidgets('correcting a call uses the same call report', (tester) async {
      // They had drifted: the live visit asked for a star rating, the products
      // discussed and the material shared; this screen asked for samples, a
      // *typed* RCPA number and a POB figure. Same record, same step, same
      // title, two sets of questions — so what a call report contained
      // depended on which door the rep came through.
      //
      // Creating an activity no longer walks the steps at all — it plans a
      // call — so the shared form is reached by correcting one.
      await pumpScreen(tester, const EditActivityScreen(activityId: 'act-1'),
          size: const Size(430, 2200));

      await tester.tap(find.text('Continue'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(CallReportForm), findsOneWidget);
    });

    testWidgets('Client list', (tester) async {
      await pumpScreen(tester, const ClientListScreen());
      expect(find.text('Clients'), findsOneWidget);
    });

    testWidgets('New client', (tester) async {
      await pumpScreen(tester, const NewClientScreen(), size: const Size(420, 1600));
      expect(find.text('New Client'), findsOneWidget);
      // Search first, then register: the duplicate check leads the form.
      expect(find.text('SEARCH EXISTING CLIENTS'), findsOneWidget);
      expect(find.text('NEW CLIENT REGISTRATION'), findsOneWidget);
      // Fields added for the client master, not just the visit.
      expect(find.text('Designation'), findsOneWidget);
      expect(find.text('Territory'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      // Category is the listing state, not a planning grade.
      expect(find.text('Unlisted'), findsOneWidget);
      // Interpolated copy must render its values, not the source text.
      expect(find.textContaining(r'${'), findsNothing);
      expect(find.text('Core Target'), findsNothing);

      // Below the fold — the list is lazy, so it has to be scrolled to.
      // `.first` is the form itself — the client-type filter bar inside it is
      // also a Scrollable, so an unqualified finder matches two.
      await tester.scrollUntilVisible(
        find.text('Special date'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Special date'), findsOneWidget);
    });

    testWidgets('editing a client opens the same form, filled in',
        (tester) async {
      await pumpScreen(
        tester,
        const EditClientScreen(clientId: 'cli-1'),
        size: const Size(420, 1600),
      );

      // The same form, in the other mode.
      expect(find.text('Edit Client'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);

      // The record's own values are in the fields, not blank ones.
      final seeded = MockDataset.instance.clients
          .firstWhere((c) => c.id == 'cli-1');
      expect(find.text(seeded.name), findsWidgets);

      // The duplicate search is for registering, not for editing something
      // that already exists.
      expect(find.text('SEARCH EXISTING CLIENTS'), findsNothing);
    });

    testWidgets('Expenses — the month of declared days', (tester) async {
      await pumpScreen(tester, const ExpenseClaimScreen(),
          size: const Size(420, 1600));
      expect(find.text('Expenses'), findsOneWidget);

      // The rows are declared *days*, claimed or not. The screen this
      // replaced was a flat list of receipts, which could not show the only
      // rows that need action: a worked day with nothing filed against it.
      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_DayRow'),
        findsWidgets,
        reason: 'a month of declared days, not a list of receipts',
      );

      // The month never shuts, and the screen says so.
      expect(find.textContaining('No cut-off'), findsOneWidget);
    });

    testWidgets('the calendar drives the list, and only on declared days',
        (tester) async {
      // The calendar has two jobs and has to do both or it is decoration: it
      // shows where every day stands, and tapping one selects that day so the
      // list can be scrolled to it. A calendar that only paints state leaves
      // the rep scrolling to find the day they just looked at.
      //
      // Nothing here awaits the repository. A `testWidgets` body that awaits
      // the mock's simulated latency deadlocks — the fake clock only advances
      // when the test pumps — and the first version of this test hung for the
      // full ten-minute timeout instead of failing.
      await pumpScreen(tester, const ExpenseClaimScreen(),
          size: const Size(420, 1800));

      final cells = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_DayCell',
      );
      expect(cells, findsWidgets, reason: 'the month is drawn as a calendar');

      // Every day of the month gets a cell, declared or not — a calendar
      // missing its blank days is a list wearing a grid.
      final now = DateTime.now();
      expect(cells.evaluate().length, DateTime(now.year, now.month + 1, 0).day);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExpenseClaimScreen)),
      );
      expect(container.read(claimSelectedDayProvider), isNull);

      // Tap along the month until a declared day answers. Which dates are
      // declared depends on the day the suite runs, so the test asks the
      // screen rather than assuming — and a day with no plan behind it is
      // deliberately inert, which is the other half of what is being checked.
      var selected = false;
      for (var day = 1; day <= cells.evaluate().length && !selected; day++) {
        final cell = find.descendant(
          of: cells.at(day - 1),
          matching: find.text('$day'),
        );
        if (cell.evaluate().isEmpty) continue;
        await tester.tap(cell, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        selected = container.read(claimSelectedDayProvider) != null;
      }

      expect(selected, isTrue,
          reason: 'tapping a declared day must select it');
    });

    testWidgets('a day with no plan behind it cannot be claimed',
        (tester) async {
      // The rule the whole feature rests on. A date the rep never intimated
      // has nothing to claim against, and the screen has to say so rather
      // than offering a form that would write an orphan record.
      await pumpScreen(
        tester,
        ClaimDayScreen(date: DateTime(2019, 1, 2)),
      );
      expect(find.text('Nothing to claim'), findsOneWidget);
    });

    testWidgets('Tour plan opens on the calendar, not a list', (tester) async {
      await pumpScreen(tester, const TourPlanScreen(),
          size: const Size(420, 1600));

      expect(find.text('Tour Plan'), findsOneWidget);
      expect(find.text('Travel Plans'), findsNothing);

      // A calendar, not a dashboard. The old screen led with counts, filters
      // and a scroll of cards, none of which answers the question a rep opens
      // this with — which days have I not planned yet.
      // All four calendars in the app are the same widget now — attendance,
      // the day plan, the expense claim and this one — so the assertion is on
      // that rather than on a private cell each screen used to own.
      expect(find.byType(MonthCalendar), findsOneWidget,
          reason: 'the month is the screen');
      expect(find.textContaining('days planned'), findsOneWidget);

      // An escaped interpolation compiles, renders, and reads as a literal in
      // every cell — the label assertions above would all still pass while the
      // grid was nonsense.
      expect(find.textContaining(r'${'), findsNothing);
    });

    testWidgets('the tour month opens on next month', (tester) async {
      // A rep files next month's tour during this one. Opening on the current
      // month lands them on a plan already with their manager.
      await pumpScreen(tester, const TourPlanScreen(),
          size: const Size(420, 1600));

      final now = DateTime.now();
      expect(
        find.text(Fmt.monthYear(DateTime(now.year, now.month + 1))),
        findsOneWidget,
      );
    });

    testWidgets('a tour day asks where, and saves rather than submits',
        (tester) async {
      // A date far enough out that the seed cannot have planned it. Tomorrow
      // is already submitted in the demo data, and a submitted day is
      // correctly read-only — which is a different screen from the one this
      // test is about.
      await pumpScreen(tester, TourPlanDayScreen(date: DateTime(2030, 1, 15)),
          size: const Size(420, 1800));

      expect(find.text('Work type'), findsOneWidget);
      expect(find.text('Territory'), findsOneWidget);
      expect(find.text('Clients'), findsOneWidget);

      // There is no Submit here. The day is saved; the month is submitted,
      // once, from the calendar — splitting it lets a rep send half a plan,
      // which is the one thing a manager cannot approve.
      expect(find.text('Save day'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Submit for approval'), findsNothing);
    });

    testWidgets('Business dashboard', (tester) async {
      await pumpScreen(tester, const BusinessDashboardScreen());
      expect(find.text('Business'), findsOneWidget);
    });

    testWidgets('Sales', (tester) async {
      await pumpScreen(tester, const SalesScreen());
    });

    testWidgets('Targets', (tester) async {
      await pumpScreen(tester, const TargetsScreen());
    });

    testWidgets('Orders', (tester) async {
      await pumpScreen(tester, const OrderListScreen());
      expect(find.text('Orders'), findsOneWidget);
    });

    testWidgets('New order', (tester) async {
      await pumpScreen(tester, const NewOrderScreen());
      expect(find.text('New Order'), findsOneWidget);
    });

    testWidgets('HR home', (tester) async {
      await pumpScreen(tester, const HrHomeScreen());
    });

    testWidgets('Attendance', (tester) async {
      await pumpScreen(tester, const AttendanceScreen());
    });

    testWidgets('Leave list', (tester) async {
      await pumpScreen(tester, const LeaveListScreen());
    });

    testWidgets('New leave', (tester) async {
      await pumpScreen(tester, const NewLeaveScreen());
    });

    testWidgets('Payslips', (tester) async {
      await pumpScreen(tester, const PayslipsScreen());
    });

    testWidgets('Calendar', (tester) async {
      await pumpScreen(tester, const CalendarScreen());
    });

    testWidgets('Chat list', (tester) async {
      await pumpScreen(tester, const ChatListScreen());
    });

    testWidgets('Resources', (tester) async {
      await pumpScreen(tester, const ResourceListScreen());
    });

    testWidgets('Surveys', (tester) async {
      await pumpScreen(tester, const SurveyListScreen());
    });

    testWidgets('Complaints', (tester) async {
      await pumpScreen(tester, const ComplaintListScreen());
    });

    testWidgets('Reports home', (tester) async {
      await pumpScreen(tester, const ReportsHomeScreen());
    });

    testWidgets('Daily report', (tester) async {
      await pumpScreen(tester, const DailyReportScreen());
    });

    testWidgets('Visit report', (tester) async {
      await pumpScreen(tester, const VisitReportScreen());
    });

    testWidgets('Sales report', (tester) async {
      await pumpScreen(tester, const SalesReportScreen());
    });

    testWidgets('Expense report', (tester) async {
      await pumpScreen(tester, const ExpenseReportScreen());
    });

    testWidgets('Overview report', (tester) async {
      await pumpScreen(tester, const OverviewReportScreen());
    });

    testWidgets('Profile', (tester) async {
      await pumpScreen(tester, const ProfileScreen());
    });

    testWidgets('Settings', (tester) async {
      await pumpScreen(tester, const SettingsScreen());
    });

    testWidgets('Sync center', (tester) async {
      await pumpScreen(tester, const SyncCenterScreen());
    });

    testWidgets('More', (tester) async {
      await pumpScreen(tester, const MoreScreen());
    });

    testWidgets('Notifications', (tester) async {
      await pumpScreen(tester, const NotificationsScreen());
    });

    testWidgets('Tasks', (tester) async {
      await pumpScreen(tester, const TaskListScreen());
      expect(find.text('To-Do'), findsOneWidget);
      // A rep adds their own to-do; the calendar sits beside it.
      expect(find.text('Add to-do'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    });

    testWidgets('New to-do', (tester) async {
      await pumpScreen(tester, const NewTaskScreen());
      expect(find.text('Add To-Do'), findsOneWidget);
    });
  });

  group('manager screens render', () {
    testWidgets('Manager dashboard', (tester) async {
      await pumpScreen(tester, const ManagerDashboardScreen(), code: 'ASM201');
      expect(find.textContaining('Good'), findsOneWidget);
    });

    testWidgets('Home routes a manager to the manager dashboard', (tester) async {
      await pumpScreen(tester, const HomeScreen(), code: 'ASM201');
      // A manager must not see the field user's visit plan on Home.
      expect(find.text('NEXT ACTION'), findsNothing);
      expect(find.text('TEAM TODAY'), findsOneWidget);
    });

    testWidgets('My team', (tester) async {
      await pumpScreen(tester, const MyTeamScreen(), code: 'ASM201');
      expect(find.text('My Team'), findsOneWidget);
    });

    testWidgets('Team activity', (tester) async {
      await pumpScreen(tester, const TeamActivityScreen(), code: 'ASM201');
    });

    testWidgets('Team map', (tester) async {
      await pumpScreen(tester, const TeamMapScreen(), code: 'ASM201');
    });

    testWidgets('Team performance', (tester) async {
      await pumpScreen(tester, const TeamPerformanceScreen(), code: 'ASM201');
    });

    testWidgets('Approval center', (tester) async {
      await pumpScreen(tester, const ApprovalCenterScreen(), code: 'ASM201');
      expect(find.text('Approvals'), findsOneWidget);
    });

    testWidgets('Target assignment', (tester) async {
      await pumpScreen(tester, const TargetAssignmentScreen(), code: 'ASM201');
    });

    testWidgets('Rate assignment', (tester) async {
      await pumpScreen(tester, const RateAssignmentScreen(), code: 'ASM201');
    });

    testWidgets('Task assignment', (tester) async {
      await pumpScreen(tester, const TaskAssignmentScreen(), code: 'ASM201');
    });
  });

  group('admin screens render', () {
    testWidgets('Admin dashboard', (tester) async {
      await pumpScreen(tester, const AdminDashboardScreen(), code: 'ADM001');
      expect(find.text('Administration'), findsOneWidget);
    });

    testWidgets('Users', (tester) async {
      await pumpScreen(tester, const AdminUsersScreen(), code: 'ADM001');
    });

    testWidgets('Master data', (tester) async {
      await pumpScreen(tester, const AdminMasterDataScreen(), code: 'ADM001');
    });

    testWidgets('Geo-fence configuration', (tester) async {
      await pumpScreen(tester, const AdminGeoFenceScreen(), code: 'ADM001');
      expect(find.text('Geo-fence'), findsOneWidget);
    });

    testWidgets('Approval rules', (tester) async {
      await pumpScreen(tester, const AdminApprovalRulesScreen(), code: 'ADM001');
    });
  });

  group('home header and navigation', () {
    testWidgets('top bar carries the brand, greeting sits below it',
        (tester) async {
      await pumpScreen(tester, const HomeScreen());

      // Brand in the top bar.
      expect(find.text('Mr Sales'), findsOneWidget);

      // Greeting is beneath the bar, not squeezed beside it: its left edge
      // should line up with the screen gutter rather than being pushed right.
      final greeting = find.textContaining('Good');
      expect(greeting, findsOneWidget);

      final brandBox = tester.getRect(find.text('Mr Sales'));
      final greetingBox = tester.getRect(greeting);

      expect(greetingBox.top, greaterThan(brandBox.bottom),
          reason: 'greeting must sit below the top bar');

      // Pinned to the left gutter, not merely left of the brand: this is what
      // keeps the greeting in the corner rather than drifting toward centre
      // if the header's alignment is ever changed.
      expect(
        greetingBox.left,
        closeTo(AppSpacing.screenH, 1.0),
        reason: 'greeting must start at the screen gutter, not be centred',
      );
    });

    testWidgets('the modules sit above the day', (tester) async {
      await pumpScreen(tester, const HomeScreen(), size: const Size(375, 1600));

      final tile = tester.getRect(find.text('My Day Plan'));
      final visits = tester.getRect(find.text("TODAY'S PLANNED VISITS"));

      expect(tile.top, lessThan(visits.top),
          reason: 'the module grid comes first');
    });

    testWidgets('the day list is a window of six, anchored on the next call',
        (tester) async {
      // Six, not three and not the whole day. Three was too few to plan
      // against; the whole day turned Home into a page you scroll past to
      // reach the tab bar. "See all" carries the rest.
      await pumpScreen(tester, const HomeScreen(), size: const Size(430, 3000));

      final rows = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_VisitRow',
      );
      // A ceiling, not a floor. How many rows there are depends on how far
      // into the day the suite runs — the window starts at the next call and
      // runs to the end of the plan, so a late-afternoon run legitimately has
      // two of them. What must always hold is the cap and the anchor.
      expect(rows.evaluate().length, lessThanOrEqualTo(6));
      expect(rows.evaluate().length, greaterThan(0));

      // Exactly one NEXT mark, and it is on the *first* row. A row above it
      // would be a visit already made, and with the ticks gone there is
      // nothing left on the row to say so.
      expect(find.text('NEXT'), findsOneWidget);
      expect(
        find.descendant(of: rows.first, matching: find.text('NEXT')),
        findsOneWidget,
        reason: 'the window starts at the next call, it does not back-fill',
      );

      // No ticks. A finished visit renders like any other row — the count
      // above already says how many are behind you, and six green ticks turn a
      // schedule into a checklist.
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('no visit is started from Home', (tester) async {
      // Start and Complete both live on the activity detail. They were on the
      // NEXT row for a while, and on an in-progress visit the label truncated
      // to "Complete …" — a button that cannot say what it does. Home shows
      // the day; the detail screen runs the visit.
      await pumpScreen(tester, const HomeScreen(), size: const Size(430, 3000));

      expect(find.text('Start visit'), findsNothing);
      expect(find.text('Complete visit'), findsNothing);

      // Every row still opens its record, and so does the square beside it.
      expect(find.byTooltip('Open visit'), findsWidgets);
    });

    testWidgets('progress, pace and the month share one card', (tester) async {
      await pumpScreen(tester, const HomeScreen());

      // Progress, pace and the month, in one card rather than two that said
      // the same thing.
      expect(find.textContaining('visits completed today'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);

      // The pace line, without pinning the wording: `paceLabel` reads the
      // clock, so asserting "behind schedule" passed in the afternoon and
      // failed at 7pm when the same rep was on track.
      expect(
        find.byWidgetPredicate((w) => w is StatusDot),
        findsWidgets,
        reason: 'the goal card must still show a pace indicator',
      );

      // The separate status strip is gone, and with it the duplicate figure.
      expect(find.text("Today's Work"), findsNothing);
      expect(find.text('Pending Tasks'), findsNothing);
    });

    testWidgets('the goal card survives a small phone', (tester) async {
      await pumpScreen(tester, const HomeScreen(),
          size: const Size(320, 640));
      expect(find.textContaining('visits completed today'), findsOneWidget);
    });

    testWidgets('six quick actions, all visible', (tester) async {
      await pumpScreen(tester, const HomeScreen(), size: const Size(430, 1400));

      for (final label in [
        'My Day Plan',
        'My Activity',
        'Clients',
        'Tour Plan',
        'HR',
        'Expenses',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label missing');
      }
      // No expander — all six are always on screen.
      expect(find.text('Show all'), findsNothing);
      // To-Do moved to the bottom bar, and Sales came off the grid when
      // Expenses took its place — a rep touches expenses every working day.
      // Sales is still one tap away in the side menu.
      expect(find.text('Business'), findsNothing);
      expect(find.text('Sales'), findsNothing);
    });

    testWidgets('the six tiles lay out as three columns by two rows',
        (tester) async {
      await pumpScreen(tester, const HomeScreen(), size: const Size(375, 1400));

      const labels = [
        'My Day Plan',
        'My Activity',
        'Clients',
        'Tour Plan',
        'HR',
        'Expenses',
      ];
      // The tiles, not the labels: a label's vertical centre moves with how
      // many lines it wraps to, so measuring text would report a row per
      // label length rather than a row per row.
      final rects = [
        for (final l in labels)
          tester.getRect(find.ancestor(
            of: find.text(l),
            matching: find.byType(AppCard),
          )),
      ];

      // Three distinct columns, two distinct rows. A ragged last row is the
      // symptom of the tile count and the column count disagreeing.
      expect(rects.map((r) => r.center.dx.round()).toSet(), hasLength(3));
      expect(rects.map((r) => r.center.dy.round()).toSet(), hasLength(2));
    });

    testWidgets('the tile grows with the text size, not the device width',
        (tester) async {
      // The bug this guards against is the one that clipped labels across the
      // app: with childAspectRatio the tile height follows the *width*, so
      // raising the text size overflowed a tile that never grew.
      //
      // It asserts the tile is taller at 1.3x than at 1.0 on the *same* device
      // width, rather than checking a computed height. That is both
      // font-independent — `flutter test` substitutes a fixed-width test font
      // whose glyphs are far wider than the real one — and free of any
      // assumption about how many label lines the tile reserves, which is a
      // design decision that has already changed once and broke this test.
      Future<double> tileHeight(double textScale) async {
        await pumpScreen(tester, const HomeScreen(),
            size: const Size(375, 1600), textScale: textScale);
        return tester
            .getRect(find.ancestor(
              of: find.text('Clients'),
              matching: find.byType(AppCard),
            ))
            .height;
      }

      final normal = await tileHeight(1);

      // Tear the first tree down and let its provider chain finish before the
      // second goes up. Replacing one live tree with another leaves the first
      // one's simulated-latency timers pending, which trips the binding's
      // leak check at the end of the test.
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      final large = await tileHeight(1.3);

      expect(large, greaterThan(normal),
          reason: 'the tile must make room for larger text');
    });

    test('bottom navigation has four tabs and no More', () {
      for (final (isManager, isAdmin) in [
        (false, false),
        (true, false),
        (false, true),
      ]) {
        final tabs = destinationsFor(isManager: isManager, isAdmin: isAdmin);
        expect(tabs, hasLength(4));
        expect(tabs.map((t) => t.label), isNot(contains('More')));
      }
    });

    test('a rep gets Home, To-Do, Resources and Reports', () {
      // Chat moved to the top bar: it is checked, not navigated to.
      expect(
        destinationsFor(isManager: false, isAdmin: false).map((t) => t.label),
        ['Home', 'To-Do', 'Resources', 'Reports'],
      );
    });

    test('a manager keeps Activity and Team', () {
      expect(
        destinationsFor(isManager: true, isAdmin: false).map((t) => t.label),
        ['Home', 'Activity', 'Team', 'Reports'],
      );
    });

    test('every tab names a distinct branch, and its own route', () {
      // The branch index is what `goBranch` acts on. If two tabs shared one,
      // or a tab pointed at a branch holding a different screen, the tap would
      // silently open the wrong destination.
      for (final (isManager, isAdmin) in [
        (false, false),
        (true, false),
        (false, true),
      ]) {
        final tabs = destinationsFor(isManager: isManager, isAdmin: isAdmin);
        expect(tabs.map((t) => t.branch).toSet(), hasLength(tabs.length));
        for (final tab in tabs) {
          expect(Routes.shellRoots, contains(tab.route),
              reason: '${tab.label} must be a shell branch root');
        }
      }
    });
  });

  group('the page ground', () {
    testWidgets('is a wash, and screens let it through', (tester) async {
      await pumpScreen(tester, const HomeScreen());

      // The flattest thing an app can do is paint one colour behind every
      // screen. If a Scaffold ever paints its own ground again, it covers this
      // and the app goes flat without anything failing to compile.
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppBackground),
          matching: find.byType(DecoratedBox),
        ).first,
      );
      final gradient =
          (box.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors, [
        AppColors.backgroundTop,
        AppColors.backgroundMid,
        AppColors.backgroundBottom,
      ]);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.transparent,
          reason: 'a screen that paints its own ground hides the wash');
    });
  });

  group('side menu', () {
    testWidgets('opens from Home and lists account destinations',
        (tester) async {
      await pumpScreen(tester, const _ShellHarness());

      expect(find.byIcon(Icons.menu), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Field-operations group is at the top of the menu.
      expect(find.text('FIELD OPERATIONS'), findsOneWidget);
      // 'Calendar' is unique to the menu — 'My Day Plan', 'Clients',
      // 'To-Do' and 'Expenses' all appear on Home's grid as well.
      expect(find.text('Calendar'), findsOneWidget);
      // Logout is pinned outside the scrolling list.
      expect(find.text('Logout'), findsOneWidget);

      // A field user has no management group at all.
      expect(find.text('MANAGEMENT'), findsNothing);

      // Account destinations sit at the bottom of the index.
      await tester.scrollUntilVisible(
        find.text('Help & Support'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows Approvals for a manager', (tester) async {
      await pumpScreen(tester, const _ShellHarness(), code: 'ASM201');

      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.scrollUntilVisible(
        find.text('Approvals'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // Assert on the manager-only items, not the section header above them:
      // scrollUntilVisible stops as soon as the target is on screen, which can
      // leave the header just off the top.
      // Just the item scrolled to. Asserting on its neighbours or its section
      // header depends on exactly where scrollUntilVisible stops, which is not
      // a property worth pinning.
      expect(find.text('Approvals'), findsOneWidget);
    });
  });

  // Every screen, on the two conditions that actually break layouts: a small
  // phone, and the largest text size the app allows (main.dart clamps the
  // system scale to 1.3). A tile that clips its label on "some devices" is
  // this, and it should fail here rather than in a demo.
  group('layout holds on a small phone at maximum text size', () {
    final screens = <(String, Widget, String)>[
      ('Home', const HomeScreen(), 'MR1001'),
      ('My day plan', const MyDayPlanScreen(), 'MR1001'),
      ('Activity list', const ActivityListScreen(), 'MR1001'),
      ('Add new activity', const AddActivityScreen(), 'MR1001'),
      ('Client list', const ClientListScreen(), 'MR1001'),
      ('New client', const NewClientScreen(), 'MR1001'),
      // A real seeded id — 'cl-1' is a cluster, and the screen would have
      // rendered its error state, proving nothing about the prefill.
      ('Edit client', const EditClientScreen(clientId: 'cli-1'), 'MR1001'),
      ('Edit expense', const EditExpenseScreen(expenseId: 'exp-1'), 'MR1001'),
      ('Edit activity', const EditActivityScreen(activityId: 'act-1'), 'MR1001'),
      ('Expenses', const ExpenseClaimScreen(), 'MR1001'),
      ('Tour plan', const TourPlanScreen(), 'MR1001'),
      ('Business', const BusinessDashboardScreen(), 'MR1001'),
      ('Sales', const SalesScreen(), 'MR1001'),
      ('Targets', const TargetsScreen(), 'MR1001'),
      ('Orders', const OrderListScreen(), 'MR1001'),
      ('New order', const NewOrderScreen(), 'MR1001'),
      ('HR home', const HrHomeScreen(), 'MR1001'),
      ('Attendance', const AttendanceScreen(), 'MR1001'),
      ('Leave list', const LeaveListScreen(), 'MR1001'),
      ('New leave', const NewLeaveScreen(), 'MR1001'),
      ('Payslips', const PayslipsScreen(), 'MR1001'),
      ('Documents', const DocumentsScreen(), 'MR1001'),
      ('Holidays', const HolidaysScreen(), 'MR1001'),
      ('Calendar', const CalendarScreen(), 'MR1001'),
      ('Chat list', const ChatListScreen(), 'MR1001'),
      ('Resources', const ResourceListScreen(), 'MR1001'),
      ('Surveys', const SurveyListScreen(), 'MR1001'),
      ('New survey', const NewSurveyScreen(), 'MR1001'),
      ('Complaints', const ComplaintListScreen(), 'MR1001'),
      ('New complaint', const NewComplaintScreen(), 'MR1001'),
      ('Reports home', const ReportsHomeScreen(), 'MR1001'),
      ('Daily report', const DailyReportScreen(), 'MR1001'),
      ('Visit report', const VisitReportScreen(), 'MR1001'),
      ('Sales report', const SalesReportScreen(), 'MR1001'),
      ('Target report', const TargetReportScreen(), 'MR1001'),
      ('Expense report', const ExpenseReportScreen(), 'MR1001'),
      ('Overview report', const OverviewReportScreen(), 'MR1001'),
      ('More', const MoreScreen(), 'MR1001'),
      ('Profile', const ProfileScreen(), 'MR1001'),
      ('Edit profile', const EditProfileScreen(), 'MR1001'),
      ('Settings', const SettingsScreen(), 'MR1001'),
      ('Help', const HelpScreen(), 'MR1001'),
      ('Sync center', const SyncCenterScreen(), 'MR1001'),
      ('Notifications', const NotificationsScreen(), 'MR1001'),
      ('Tasks', const TaskListScreen(), 'MR1001'),
      ('New to-do', const NewTaskScreen(), 'MR1001'),
      ('Search', const SearchScreen(), 'MR1001'),
      ('Manager dashboard', const ManagerDashboardScreen(), 'ASM201'),
      ('My team', const MyTeamScreen(), 'ASM201'),
      ('Team activity', const TeamActivityScreen(), 'ASM201'),
      ('Team map', const TeamMapScreen(), 'ASM201'),
      ('Team performance', const TeamPerformanceScreen(), 'ASM201'),
      ('Approvals', const ApprovalCenterScreen(), 'ASM201'),
      ('Target assignment', const TargetAssignmentScreen(), 'ASM201'),
      ('Rate assignment', const RateAssignmentScreen(), 'ASM201'),
      ('Task assignment', const TaskAssignmentScreen(), 'ASM201'),
      ('Admin dashboard', const AdminDashboardScreen(), 'ADM001'),
      ('Admin users', const AdminUsersScreen(), 'ADM001'),
      ('Admin master data', const AdminMasterDataScreen(), 'ADM001'),
      ('Admin geo-fence', const AdminGeoFenceScreen(), 'ADM001'),
      ('Admin approval rules', const AdminApprovalRulesScreen(), 'ADM001'),
    ];

    for (final (name, screen, code) in screens) {
      testWidgets(name, (tester) async {
        await pumpScreen(
          tester,
          screen,
          code: code,
          size: const Size(320, 640),
          textScale: 1.3,
        );
      });
    }
  });

  group('narrow and wide viewports', () {
    testWidgets('Home on a small phone', (tester) async {
      await pumpScreen(tester, const HomeScreen(), size: const Size(320, 640));
    });

    testWidgets('Home on a tablet', (tester) async {
      await pumpScreen(tester, const HomeScreen(), size: const Size(900, 1200));
    });

    testWidgets('Business dashboard on a small phone', (tester) async {
      await pumpScreen(
        tester,
        const BusinessDashboardScreen(),
        size: const Size(320, 640),
      );
    });
  });
}

/// Minimal stand-in for the routed shell: supplies the Scaffold that owns the
/// drawer, so the hamburger in Home has something to open.
class _ShellHarness extends ConsumerWidget {
  const _ShellHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: ref.watch(shellScaffoldKeyProvider),
      drawer: const AppDrawer(),
      body: const HomeScreen(),
    );
  }
}

/// Auth controller that can be seeded with a session directly, so screens can
/// be rendered without driving the login form in every test.
class _TestAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();

  void seed(Session session) => state = AuthAuthenticated(session);
}
