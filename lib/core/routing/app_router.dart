import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/presentation/activity_detail_screen.dart';
import '../../features/activity/presentation/activity_list_screen.dart';
import '../../features/activity/presentation/add_activity_screen.dart';
import '../../features/activity/presentation/visit_flow_screen.dart';
import '../../features/admin/presentation/admin_screens.dart';
import '../../features/approvals/presentation/approval_screens.dart';
import '../../features/authentication/presentation/auth_flow_screens.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/business/presentation/business_screens.dart';
import '../../features/business/presentation/order_screens.dart';
import '../../features/clients/presentation/client_screens.dart';
import '../../features/communication/presentation/communication_screens.dart';
import '../../features/day_plan/presentation/day_plan_screens.dart';
import '../../features/expenses/presentation/expense_screens.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/hr/presentation/hr_screens.dart';
import '../../features/manager/presentation/assignment_screens.dart';
import '../../features/manager/presentation/team_screens.dart';
import '../../features/more/presentation/more_screens.dart';
import '../../features/reports/presentation/report_screens.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/travel/presentation/travel_screens.dart';
import '../providers/app_providers.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKeys = [
  GlobalKey<NavigatorState>(debugLabel: 'tab0'),
  GlobalKey<NavigatorState>(debugLabel: 'tab1'),
  GlobalKey<NavigatorState>(debugLabel: 'tab2'),
  GlobalKey<NavigatorState>(debugLabel: 'tab3'),
];

