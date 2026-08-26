import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/providers/app_providers.dart';
import 'package:pharmaconnect/core/theme/app_spacing.dart';
import 'package:pharmaconnect/core/theme/app_theme.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/features/activity/presentation/activity_list_screen.dart';
import 'package:pharmaconnect/features/admin/presentation/admin_screens.dart';
import 'package:pharmaconnect/features/approvals/presentation/approval_screens.dart';
import 'package:pharmaconnect/features/business/presentation/business_screens.dart';
import 'package:pharmaconnect/features/business/presentation/order_screens.dart';
import 'package:pharmaconnect/features/clients/presentation/client_screens.dart';
import 'package:pharmaconnect/features/communication/presentation/communication_screens.dart';
import 'package:pharmaconnect/features/day_plan/presentation/day_plan_screens.dart';
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
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
      // The regression this suite was written for: the next-action card and
      // everything below it must actually be in the tree.
      expect(find.text('NEXT ACTION'), findsOneWidget);
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
    });

    testWidgets('Day plan', (tester) async {
      await pumpScreen(tester, const DayPlanScreen());
      expect(find.text('SCHEDULE'), findsOneWidget);
    });

    testWidgets('Activity list', (tester) async {
      await pumpScreen(tester, const ActivityListScreen());
      expect(find.text('My Activity'), findsOneWidget);
    });

    testWidgets('Client list', (tester) async {
      await pumpScreen(tester, const ClientListScreen());
      expect(find.text('Clients'), findsOneWidget);
    });

    testWidgets('New client', (tester) async {
      await pumpScreen(tester, const NewClientScreen());
      expect(find.text('New Client'), findsOneWidget);
    });

    testWidgets('Expenses', (tester) async {
      await pumpScreen(tester, const ExpenseListScreen());
      expect(find.text('Expenses'), findsOneWidget);
    });

    testWidgets('New expense', (tester) async {
      await pumpScreen(tester, const NewExpenseScreen());
      expect(find.text('New Expense'), findsOneWidget);
    });

    testWidgets('Travel', (tester) async {
      await pumpScreen(tester, const TravelDashboardScreen());
      expect(find.text('Travel Plans'), findsOneWidget);
    });

    testWidgets('New travel plan', (tester) async {
      await pumpScreen(tester, const NewTravelPlanScreen());
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
      expect(find.text('PharmaConnect'), findsOneWidget);

      // Greeting is beneath the bar, not squeezed beside it: its left edge
      // should line up with the screen gutter rather than being pushed right.
      final greeting = find.textContaining('Good');
      expect(greeting, findsOneWidget);

      final brandBox = tester.getRect(find.text('PharmaConnect'));
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

    testWidgets('the three today-metric tiles are present', (tester) async {
      await pumpScreen(tester, const HomeScreen());

      expect(find.text("Today's Goal"), findsOneWidget);
      expect(find.text("Today's Work"), findsOneWidget);
      expect(find.text('Pending Tasks'), findsOneWidget);
      expect(find.text('Planned Visits'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('the metric tiles survive a small phone', (tester) async {
      await pumpScreen(tester, const HomeScreen(),
          size: const Size(320, 640));
      expect(find.text("Today's Goal"), findsOneWidget);
      expect(find.text('Pending Tasks'), findsOneWidget);
    });

    testWidgets('two rows of quick actions, eight tiles', (tester) async {
      await pumpScreen(tester, const HomeScreen(), size: const Size(430, 1400));

      for (final label in [
        'Day Plan',
        'Activity',
        'Add Client',
        'Clients',
        'Chat',
        'To-Do',
        'Tour Plan',
        'Expenses',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label missing');
      }
    });

    testWidgets('quick action tiles survive a 320pt phone', (tester) async {
      // The grid is four columns wide; at 320pt each tile is ~63pt, which is
      // where labels and the icon chip start to fight for room.
      await pumpScreen(tester, const HomeScreen(), size: const Size(320, 1400));
      expect(find.text('Day Plan'), findsOneWidget);
      expect(find.text('Clients'), findsOneWidget);
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

    test('a rep gets Business, a manager gets Team', () {
      expect(
        destinationsFor(isManager: false, isAdmin: false).map((t) => t.label),
        contains('Business'),
      );
      expect(
        destinationsFor(isManager: true, isAdmin: false).map((t) => t.label),
        contains('Team'),
      );
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
      // 'Travel' is unique to the menu — Home's quick-action tile is labelled
      // 'Tour Plan', whereas 'Clients' and 'Expenses' appear in both.
      expect(find.text('Travel'), findsOneWidget);
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
      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('MANAGEMENT'), findsOneWidget);
    });
  });

  // Every screen, on the two conditions that actually break layouts: a small
  // phone, and the largest text size the app allows (main.dart clamps the
  // system scale to 1.3). A tile that clips its label on "some devices" is
  // this, and it should fail here rather than in a demo.
  group('layout holds on a small phone at maximum text size', () {
    final screens = <(String, Widget, String)>[
      ('Home', const HomeScreen(), 'MR1001'),
      ('Day plan', const DayPlanScreen(), 'MR1001'),
      ('Activity list', const ActivityListScreen(), 'MR1001'),
      ('Client list', const ClientListScreen(), 'MR1001'),
      ('New client', const NewClientScreen(), 'MR1001'),
      ('Expenses', const ExpenseListScreen(), 'MR1001'),
      ('New expense', const NewExpenseScreen(), 'MR1001'),
      ('Travel', const TravelDashboardScreen(), 'MR1001'),
      ('New travel plan', const NewTravelPlanScreen(), 'MR1001'),
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
