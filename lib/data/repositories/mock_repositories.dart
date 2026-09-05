import 'package:uuid/uuid.dart';

import '../../core/location/geo_math.dart';
import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/business.dart';
import '../../shared/models/client.dart';
import '../../shared/models/engagement.dart';
import '../../shared/models/field_ops.dart';
import '../../shared/models/organization.dart';
import '../mock/mock_dataset.dart';
import 'repositories.dart';

const _uuid = Uuid();

/// Simulated round-trip so loading states are exercised in development rather
/// than only appearing in production. Kept short enough not to be irritating.
Future<void> _latency([int ms = 260]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// Mutable in-memory store shared by every mock repository, so a visit created
/// on one screen is visible from every other — the same connectedness the real
/// system requires (§1).
class MockStore {
  MockStore._();
  static final MockStore instance = MockStore._();

  /// What a worked day pays, before anything is spent above it.
  ///
  /// Flat: every worked day, whatever the distance. Reference data a company
  /// maintains, so it lives here rather than in a screen and reaches the UI
  /// through `ExpenseRepository.dailyAllowance()`. It will come from
  /// `/master-data/allowances` behind the same call later.
  static const double dailyAllowance = 250;

  final _data = MockDataset.instance;

  /// The specialty master list.
  ///
  /// Static here because it is reference data a company maintains, not
  /// transactional data a rep creates — it is exactly the shape that will come
  /// from a `/master-data/specialties` endpoint later. It lived as a literal
  /// inside the admin screen before, where the client form could not reach it
  /// and the two would have drifted the first time anyone edited either.
  static const List<String> specialties = [
    'Cardiologist',
    'Dentist',
    'Dermatologist',
    'Diabetologist',
    'ENT Specialist',
    'Endocrinologist',
    'Gastroenterologist',
    'General Surgeon',
    'Gynecologist',
    'Hematologist',
    'Nephrologist',
    'Neurologist',
    'Neurosurgeon',
    'Oncologist',
    'Ophthalmologist',
    'Orthopedic',
    'Pediatrician',
    'Physician',
    'Psychiatrist',
    'Pulmonologist',
    'Radiologist',
    'Rheumatologist',
    'Urologist',
  ];

  late final List<Client> clients = [..._data.clients];
  late final List<Activity> activities = [..._data.activities];
  late final List<DayPlan> dayPlans = [..._data.dayPlans];
  late final List<Expense> expenses = [..._data.expenses];
  late final List<TravelPlan> travelPlans = [..._data.travelPlans];
  late final List<LeaveRequest> leaves = [..._data.leaveRequests];
  late final List<Order> orders = [..._data.orders];
  late final List<Target> targets = [..._data.targets];
  late final List<FieldTask> tasks = [..._data.tasks];
  late final List<AppNotification> notifications = [..._data.notifications];
  late final List<Complaint> complaints = [..._data.complaints];
  late final List<SurveyResponse> surveys = [..._data.surveys];
  late final Map<String, List<ChatMessage>> messages = {
    for (final entry in _data.chatMessages.entries) entry.key: [...entry.value],
  };

  MockDataset get seed => _data;

  /// Employee ids visible to [session]. The single place scope is resolved.
  Set<String> visibleEmployeeIds(Session session) {
    return switch (session.scope) {
      DataScope.self => {session.employee.id},
      DataScope.subtree =>
        _data.subtreeOf(session.employee.id).map((e) => e.id).toSet(),
      DataScope.global => _data.employees.map((e) => e.id).toSet(),
    };
  }

  /// Applies scope plus an optional explicit employee filter. Passing an
  /// [employeeId] outside the caller's scope yields nothing rather than
  /// leaking — defence in depth against a UI bug.
  bool canSee(Session session, String employeeId, {String? filterId}) {
    if (filterId != null && filterId != employeeId) return false;
    return visibleEmployeeIds(session).contains(employeeId);
  }
}

// ================================================================== auth ==

class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  final _data = MockDataset.instance;
  Session? _current;

  /// Any employee code from the seed signs in, with any non-empty password.
  /// This lets the whole role matrix be explored without a backend: sign in as
  /// MR1001 for the field experience, ASM201 for the manager one, ADM001 for
  /// administration.
  @override
  Future<Session> login({
    required String employeeCode,
    required String password,
  }) async {
    await _latency(700);

    final match = _data.employees
        .where((e) => e.employeeCode.toLowerCase() == employeeCode.toLowerCase().trim())
        .firstOrNull;

    if (match == null) {
      throw const AuthException('No employee found with that ID.');
    }
    if (password.trim().isEmpty) {
      throw const AuthException('Please enter your password.');
    }
    if (!match.isActive) {
      throw const AuthException('This account is inactive. Contact your administrator.');
    }

    return _current = Session(employee: match, loginAt: DateTime.now());
  }

  @override
  Future<void> logout() async {
    await _latency(200);
    _current = null;
  }

  @override
  Future<Session?> restoreSession() async => _current;

  @override
  Future<void> requestPasswordReset(String employeeCode) => _latency(600);

  @override
  Future<bool> verifyOtp({required String employeeCode, required String otp}) async {
    await _latency(600);
    // Fixed OTP for the mock build.
    return otp.trim() == '123456';
  }

  @override
  Future<void> resetPassword({required String employeeCode, required String password}) =>
      _latency(600);
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

// ============================================================= employees ==

class MockEmployeeRepository implements EmployeeRepository {
  final _store = MockStore.instance;

  @override
  Future<Employee> byId(String id) async {
    await _latency(120);
    return _store.seed.employees.firstWhere((e) => e.id == id);
  }

  @override
  Future<List<Employee>> visibleTo(Session session) async {
    await _latency();
    final ids = _store.visibleEmployeeIds(session);
    return _store.seed.employees.where((e) => ids.contains(e.id)).toList();
  }

  @override
  Future<List<Employee>> teamOf(Session session) async {
    await _latency();
    final ids = _store.visibleEmployeeIds(session)..remove(session.employee.id);
    return _store.seed.employees
        .where((e) => ids.contains(e.id))
        // The system owner is not part of anyone's sales team. Without this a
        // national manager's team list showed "System Administrator" while the
        // dashboard count, which walks the reporting tree, did not.
        .where((e) => e.role != UserRole.admin)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<Territory>> territories() async => _store.seed.territories;

  @override
  Future<List<Area>> areas({String? territoryId}) async {
    return _store.seed.areas
        .where((a) => territoryId == null || a.territoryId == territoryId)
        .toList();
  }

  @override
  Future<List<Cluster>> clusters({String? areaId}) async {
    return _store.seed.clusters
        .where((c) => areaId == null || c.areaId == areaId)
        .toList();
  }
}

// =============================================================== clients ==

class MockClientRepository implements ClientRepository {
  final _store = MockStore.instance;

  /// Sorted, so the picker's list is predictable and its search is the only
  /// thing that reorders anything.
  @override
  Future<List<String>> specialties() async {
    await _latency();
    return List.of(MockStore.specialties)..sort();
  }

  @override
  Future<List<Client>> list(
    Session session, {
    String? query,
    ClientType? type,
    String? areaId,
  }) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    final q = query?.trim().toLowerCase() ?? '';

    return _store.clients.where((c) {
      if (c.ownerEmployeeId != null && !visible.contains(c.ownerEmployeeId)) {
        return false;
      }
      if (type != null && c.type != type) return false;
      if (areaId != null && c.areaId != areaId) return false;
      if (q.isNotEmpty) {
        final haystack =
            '${c.name} ${c.specialty ?? ''} ${c.areaName} ${c.type.label}'
                .toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Client> byId(String id) async {
    await _latency(140);
    return _store.clients.firstWhere((c) => c.id == id);
  }

  @override
  Future<Client> create(Client client) async {
    await _latency(600);
    _store.clients.add(client);
    return client;
  }

  @override
  Future<Client> update(Client client) async {
    await _latency(400);
    final index = _store.clients.indexWhere((c) => c.id == client.id);
    if (index >= 0) _store.clients[index] = client;
    return client;
  }

  @override
  Future<List<Activity>> historyOf(String clientId) async {
    await _latency();
    return _store.activities
        .where((a) => a.clientId == clientId && a.status == ActivityStatus.completed)
        .toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
  }
}

// ============================================================ activities ==

class MockActivityRepository implements ActivityRepository {
  final _store = MockStore.instance;

  @override
  Future<List<Activity>> list(
    Session session, {
    DateTime? date,
    DateTime? from,
    DateTime? to,
    ActivityStatus? status,
    String? employeeId,
    String? clientId,
  }) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);

    return _store.activities.where((a) {
      if (!visible.contains(a.employeeId)) return false;
      if (employeeId != null && a.employeeId != employeeId) return false;
      if (clientId != null && a.clientId != clientId) return false;
      if (status != null && a.status != status) return false;
      if (date != null && !_sameDay(a.scheduledStart, date)) return false;
      if (from != null && a.scheduledStart.isBefore(from)) return false;
      if (to != null && a.scheduledStart.isAfter(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  }

  @override
  Future<Activity> byId(String id) async {
    await _latency(140);
    return _store.activities.firstWhere((a) => a.id == id);
  }

  @override
  Future<DaySummary> daySummary(String employeeId, DateTime date) async {
    await _latency(200);
    final employee =
        _store.seed.employees.firstWhere((e) => e.id == employeeId);

    final items = _store.activities
        .where((a) => a.employeeId == employeeId && _sameDay(a.scheduledStart, date))
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    // The intimation for this date, if the rep has filed one. It is what makes
    // the day "started" and what names a non-field day as a meeting or a
    // training — both facts the rep already typed into My Day Plan and which,
    // until now, reached no screen.
    final plan = _store.dayPlans
        .where((p) => p.employeeId == employeeId && _sameDay(p.date, date))
        .firstOrNull;

    return DaySummary(
      date: date,
      activities: items,
      headquarters: employee.headquarters,
      workType: plan?.workType ?? WorkType.fieldWork,
      declaredAt: plan?.submittedAt,
    );
  }

  @override
  Future<Activity> create(Activity activity) async {
    await _latency(500);
    _store.activities.add(activity);
    return activity;
  }

  @override
  Future<Activity> update(Activity activity) async {
    await _latency(400);
    _replace(activity);
    return activity;
  }

  @override
  Future<Activity> startVisit(String activityId) async {
    await _latency(300);
    final current = _store.activities.firstWhere((a) => a.id == activityId);
    final updated = current.copyWith(
      status: ActivityStatus.inProgress,
      actualStart: DateTime.now(),
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<Activity> completeVisit(Activity activity) async {
    await _latency(600);
    final completed = activity.copyWith(
      status: ActivityStatus.completed,
      actualEnd: DateTime.now(),
      syncStatus: SyncStatus.synced,
    );
    _replace(completed);

    // Completing a visit updates the client's history without re-entry (§1).
    final index = _store.clients.indexWhere((c) => c.id == activity.clientId);
    if (index >= 0) {
      final client = _store.clients[index];
      _store.clients[index] = client.copyWith(
        lastVisitAt: DateTime.now(),
        totalVisits: client.totalVisits + 1,
      );
    }
    return completed;
  }

  void _replace(Activity activity) {
    final index = _store.activities.indexWhere((a) => a.id == activity.id);
    if (index >= 0) {
      _store.activities[index] = activity;
    } else {
      _store.activities.add(activity);
    }
  }
}

// ============================================================== day plan ==

class MockDayPlanRepository implements DayPlanRepository {
  final _store = MockStore.instance;

  @override
  Future<DayPlan?> forDate(String employeeId, DateTime date) async {
    await _latency();
    return _store.dayPlans
        .where((p) =>
            p.employeeId == employeeId &&
            p.date.year == date.year &&
            p.date.month == date.month &&
            p.date.day == date.day)
        .firstOrNull;
  }

  @override
  Future<DayPlan> submit(DayPlan plan) async {
    await _latency();
    // One intimation per rep per day: a correction replaces the morning's
    // first answer rather than appearing beside it.
    _store.dayPlans.removeWhere((p) =>
        p.employeeId == plan.employeeId &&
        p.date.year == plan.date.year &&
        p.date.month == plan.date.month &&
        p.date.day == plan.date.day);
    _store.dayPlans.add(plan);
    return plan;
  }

  @override
  Future<List<DayPlan>> list(Session session, {String? employeeId}) async {
    await _latency();
    return _store.dayPlans
        .where((p) => _store.canSee(session, p.employeeId, filterId: employeeId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<String> addressFor(GeoPoint point, {String? areaId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _store.seed.addressFor(areaId: areaId, point: point);
  }
}

// ================================================================ travel ==

class MockTravelRepository implements TravelRepository {
  final _store = MockStore.instance;

  @override
  Future<List<TravelPlan>> list(
    Session session, {
    ApprovalStatus? status,
    String? employeeId,
  }) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);

    return _store.travelPlans.where((p) {
      if (!visible.contains(p.employeeId)) return false;
      if (employeeId != null && p.employeeId != employeeId) return false;
      if (status != null && p.status != status) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<TravelPlan> byId(String id) async =>
      _store.travelPlans.firstWhere((p) => p.id == id);

  @override
  Future<TravelPlan> create(TravelPlan plan) async {
    await _latency(500);
    _store.travelPlans.add(plan);
    return plan;
  }

  @override
  Future<TravelPlan> update(TravelPlan plan) async {
    await _latency(400);
    final index = _store.travelPlans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) _store.travelPlans[index] = plan;
    return plan;
  }

  @override
  Future<TravelPlan> submit(String id) async {
    await _latency(500);
    final index = _store.travelPlans.indexWhere((p) => p.id == id);
    final plan = _store.travelPlans[index];
    final updated = plan.copyWith(
      status: ApprovalStatus.submitted,
      approvalHistory: [
        ...plan.approvalHistory,
        ApprovalEvent(
          status: ApprovalStatus.submitted,
          actorId: plan.employeeId,
          actorName: plan.employeeName,
          actorRole: 'MR',
          at: DateTime.now(),
        ),
      ],
    );
    _store.travelPlans[index] = updated;
    return updated;
  }

  // ---------------------------------------------------------- by the month

  @override
  Future<TourMonth> month(
    Session session,
    DateTime month, {
    String? employeeId,
  }) async {
    await _latency(240);
    final id = employeeId ?? session.employee.id;

    return TourMonth(
      month: month,
      plans: {
        for (final p in _store.travelPlans)
          if (p.employeeId == id &&
              p.date.year == month.year &&
              p.date.month == month.month)
            p.date.day: p,
      },
    );
  }

  @override
  Future<TravelPlan> saveDay(TravelPlan plan) async {
    await _latency(400);

    // Replace by date, not by id. A rep correcting Tuesday is correcting
    // Tuesday; adding a second record would leave the manager two answers to
    // one question, and the calendar would have to pick one of them.
    final index = _store.travelPlans.indexWhere(
      (p) =>
          p.employeeId == plan.employeeId &&
          _sameDay(p.date, plan.date),
    );
    if (index >= 0) {
      _store.travelPlans[index] = plan;
    } else {
      _store.travelPlans.add(plan);
    }
    return plan;
  }

  @override
  Future<int> submitMonth(Session session, DateTime month) async {
    await _latency(600);

    final current = await this.month(session, month);
    // Asked of the store, not of anything the caller passed in. The screen
    // disables its button on a snapshot taken when it loaded; a month can
    // have lost a day since.
    if (!current.isComplete) return 0;

    var sent = 0;
    for (var i = 0; i < _store.travelPlans.length; i++) {
      final p = _store.travelPlans[i];
      if (p.employeeId != session.employee.id) continue;
      if (p.date.year != month.year || p.date.month != month.month) continue;
      if (p.status != ApprovalStatus.draft) continue;

      _store.travelPlans[i] = p.copyWith(
        status: ApprovalStatus.submitted,
        approvalHistory: [
          ...p.approvalHistory,
          ApprovalEvent(
            status: ApprovalStatus.submitted,
            actorId: p.employeeId,
            actorName: p.employeeName,
            actorRole: 'MR',
            at: DateTime.now(),
          ),
        ],
      );
      sent++;
    }
    return sent;
  }
}

// ============================================================== expenses ==

class MockExpenseRepository implements ExpenseRepository {
  final _store = MockStore.instance;

  @override
  Future<List<Expense>> list(
    Session session, {
    ApprovalStatus? status,
    String? employeeId,
  }) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);

    return _store.expenses.where((e) {
      if (!visible.contains(e.employeeId)) return false;
      if (employeeId != null && e.employeeId != employeeId) return false;
      if (status != null && e.status != status) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<Expense> byId(String id) async =>
      _store.expenses.firstWhere((e) => e.id == id);

  @override
  Future<Expense> create(Expense expense) async {
    await _latency(500);
    _store.expenses.add(expense);
    return expense;
  }

  @override
  Future<Expense> update(Expense expense) async {
    await _latency(400);
    final index = _store.expenses.indexWhere((e) => e.id == expense.id);
    if (index >= 0) _store.expenses[index] = expense;
    return expense;
  }

  @override
  Future<Expense> submit(String id) async {
    await _latency(500);
    final index = _store.expenses.indexWhere((e) => e.id == id);
    final expense = _store.expenses[index];
    final updated = expense.copyWith(
      status: ApprovalStatus.submitted,
      approvalHistory: [
        ...expense.approvalHistory,
        ApprovalEvent(
          status: ApprovalStatus.submitted,
          actorId: expense.employeeId,
          actorName: expense.employeeName,
          actorRole: 'MR',
          at: DateTime.now(),
        ),
      ],
    );
    _store.expenses[index] = updated;
    return updated;
  }

  // ------------------------------------------------------------- claiming

  @override
  Future<double> dailyAllowance() async {
    await _latency(120);
    return MockStore.dailyAllowance;
  }

  @override
  Future<List<ClaimDay>> claimMonth(
    Session session,
    DateTime month, {
    String? employeeId,
  }) async {
    await _latency(260);

    final id = employeeId ?? session.employee.id;
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;

    final plans = _store.dayPlans
        .where((p) => p.employeeId == id && inMonth(p.date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final filed = _store.expenses.where(
      (e) => e.employeeId == id && inMonth(e.date),
    );

    return [
      for (final plan in plans)
        ClaimDay(
          date: plan.date,
          dayPlanId: plan.id,
          workType: plan.workType,
          // The cluster is the more useful of the two — an area is a whole
          // city, a cluster is where he actually was.
          place: plan.clusterName ?? plan.areaName ?? '—',
          allowance: ClaimDay.isClaimable(plan.workType)
              ? MockStore.dailyAllowance
              : 0,
          // Matched on the day plan, not on the date. A claim belongs to the
          // intimation it was filed against, and matching by date would
          // silently attach it to a second plan for the same day.
          expenses: filed.where((e) => e.dayPlanId == plan.id).toList(),
          calls: _store.activities
              .where((a) =>
                  a.employeeId == id &&
                  a.status == ActivityStatus.completed &&
                  _sameDay(a.scheduledStart, plan.date))
              .length,
        ),
    ];
  }

  @override
  Future<int> confirmStandardDays(Session session, List<ClaimDay> days) async {
    await _latency(600);

    var added = 0;
    for (final day in days) {
      if (!day.claimable) continue;

      // Asked of the *store*, not of the ClaimDay handed in.
      //
      // A `ClaimDay` is a snapshot taken when the screen loaded, so after the
      // first confirm the object in the caller's list still reads as open —
      // and a second tap on "confirm all" paid every day again. Checking the
      // snapshot is checking a copy of the question. This is the guard that
      // makes the button safe to press twice, which is exactly what a rep
      // does when he is not sure it worked.
      final already = _store.expenses.any(
        (e) => e.dayPlanId == day.dayPlanId,
      );
      if (already) continue;

      _store.expenses.add(
        Expense(
          id: const Uuid().v4(),
          employeeId: session.employee.id,
          employeeName: session.employee.name,
          date: day.date,
          categories: const [ExpenseCategory.dailyAllowance],
          amount: day.allowance,
          status: ApprovalStatus.draft,
          description: 'Daily allowance',
          dayPlanId: day.dayPlanId,
          allowance: day.allowance,
          createdAt: DateTime.now(),
        ),
      );
      added++;
    }
    return added;
  }

  @override
  Future<int> submitMonth(Session session, DateTime month) async {
    await _latency(600);

    var sent = 0;
    for (var i = 0; i < _store.expenses.length; i++) {
      final e = _store.expenses[i];
      if (e.employeeId != session.employee.id) continue;
      if (e.date.year != month.year || e.date.month != month.month) continue;
      if (e.status != ApprovalStatus.draft) continue;

      _store.expenses[i] = e.copyWith(
        status: ApprovalStatus.submitted,
        approvalHistory: [
          ...e.approvalHistory,
          ApprovalEvent(
            status: ApprovalStatus.submitted,
            actorId: e.employeeId,
            actorName: e.employeeName,
            actorRole: 'MR',
            at: DateTime.now(),
          ),
        ],
      );
      sent++;
    }
    return sent;
  }
}

// ==================================================================== hr ==

class MockHrRepository implements HrRepository {
  final _store = MockStore.instance;

  /// Attendance is derived from activities and approved leave rather than
  /// stored separately — one source of truth, so a day cannot be "present" in
  /// attendance while showing no work in activity.
  ///
  /// Visits are only a proxy for attendance for people whose job is visiting.
  /// A manager or administrator who logs no calls is still at work, so for
  /// non-field roles a working day counts as present unless it is a holiday or
  /// approved leave. Deriving purely from visits painted their whole month red.
  @override
  Future<List<AttendanceRecord>> attendance(String employeeId, DateTime month) async {
    await _latency();

    final employee = _store.seed.employees
        .where((e) => e.id == employeeId)
        .firstOrNull;
    final derivesFromVisits = employee?.role == UserRole.mr;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final holidays = _store.seed.holidays;
    final approvedLeave = _store.leaves.where(
      (l) => l.employeeId == employeeId && l.status == ApprovalStatus.approved,
    );
    final today = _store.seed.today;

    final records = <AttendanceRecord>[];

    for (var day = 1; day <= days; day++) {
      final date = DateTime(month.year, month.month, day);
      if (date.isAfter(today)) break;

      final isHoliday = holidays.any((h) => _sameDay(h.date, date));
      final isLeave = approvedLeave.any(
        (l) => !date.isBefore(_dateOnly(l.fromDate)) && !date.isAfter(_dateOnly(l.toDate)),
      );
      final hasWork = _store.activities.any(
        (a) =>
            a.employeeId == employeeId &&
            _sameDay(a.scheduledStart, date) &&
            a.status == ActivityStatus.completed,
      );

      final status = isHoliday
          ? AttendanceStatus.holiday
          // A Sunday is a week off unless the rep actually worked it — the
          // calendar must agree with the visits it is derived from.
          : (date.weekday == DateTime.sunday && !hasWork)
              ? AttendanceStatus.weekOff
              : isLeave
                  ? AttendanceStatus.leave
                  : (hasWork || !derivesFromVisits)
                      ? AttendanceStatus.present
                      : AttendanceStatus.absent;

      records.add(
        AttendanceRecord(
          date: date,
          status: status,
          checkIn: status == AttendanceStatus.present
              ? date.add(const Duration(hours: 9, minutes: 12))
              : null,
          checkOut: status == AttendanceStatus.present
              ? date.add(const Duration(hours: 18, minutes: 24))
              : null,
          workType: status != AttendanceStatus.present
              ? null
              : hasWork
                  ? WorkType.fieldWork
                  : WorkType.officeWork,
        ),
      );
    }
    return records;
  }

  @override
  Future<List<LeaveRequest>> leaves(Session session, {String? employeeId}) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.leaves
        .where((l) =>
            visible.contains(l.employeeId) &&
            (employeeId == null || l.employeeId == employeeId))
        .toList()
      ..sort((a, b) => b.fromDate.compareTo(a.fromDate));
  }

  @override
  Future<LeaveRequest> applyLeave(LeaveRequest request) async {
    await _latency(600);
    _store.leaves.add(request);
    return request;
  }

  @override
  Future<List<Holiday>> holidays(int year) async {
    await _latency(160);
    return _store.seed.holidays.where((h) => h.date.year == year).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<Payslip>> payslips(String employeeId) async {
    await _latency();
    return _store.seed.payslips;
  }

  @override
  Future<List<AppDocument>> documents(String employeeId) async {
    await _latency();
    return _store.seed.documents;
  }
}

// ============================================================== business ==

class MockBusinessRepository implements BusinessRepository {
  final _store = MockStore.instance;

  @override
  Future<List<SalesRecord>> sales(Session session, {String? employeeId, int? year}) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.seed.salesRecords
        .where((s) =>
            visible.contains(s.employeeId) &&
            (employeeId == null || s.employeeId == employeeId) &&
            (year == null || s.month.year == year))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  @override
  Future<List<Target>> targets(Session session, {String? employeeId, DateTime? month}) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.targets
        .where((t) =>
            visible.contains(t.employeeId) &&
            (employeeId == null || t.employeeId == employeeId) &&
            (month == null ||
                (t.month.year == month.year && t.month.month == month.month)))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  @override
  Future<Target> saveTarget(Target target) async {
    await _latency(400);
    final index = _store.targets.indexWhere((t) => t.id == target.id);
    if (index >= 0) {
      _store.targets[index] = target;
    } else {
      _store.targets.add(target);
    }
    return target;
  }

  @override
  Future<List<Order>> orders(Session session, {ApprovalStatus? status, String? employeeId}) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.orders
        .where((o) =>
            visible.contains(o.employeeId) &&
            (employeeId == null || o.employeeId == employeeId) &&
            (status == null || o.status == status))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<Order> orderById(String id) async =>
      _store.orders.firstWhere((o) => o.id == id);

  @override
  Future<Order> createOrder(Order order) async {
    await _latency(600);
    _store.orders.insert(0, order);
    return order;
  }

  @override
  Future<List<Product>> products() async {
    await _latency(160);
    return _store.seed.products;
  }
}

// ============================================================= approvals ==

class MockApprovalRepository implements ApprovalRepository {
  final _store = MockStore.instance;

  /// Projects the four approvable record types into one queue.
  List<ApprovalItem> _project(Session session, {required bool decided, ApprovalKind? kind}) {
    final visible = _store.visibleEmployeeIds(session)
      ..remove(session.employee.id); // a manager does not approve their own
    final items = <ApprovalItem>[];

    bool matches(ApprovalStatus s) => decided ? s.isDecided : s.awaitsDecision;

    if (kind == null || kind == ApprovalKind.expense) {
      for (final e in _store.expenses) {
        if (!visible.contains(e.employeeId) || !matches(e.status)) continue;
        items.add(ApprovalItem(
          id: 'ap-exp-${e.id}',
          kind: ApprovalKind.expense,
          recordId: e.id,
          employeeId: e.employeeId,
          employeeName: e.employeeName,
          title: e.category.label,
          subtitle: e.description,
          submittedAt: e.createdAt ?? e.date,
          status: e.status,
          amount: e.amount,
          date: e.date,
        ));
      }
    }

    if (kind == null || kind == ApprovalKind.leave) {
      for (final l in _store.leaves) {
        if (!visible.contains(l.employeeId) || !matches(l.status)) continue;
        items.add(ApprovalItem(
          id: 'ap-lv-${l.id}',
          kind: ApprovalKind.leave,
          recordId: l.id,
          employeeId: l.employeeId,
          employeeName: l.employeeName,
          title: '${l.type.label} · ${l.days} day${l.days == 1 ? '' : 's'}',
          subtitle: l.reason,
          submittedAt: l.createdAt ?? l.fromDate,
          status: l.status,
          date: l.fromDate,
        ));
      }
    }

    if (kind == null || kind == ApprovalKind.tourPlan) {
      for (final t in _store.travelPlans) {
        if (!visible.contains(t.employeeId) || !matches(t.status)) continue;
        items.add(ApprovalItem(
          id: 'ap-tp-${t.id}',
          kind: ApprovalKind.tourPlan,
          recordId: t.id,
          employeeId: t.employeeId,
          employeeName: t.employeeName,
          title: '${t.areaName ?? 'Tour'} · ${t.plannedVisits} visits',
          subtitle: t.purpose,
          submittedAt: t.createdAt ?? t.date,
          status: t.status,
          date: t.date,
        ));
      }
    }

    if (kind == null || kind == ApprovalKind.order) {
      for (final o in _store.orders) {
        if (!visible.contains(o.employeeId) || !matches(o.status)) continue;
        items.add(ApprovalItem(
          id: 'ap-ord-${o.id}',
          kind: ApprovalKind.order,
          recordId: o.id,
          employeeId: o.employeeId,
          employeeName: o.employeeName,
          title: '${o.orderNumber} · ${o.clientName}',
          subtitle: '${o.lineCount} product${o.lineCount == 1 ? '' : 's'}',
          submittedAt: o.date,
          status: o.status,
          amount: o.grandTotal,
          date: o.date,
        ));
      }
    }

    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  @override
  Future<List<ApprovalItem>> pending(Session session, {ApprovalKind? kind}) async {
    await _latency();
    return _project(session, decided: false, kind: kind);
  }

  @override
  Future<List<ApprovalItem>> decided(Session session, {ApprovalKind? kind}) async {
    await _latency();
    return _project(session, decided: true, kind: kind);
  }

  @override
  Future<void> approve(Session session, ApprovalItem item, {String? comment}) =>
      _decide(session, item, ApprovalStatus.approved, comment: comment);

  @override
  Future<void> reject(Session session, ApprovalItem item, {required String reason}) =>
      _decide(session, item, ApprovalStatus.rejected, reason: reason);

  @override
  Future<void> approveAll(Session session, List<ApprovalItem> items) async {
    for (final item in items) {
      await _decide(session, item, ApprovalStatus.approved, delay: false);
    }
    await _latency(400);
  }

  /// Writes the decision and appends to the record's approval history. History
  /// is never overwritten (§62, §69).
  Future<void> _decide(
    Session session,
    ApprovalItem item,
    ApprovalStatus status, {
    String? reason,
    String? comment,
    bool delay = true,
  }) async {
    if (delay) await _latency(450);

    final event = ApprovalEvent(
      status: status,
      actorId: session.employee.id,
      actorName: session.employee.name,
      actorRole: session.role.shortLabel,
      at: DateTime.now(),
      reason: reason,
      comment: comment,
    );

    switch (item.kind) {
      case ApprovalKind.expense:
        final i = _store.expenses.indexWhere((e) => e.id == item.recordId);
        if (i >= 0) {
          _store.expenses[i] = _store.expenses[i].copyWith(
            status: status,
            approvalHistory: [..._store.expenses[i].approvalHistory, event],
          );
        }
      case ApprovalKind.leave:
        final i = _store.leaves.indexWhere((l) => l.id == item.recordId);
        if (i >= 0) {
          _store.leaves[i] = _store.leaves[i].copyWith(
            status: status,
            approvalHistory: [..._store.leaves[i].approvalHistory, event],
          );
        }
      case ApprovalKind.tourPlan:
        final i = _store.travelPlans.indexWhere((t) => t.id == item.recordId);
        if (i >= 0) {
          _store.travelPlans[i] = _store.travelPlans[i].copyWith(
            status: status,
            approvalHistory: [..._store.travelPlans[i].approvalHistory, event],
          );
        }
      case ApprovalKind.order:
        final i = _store.orders.indexWhere((o) => o.id == item.recordId);
        if (i >= 0) {
          _store.orders[i] = _store.orders[i].copyWith(
            status: status,
            approvalHistory: [..._store.orders[i].approvalHistory, event],
          );
        }
      case ApprovalKind.other:
        break;
    }
  }
}

// ================================================================= tasks ==

class MockTaskRepository implements TaskRepository {
  final _store = MockStore.instance;

  @override
  Future<List<FieldTask>> list(Session session, {String? employeeId, TaskStatus? status}) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.tasks
        .where((t) =>
            visible.contains(t.assignedToId) &&
            (employeeId == null || t.assignedToId == employeeId) &&
            (status == null || t.effectiveStatus() == status))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  Future<FieldTask> create(FieldTask task) async {
    await _latency(500);
    _store.tasks.add(task);
    return task;
  }

  @override
  Future<FieldTask> updateStatus(String id, TaskStatus status) async {
    await _latency(300);
    final i = _store.tasks.indexWhere((t) => t.id == id);
    final updated = _store.tasks[i].copyWith(
      status: status,
      completedAt: status == TaskStatus.completed ? DateTime.now() : null,
    );
    _store.tasks[i] = updated;
    return updated;
  }
}

// ========================================================= notifications ==

class MockNotificationRepository implements NotificationRepository {
  final _store = MockStore.instance;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    await _latency(200);
    return _store.notifications.where((n) => !unreadOnly || !n.isRead).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markRead(String id) async {
    final i = _store.notifications.indexWhere((n) => n.id == id);
    if (i >= 0) _store.notifications[i] = _store.notifications[i].copyWith(isRead: true);
  }

  @override
  Future<void> markAllRead() async {
    await _latency(200);
    for (var i = 0; i < _store.notifications.length; i++) {
      _store.notifications[i] = _store.notifications[i].copyWith(isRead: true);
    }
  }

  @override
  Future<int> unreadCount() async =>
      _store.notifications.where((n) => !n.isRead).length;
}

// ================================================================== chat ==

class MockChatRepository implements ChatRepository {
  final _store = MockStore.instance;

  @override
  Future<List<ChatThread>> threads({String? query}) async {
    await _latency();
    final q = query?.trim().toLowerCase() ?? '';
    return _store.seed.chatThreads
        .where((t) => q.isEmpty || t.title.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.lastMessageAt.compareTo(a.lastMessageAt);
      });
  }

  @override
  Future<List<ChatMessage>> messages(String threadId) async {
    await _latency(200);
    return [...?_store.messages[threadId]];
  }

  @override
  Future<ChatMessage> send(String threadId, String text) async {
    final message = ChatMessage(
      id: _uuid.v4(),
      threadId: threadId,
      senderId: _store.seed.currentUser.id,
      senderName: _store.seed.currentUser.name,
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
    );
    (_store.messages[threadId] ??= []).add(message);
    await _latency(150);
    return message;
  }
}

// ============================================================= resources ==

class MockResourceRepository implements ResourceRepository {
  final _store = MockStore.instance;

  @override
  Future<List<Resource>> list({String? query, String? category}) async {
    await _latency();
    final q = query?.trim().toLowerCase() ?? '';
    return _store.seed.resources.where((r) {
      if (category != null && category != 'All' && r.category != category) return false;
      if (q.isNotEmpty && !r.title.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Future<Resource> byId(String id) async =>
      _store.seed.resources.firstWhere((r) => r.id == id);
}

// =============================================== surveys and complaints ==

class MockSurveyRepository implements SurveyRepository {
  final _store = MockStore.instance;

  @override
  Future<List<SurveyResponse>> list(Session session) async {
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.surveys.where((s) => visible.contains(s.employeeId)).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  @override
  Future<SurveyResponse> create(SurveyResponse response) async {
    await _latency(500);
    _store.surveys.insert(0, response);
    return response;
  }
}

class MockComplaintRepository implements ComplaintRepository {
  final _store = MockStore.instance;

  @override
  Future<List<Complaint>> list(Session session, {ComplaintStatus? status}) async {
    await _latency();
    return _store.complaints.where((c) => status == null || c.status == status).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Complaint> byId(String id) async =>
      _store.complaints.firstWhere((c) => c.id == id);

  @override
  Future<Complaint> create(Complaint complaint) async {
    await _latency(500);
    _store.complaints.insert(0, complaint);
    return complaint;
  }
}

// =============================================================== helpers ==

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Exposed for the report repository, which lives in its own file but shares
/// these conventions.
bool sameDay(DateTime a, DateTime b) => _sameDay(a, b);

DateTime dateOnly(DateTime d) => _dateOnly(d);

/// Shared RNG-free helper for deterministic pseudo-variation in derived demo
/// figures (e.g. distance travelled), keyed off a stable string.
double stableJitter(String seed, double min, double max) {
  final hash = seed.codeUnits.fold<int>(7, (acc, c) => (acc * 31 + c) & 0x7fffffff);
  return min + (hash % 1000) / 1000 * (max - min);
}

/// Kept so callers can generate ids without importing uuid everywhere.
String newId() => _uuid.v4();