/// Application router.
///
/// The redirect is the single authorization gate for navigation (§70): an
/// unauthenticated user can only reach the auth routes, and an authenticated
/// one can never land back on login. Role-specific routes additionally check
/// the session, so a hand-typed deep link cannot bypass the UI.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.login,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthed = auth is AuthAuthenticated;
      final path = state.matchedLocation;

      const authRoutes = {
        Routes.login,
        Routes.forgotPassword,
        Routes.otp,
        Routes.resetPassword,
        Routes.splash,
      };
      final onAuthRoute = authRoutes.contains(path);

      if (!isAuthed) return onAuthRoute ? null : Routes.login;

      if (onAuthRoute) {
        // Land each role on the home its navigation actually starts from.
        return auth.session.isAdmin ? Routes.admin : Routes.home;
      }

      // A field user has no business on manager or admin routes.
      final session = auth.session;
      final isManagerRoute = path.startsWith('/team') ||
          path.startsWith('/approvals') ||
          path.startsWith('/manage');
      final isAdminRoute = path.startsWith('/admin');

      if (isManagerRoute && !session.isManager && !session.isAdmin) {
        return Routes.home;
      }
      if (isAdminRoute && !session.isAdmin) return Routes.home;

      return null;
    },
    routes: [
      // ----------------------------------------------------------- auth
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        builder: (_, state) =>
            OtpScreen(employeeCode: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, state) =>
            ResetPasswordScreen(employeeCode: state.extra as String? ?? ''),
      ),

      // -------------------------------------------------- tabbed shell
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          // Tab 0 — Home (or Admin dashboard)
          StatefulShellBranch(
            navigatorKey: _shellKeys[0],
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
              GoRoute(
                path: Routes.admin,
                builder: (_, _) => const AdminDashboardScreen(),
              ),
            ],
          ),

          // Tab 1 — Activity (or Users for admin)
          StatefulShellBranch(
            navigatorKey: _shellKeys[1],
            routes: [
              GoRoute(
                path: Routes.activity,
                builder: (_, _) => const ActivityListScreen(),
              ),
              GoRoute(
                path: Routes.adminUsers,
                builder: (_, _) => const AdminUsersScreen(),
              ),
            ],
          ),

          // Tab 2 — Business / Team / Master data
          StatefulShellBranch(
            navigatorKey: _shellKeys[2],
            routes: [
              GoRoute(
                path: Routes.business,
                builder: (_, _) => const BusinessDashboardScreen(),
              ),
              GoRoute(path: Routes.team, builder: (_, _) => const MyTeamScreen()),
              GoRoute(
                path: Routes.adminMasterData,
                builder: (_, _) => const AdminMasterDataScreen(),
              ),
            ],
          ),

          // Tab 3 — Reports
          StatefulShellBranch(
            navigatorKey: _shellKeys[3],
            routes: [
              GoRoute(
                path: Routes.reports,
                builder: (_, _) => const ReportsHomeScreen(),
              ),
            ],
          ),

        ],
      ),

      // ------------------------------------------- full-screen routes
      // Pushed above the shell so forms and flows own the whole viewport.

      // No longer a tab, but still a useful index of every module.
      GoRoute(path: Routes.more, builder: (_, _) => const MoreScreen()),

      GoRoute(path: Routes.dayPlan, builder: (_, _) => const DayPlanScreen()),

      GoRoute(
        path: Routes.addActivity,
        builder: (_, state) => AddActivityScreen(
          presetClientId: state.uri.queryParameters['clientId'],
        ),
      ),
      GoRoute(
        path: '/activity/detail/:id',
        builder: (_, state) =>
            ActivityDetailScreen(activityId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/activity/visit/:id',
        builder: (_, state) =>
            VisitFlowScreen(activityId: state.pathParameters['id']!),
      ),

      GoRoute(path: Routes.clients, builder: (_, _) => const ClientListScreen()),
      GoRoute(path: Routes.newClient, builder: (_, _) => const NewClientScreen()),
      GoRoute(
        path: '/clients/detail/:id',
        builder: (_, state) =>
            ClientDetailScreen(clientId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'history',
            builder: (_, state) =>
                ClientHistoryScreen(clientId: state.pathParameters['id']!),
          ),
        ],
      ),

      GoRoute(
        path: Routes.travel,
        builder: (_, _) => const TravelDashboardScreen(),
      ),
      GoRoute(
        path: Routes.newTravelPlan,
        builder: (_, _) => const NewTravelPlanScreen(),
      ),
      GoRoute(
        path: '/travel/detail/:id',
        builder: (_, state) =>
            TravelDetailScreen(planId: state.pathParameters['id']!),
      ),

      GoRoute(path: Routes.expenses, builder: (_, _) => const ExpenseListScreen()),
      GoRoute(path: Routes.newExpense, builder: (_, _) => const NewExpenseScreen()),
      GoRoute(
        path: '/expenses/detail/:id',
        builder: (_, state) =>
            ExpenseDetailScreen(expenseId: state.pathParameters['id']!),
      ),

      GoRoute(path: Routes.hr, builder: (_, _) => const HrHomeScreen()),
      GoRoute(path: Routes.attendance, builder: (_, _) => const AttendanceScreen()),
      GoRoute(path: Routes.holidays, builder: (_, _) => const HolidaysScreen()),
      GoRoute(path: Routes.leaves, builder: (_, _) => const LeaveListScreen()),
      GoRoute(path: Routes.newLeave, builder: (_, _) => const NewLeaveScreen()),
      GoRoute(
        path: '/hr/leaves/:id',
        builder: (_, state) =>
            LeaveDetailScreen(leaveId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.payslips, builder: (_, _) => const PayslipsScreen()),
      GoRoute(path: Routes.documents, builder: (_, _) => const DocumentsScreen()),

      GoRoute(path: Routes.calendar, builder: (_, _) => const CalendarScreen()),

      GoRoute(path: Routes.chat, builder: (_, _) => const ChatListScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) =>
            ChatDetailScreen(threadId: state.pathParameters['id']!),
      ),

      GoRoute(path: Routes.resources, builder: (_, _) => const ResourceListScreen()),
      GoRoute(
        path: '/resources/:id',
        builder: (_, state) =>
            ResourceDetailScreen(resourceId: state.pathParameters['id']!),
      ),

      GoRoute(path: Routes.sales, builder: (_, _) => const SalesScreen()),
      GoRoute(path: Routes.targets, builder: (_, _) => const TargetsScreen()),
      GoRoute(path: Routes.orders, builder: (_, _) => const OrderListScreen()),
      GoRoute(path: Routes.newOrder, builder: (_, _) => const NewOrderScreen()),
      GoRoute(
        path: '/business/orders/:id',
        builder: (_, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),

      GoRoute(path: Routes.surveys, builder: (_, _) => const SurveyListScreen()),
      GoRoute(path: Routes.newSurvey, builder: (_, _) => const NewSurveyScreen()),
      GoRoute(
        path: Routes.complaints,
        builder: (_, _) => const ComplaintListScreen(),
      ),
      GoRoute(
        path: Routes.newComplaint,
        builder: (_, _) => const NewComplaintScreen(),
      ),
      GoRoute(
        path: '/complaints/:id',
        builder: (_, state) =>
            ComplaintDetailScreen(complaintId: state.pathParameters['id']!),
      ),

      GoRoute(path: Routes.dailyReport, builder: (_, _) => const DailyReportScreen()),
      GoRoute(path: Routes.visitReport, builder: (_, _) => const VisitReportScreen()),
      GoRoute(path: Routes.salesReport, builder: (_, _) => const SalesReportScreen()),
      GoRoute(
        path: Routes.targetReport,
        builder: (_, _) => const TargetReportScreen(),
      ),
      GoRoute(
        path: Routes.expenseReport,
        builder: (_, _) => const ExpenseReportScreen(),
      ),
      GoRoute(
        path: Routes.overviewReport,
        builder: (_, _) => const OverviewReportScreen(),
      ),

      GoRoute(
        path: '/team/employee/:id',
        builder: (_, state) =>
            EmployeeDetailScreen(employeeId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.teamMap, builder: (_, _) => const TeamMapScreen()),
      GoRoute(
        path: Routes.teamActivity,
        builder: (_, _) => const TeamActivityScreen(),
      ),
      GoRoute(
        path: Routes.teamPerformance,
        builder: (_, _) => const TeamPerformanceScreen(),
      ),

      GoRoute(
        path: Routes.approvals,
        builder: (_, _) => const ApprovalCenterScreen(),
      ),
      GoRoute(
        path: Routes.targetAssignment,
        builder: (_, _) => const TargetAssignmentScreen(),
      ),
      GoRoute(
        path: Routes.rateAssignment,
        builder: (_, _) => const RateAssignmentScreen(),
      ),
      GoRoute(
        path: Routes.taskAssignment,
        builder: (_, _) => const TaskAssignmentScreen(),
      ),
      GoRoute(path: Routes.tasks, builder: (_, _) => const TaskListScreen()),

      GoRoute(
        path: Routes.adminGeoFence,
        builder: (_, _) => const AdminGeoFenceScreen(),
      ),
      GoRoute(
        path: Routes.adminApprovalRules,
        builder: (_, _) => const AdminApprovalRulesScreen(),
      ),

      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: Routes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.help, builder: (_, _) => const HelpScreen()),
      GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(path: Routes.syncCenter, builder: (_, _) => const SyncCenterScreen()),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.path),
  );
});

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 40),
              const SizedBox(height: 16),
              Text('No screen at $location', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
