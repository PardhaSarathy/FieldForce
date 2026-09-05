/// Canonical route paths.
///
/// Centralised as constants so deep links (from notifications, chat and
/// approvals) reference the same strings the router declares — a typo becomes a
/// compile error rather than a dead link at runtime.
abstract final class Routes {
  // auth
  static const splash = '/splash';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const otp = '/otp';
  static const resetPassword = '/reset-password';

  // shell tabs
  static const home = '/home';
  static const activity = '/activity';
  static const business = '/business';
  static const reports = '/reports';
  static const more = '/more';

  // manager tabs (replaces business for managers)
  static const team = '/team';

  /// Roots of the tabbed shell's branches.
  ///
  /// These must be *navigated to*, never pushed: pushing one lands it on that
  /// branch's own navigator, which the indexed stack is not currently showing,
  /// so the screen appears not to open at all. [navigateTo] picks the right
  /// verb; anything reached from a menu or a tile should go through it.
  static const shellRoots = {
    home,
    activity,
    team,
    reports,
    chat,
    resources,
    tasks,
    admin,
    adminUsers,
    adminMasterData,
  };

  // day plan — the morning intimation, not a schedule
  static const dayPlan = '/home/day-plan';

  // activity
  static const addActivity = '/activity/add';
  static String activityDetail(String id) => '/activity/detail/$id';
  static String editActivity(String id) => '/activity/detail/$id/edit';
  static String visitFlow(String id) => '/activity/visit/$id';

  // clients
  static const clients = '/clients';
  static const newClient = '/clients/new';
  static String clientDetail(String id) => '/clients/detail/$id';
  static String clientHistory(String id) => '/clients/detail/$id/history';
  static String editClient(String id) => '/clients/detail/$id/edit';

  // travel — the tour plan. It was a hub with two doors behind it, and the
  // second one (expenses) is now a module of its own on Home, which left the
  // hub asking a question with a single answer.
  static const travelPlans = '/travel/plans';

  /// One day of the tour plan, addressed by its date.
  ///
  /// By date rather than by record id, because the screen exists before the
  /// record does — the whole point is planning a day nothing has been saved
  /// against yet. On one line so `no_dead_controls_test`, which reads this
  /// file as text, can still find the path behind the name.
  static String tourPlanDay(DateTime d) => '/travel/plans/day/${isoDay(d)}';

  static String travelDetail(String id) => '/travel/detail/$id';

  // expenses
  static const expenses = '/expenses';

  /// One declared day's claim, addressed by its date.
  ///
  /// By date rather than by a record id, because the screen exists before the
  /// record does — the whole point is claiming a day nothing has been filed
  /// against yet.
  /// The name and the path literal share a line on purpose. Split across
  /// two, `no_dead_controls_test` can no longer tell which screen is behind
  /// this constant — the guard reads this file as text, so a route written
  /// across several lines is a route that quietly stops being checked. The
  /// date formatting lives in [isoDay] below for exactly that reason.
  static String claimDay(DateTime d) => '/expenses/day/${isoDay(d)}';
  static String expenseDetail(String id) => '/expenses/detail/$id';
  static String editExpense(String id) => '/expenses/detail/$id/edit';

  // hr
  static const hr = '/hr';
  static const attendance = '/hr/attendance';
  static const holidays = '/hr/holidays';
  static const leaves = '/hr/leaves';
  static const newLeave = '/hr/leaves/new';
  static String leaveDetail(String id) => '/hr/leaves/$id';
  static const payslips = '/hr/payslips';
  static const documents = '/hr/documents';

  // calendar
  static const calendar = '/calendar';

  // chat
  static const chat = '/chat';
  static String chatDetail(String id) => '/chat/$id';

  // resources
  static const resources = '/resources';
  static String resourceDetail(String id) => '/resources/$id';

  // business
  static const sales = '/business/sales';
  static const targets = '/business/targets';
  static const orders = '/business/orders';
  static const newOrder = '/business/orders/new';
  static String orderDetail(String id) => '/business/orders/$id';

  // survey & complaints
  static const surveys = '/surveys';
  static const newSurvey = '/surveys/new';
  static const complaints = '/complaints';
  static const newComplaint = '/complaints/new';
  static String complaintDetail(String id) => '/complaints/$id';

  // reports
  static const dailyReport = '/reports/daily';
  static const visitReport = '/reports/visits';
  static const salesReport = '/reports/sales';
  static const targetReport = '/reports/targets';
  static const expenseReport = '/reports/expenses';
  static const overviewReport = '/reports/overview';

  // manager
  static String employeeDetail(String id) => '/team/employee/$id';
  static const teamMap = '/team/map';
  static const teamActivity = '/team/activity';
  static const teamPerformance = '/team/performance';
  static const approvals = '/approvals';
  static const targetAssignment = '/manage/targets';
  static const rateAssignment = '/manage/rates';
  static const taskAssignment = '/manage/tasks';
  static const tasks = '/tasks';
  static const newTask = '/tasks/new';

  // admin
  static const admin = '/admin';
  static const adminUsers = '/admin/users';
  static const adminMasterData = '/admin/master-data';
  static const adminGeoFence = '/admin/geo-fence';
  static const adminApprovalRules = '/admin/approval-rules';

  // global
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const help = '/help';
  static const search = '/search';
  static const syncCenter = '/sync';
}

/// `2026-09-04` — the path segment [Routes.claimDay] addresses a day by.
String isoDay(DateTime d) => d.toIso8601String().substring(0, 10);
