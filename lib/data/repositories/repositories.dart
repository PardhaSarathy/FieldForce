import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/business.dart';
import '../../shared/models/client.dart';
import '../../shared/models/engagement.dart';
import '../../shared/models/field_ops.dart';
import '../../shared/models/organization.dart';

/// Repository contracts (§7).
///
/// The presentation layer depends only on these interfaces. A remote (API),
/// local (database) or mock implementation can be swapped in without any UI
/// change — which is what makes the current mock-first build disposable in the
/// right way.
///
/// Every method that returns employee-scoped data takes the caller's [Session]
/// so that scope filtering happens in one place rather than being re-derived
/// per screen. The server must enforce the same rules (§70).

abstract interface class AuthRepository {
  Future<Session> login({required String employeeCode, required String password});
  Future<void> logout();
  Future<Session?> restoreSession();
  Future<void> requestPasswordReset(String employeeCode);
  Future<bool> verifyOtp({required String employeeCode, required String otp});
  Future<void> resetPassword({required String employeeCode, required String password});
}

abstract interface class EmployeeRepository {
  Future<Employee> byId(String id);

  /// Employees visible to [session] under its [DataScope].
  Future<List<Employee>> visibleTo(Session session);

  /// Direct and indirect reports only, excluding the manager themselves.
  Future<List<Employee>> teamOf(Session session);

  Future<List<Territory>> territories();
  Future<List<Area>> areas({String? territoryId});
  Future<List<Cluster>> clusters({String? areaId});
}

abstract interface class ClientRepository {
  Future<List<Client>> list(
    Session session, {
    String? query,
    ClientType? type,
    String? areaId,
  });
  Future<Client> byId(String id);
  Future<Client> create(Client client);
  Future<Client> update(Client client);

  /// Completed visits to this client, newest first (§28 client history).
  Future<List<Activity>> historyOf(String clientId);
}

abstract interface class ActivityRepository {
  Future<List<Activity>> list(
    Session session, {
    DateTime? date,
    DateTime? from,
    DateTime? to,
    ActivityStatus? status,
    String? employeeId,
    String? clientId,
  });

  Future<Activity> byId(String id);

  /// Today's derived summary for [employeeId] — the source of Home's content.
  Future<DaySummary> daySummary(String employeeId, DateTime date);

  Future<Activity> create(Activity activity);
  Future<Activity> update(Activity activity);

  /// Transitions a planned activity to in-progress and stamps the start time.
  Future<Activity> startVisit(String activityId);

  /// Completes a visit with its feedback and geo evidence.
  Future<Activity> completeVisit(Activity activity);
}

abstract interface class TravelRepository {
  Future<List<TravelPlan>> list(Session session, {ApprovalStatus? status, String? employeeId});
  Future<TravelPlan> byId(String id);
  Future<TravelPlan> create(TravelPlan plan);
  Future<TravelPlan> submit(String id);
}

abstract interface class ExpenseRepository {
  Future<List<Expense>> list(Session session, {ApprovalStatus? status, String? employeeId});
  Future<Expense> byId(String id);
  Future<Expense> create(Expense expense);
  Future<Expense> update(Expense expense);
  Future<Expense> submit(String id);
}

abstract interface class HrRepository {
  Future<List<AttendanceRecord>> attendance(String employeeId, DateTime month);
  Future<List<LeaveRequest>> leaves(Session session, {String? employeeId});
  Future<LeaveRequest> applyLeave(LeaveRequest request);
  Future<List<Holiday>> holidays(int year);
  Future<List<Payslip>> payslips(String employeeId);
  Future<List<AppDocument>> documents(String employeeId);
}

abstract interface class BusinessRepository {
  Future<List<SalesRecord>> sales(Session session, {String? employeeId, int? year});
  Future<List<Target>> targets(Session session, {String? employeeId, DateTime? month});
  Future<Target> saveTarget(Target target);
  Future<List<Order>> orders(Session session, {ApprovalStatus? status, String? employeeId});
  Future<Order> orderById(String id);
  Future<Order> createOrder(Order order);
  Future<List<Product>> products();
}

abstract interface class ApprovalRepository {
  /// The unified queue across leave, expense, travel and order (§43).
  Future<List<ApprovalItem>> pending(Session session, {ApprovalKind? kind});
  Future<List<ApprovalItem>> decided(Session session, {ApprovalKind? kind});
  Future<void> approve(Session session, ApprovalItem item, {String? comment});
  Future<void> reject(Session session, ApprovalItem item, {required String reason});
  Future<void> approveAll(Session session, List<ApprovalItem> items);
}

abstract interface class TaskRepository {
  Future<List<FieldTask>> list(Session session, {String? employeeId, TaskStatus? status});
  Future<FieldTask> create(FieldTask task);
  Future<FieldTask> updateStatus(String id, TaskStatus status);
}

abstract interface class NotificationRepository {
  Future<List<AppNotification>> list({bool unreadOnly = false});
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<int> unreadCount();
}

abstract interface class ChatRepository {
  Future<List<ChatThread>> threads({String? query});
  Future<List<ChatMessage>> messages(String threadId);
  Future<ChatMessage> send(String threadId, String text);
}

abstract interface class ResourceRepository {
  Future<List<Resource>> list({String? query, String? category});
  Future<Resource> byId(String id);
}

abstract interface class SurveyRepository {
  Future<List<SurveyResponse>> list(Session session);
  Future<SurveyResponse> create(SurveyResponse response);
}

