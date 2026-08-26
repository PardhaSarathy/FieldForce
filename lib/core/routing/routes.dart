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

  // home
  static const dayPlan = '/home/day-plan';

  // activity
  static const addActivity = '/activity/add';
  static String activityDetail(String id) => '/activity/detail/$id';
  static String visitFlow(String id) => '/activity/visit/$id';

  // clients
  static const clients = '/clients';
  static const newClient = '/clients/new';
  static String clientDetail(String id) => '/clients/detail/$id';
  static String clientHistory(String id) => '/clients/detail/$id/history';

  // travel
  static const travel = '/travel';
  static const newTravelPlan = '/travel/new';
  static String travelDetail(String id) => '/travel/detail/$id';

  // expenses
  static const expenses = '/expenses';
  static const newExpense = '/expenses/new';
  static String expenseDetail(String id) => '/expenses/detail/$id';

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
  static String approvalDetail(String id) => '/approvals/$id';
  static const targetAssignment = '/manage/targets';
  static const rateAssignment = '/manage/rates';
  static const taskAssignment = '/manage/tasks';
  static const tasks = '/tasks';

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
  static const notificationSettings = '/settings/notifications';
  static const help = '/help';
  static const search = '/search';
  static const syncCenter = '/sync';
}