abstract interface class ComplaintRepository {
  Future<List<Complaint>> list(Session session, {ComplaintStatus? status});
  Future<Complaint> byId(String id);
  Future<Complaint> create(Complaint complaint);
}

/// Aggregated reporting (§33–§39).
///
/// These are *derived* views. In production every method here is a server
/// endpoint — an RSM's quarterly report spans far too many rows to aggregate on
/// a handset (§66.9). The interface hides that, so the screens never change.
abstract interface class ReportRepository {
  Future<DailyReport> daily(Session session, {required DateTime from, required DateTime to, String? employeeId});
  Future<VisitReport> visits(Session session, {required DateTime from, required DateTime to, String? employeeId, String? areaId, ClientType? clientType});
  Future<SalesReport> salesReport(Session session, {required int year, String? employeeId});
  Future<TargetReport> targetReport(Session session, {required DateTime month, String? employeeId});
  Future<ExpenseReport> expenseReport(Session session, {required DateTime month, String? employeeId});
  Future<OverviewReport> overview(Session session, {required DateTime month, String? employeeId});
  Future<ManagerDashboard> managerDashboard(Session session);
}

// ============================================================ report shapes ==

class DailyReport {
  const DailyReport({
    required this.workingDays,
    required this.fieldDays,
    required this.totalVisits,
    required this.completed,
    required this.missed,
    required this.clientsCovered,
    required this.orders,
    required this.orderValue,
    required this.expenseTotal,
    required this.distanceKm,
    required this.trend,
  });

  final int workingDays;
  final int fieldDays;
  final int totalVisits;
  final int completed;
  final int missed;
  final int clientsCovered;
  final int orders;
  final double orderValue;
  final double expenseTotal;
  final double distanceKm;
  final List<ChartPoint> trend;

  double get completionRate =>
      totalVisits == 0 ? 0 : (completed / totalVisits) * 100;
}

class VisitReport {
  const VisitReport({
    required this.total,
    required this.completed,
    required this.missed,
    required this.rescheduled,
    required this.averageDuration,
    required this.uniqueClients,
    required this.byClientType,
    required this.trend,
    required this.verifiedCount,
  });

  final int total;
  final int completed;
  final int missed;
  final int rescheduled;
  final Duration averageDuration;
  final int uniqueClients;
  final Map<ClientType, int> byClientType;
  final List<ChartPoint> trend;

  /// How many completed visits passed the geo-fence. A coverage number without
  /// this is not trustworthy.
  final int verifiedCount;

  double get coverage => total == 0 ? 0 : (completed / total) * 100;
  double get verificationRate =>
      completed == 0 ? 0 : (verifiedCount / completed) * 100;
}

class SalesReport {
  const SalesReport({
    required this.total,
    required this.target,
    required this.primary,
    required this.secondary,
    required this.monthly,
    required this.byProduct,
  });

  final double total;
  final double target;
  final double primary;
  final double secondary;
  final List<ChartPoint> monthly;
  final List<ProductSales> byProduct;

  double get achievement => target <= 0 ? 0 : (total / target) * 100;
}

class TargetReport {
  const TargetReport({
    required this.target,
    required this.achieved,
    required this.rows,
    required this.trend,
  });

  final double target;
  final double achieved;
  final List<Target> rows;
  final List<ChartPoint> trend;

  double get gap => (target - achieved).clamp(0, double.infinity);
  double get achievement => target <= 0 ? 0 : (achieved / target) * 100;
}

class ExpenseReport {
  const ExpenseReport({
    required this.byCategory,
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.trend,
  });

  final Map<ExpenseCategory, double> byCategory;
  final double total;
  final double approved;
  final double pending;
  final double rejected;
  final List<ChartPoint> trend;
}

class OverviewReport {
  const OverviewReport({
    required this.workingDays,
    required this.fieldDays,
    required this.leaveDays,
    required this.nonFieldDays,
    required this.visits,
    required this.completedVisits,
    required this.newClients,
    required this.hospitalCoverage,
    required this.sales,
    required this.target,
    required this.expenses,
  });

  final int workingDays;
  final int fieldDays;
  final int leaveDays;
  final int nonFieldDays;
  final int visits;
  final int completedVisits;
  final int newClients;
  final int hospitalCoverage;
  final double sales;
  final double target;
  final double expenses;

  double get achievement => target <= 0 ? 0 : (sales / target) * 100;
}

/// Exception-first manager view (§40, §79). The counts here are what a manager
/// must act on today, not a general performance summary.
class ManagerDashboard {
  const ManagerDashboard({
    required this.teamSize,
    required this.presentToday,
    required this.visitsPlanned,
    required this.visitsCompleted,
    required this.pendingApprovals,
    required this.pendingByKind,
    required this.sales,
    required this.target,
    required this.orderCount,
    required this.expenseTotal,
    required this.behindPlanCount,
    required this.unverifiedVisits,
  });

  final int teamSize;
  final int presentToday;
  final int visitsPlanned;
  final int visitsCompleted;
  final int pendingApprovals;
  final Map<ApprovalKind, int> pendingByKind;
  final double sales;
  final double target;
  final int orderCount;
  final double expenseTotal;

  /// Team members whose completion is materially behind the day's pace.
  final int behindPlanCount;

  final int unverifiedVisits;

  double get achievement => target <= 0 ? 0 : (sales / target) * 100;
  int get visitGap => visitsPlanned - visitsCompleted;
}
