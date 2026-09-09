import 'package:uuid/uuid.dart';

import '../../core/location/geo_math.dart';
import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/business.dart';
import '../../shared/models/client.dart';
import '../../shared/models/engagement.dart';
import '../../shared/models/export.dart';
import '../../shared/models/field_ops.dart';
import '../../shared/models/organization.dart';
import '../mock/mock_dataset.dart';
import 'identity_map.dart';
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

  /// Which weekday nobody plans or claims for.
  ///
  /// Reference data a company maintains, like the allowance above — some field
  /// forces run Tuesday-off. It was `DateTime.sunday` written into four
  /// separate places that all had to agree; this is the one they read.
  static const int weekOff = DateTime.sunday;

  /// The rule each submitted month was judged against.
  ///
  /// Keyed by employee and month. Written once, when the month goes in, and
  /// never recomputed — see the note on `TourMonth.workingDays`.
  final Map<String, TourRule> tourRules = {};

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
  ///
  /// Resolved entirely in *seed* ids. Live, a session carries the employee's
  /// Supabase uuid and every record here is keyed by `emp-1`, so both sides of
  /// every comparison have to move together — translating only the id being
  /// checked would compare `emp-1` against a set built from a uuid, and the
  /// guards below would refuse the owner their own records.
  Set<String> visibleEmployeeIds(Session session) {
    final me = _seeded(session.employee.id);
    final seeded = switch (session.scope) {
      DataScope.self => {me},
      DataScope.subtree => _data.subtreeOf(me).map((e) => e.id).toSet(),
    };

    // Both spellings of the same person.
    //
    // The seeded records are keyed by `emp-1`; a record the app created this
    // session was built from `session.employee.id`, which live is a Supabase
    // uuid. Answering for only one of them is how a rep added a client, was
    // told it saved, and never saw it again — their own record failed the
    // visibility check on their own list.
    final both = {...seeded};
    for (final id in seeded) {
      final live = identity.uuidForFixtureId(id);
      if (live != null) both.add(live);
    }
    return both;
  }

  /// Applies scope plus an optional explicit employee filter. Passing an
  /// [employeeId] outside the caller's scope yields nothing rather than
  /// leaking — defence in depth against a UI bug.
  bool canSee(Session session, String employeeId, {String? filterId}) {
    employeeId = _seeded(employeeId);
    if (filterId != null && filterId != employeeId) return false;
    return visibleEmployeeIds(session).contains(employeeId);
  }

  /// Refuses a record belonging to someone the caller cannot see.
  ///
  /// **Throws rather than returning empty.** A filtered-away record reads as
  /// "there is nothing there", which is a different and much worse answer than
  /// "not yours" — it is how a missing row gets blamed on the rep who filed
  /// it. Every `byId` goes through this: a list that scopes correctly is no
  /// protection at all when the record next door is one route parameter away.
  void requireVisible(Session session, String employeeId, String what) {
    employeeId = _seeded(employeeId);
    if (!visibleEmployeeIds(session).contains(employeeId)) {
      throw StateError('$what belongs to $employeeId, outside this scope');
    }
  }

  /// Refuses a record the caller does not own.
  ///
  /// Stricter than [requireVisible] and used for **writes**. A manager can
  /// *see* a rep's expense — that is the whole point of an approval queue —
  /// and must not be able to rewrite it: approving and rejecting are the only
  /// two things they may do to it, and both are recorded in an append-only
  /// history. Correcting a record is the owner's job.
  void requireOwner(Session session, String employeeId, String what) {
    employeeId = _seeded(employeeId);
    if (employeeId != _seeded(session.employee.id)) {
      throw StateError('$what belongs to $employeeId, not the caller');
    }
  }
}

// ================================================================== auth ==

/// Whatever id the *seed* knows this person by.
///
/// These repositories are the modules that have no table yet. Live, a session
/// carries the employee's Supabase uuid and the seed is keyed by `emp-1`, so
/// without this every one of them looks up nobody — and `daySummary`'s
/// unguarded `firstWhere` turned that into "Something went wrong" on Home for
/// a manager who had signed in perfectly well.
///
/// In fixture mode the map is empty and the id passes straight through. This
/// is the compatibility layer, and it is deliberately only here: it shrinks as
/// each module gets a real table and disappears with the last one.
String _seeded(String employeeId) => identity.seeded(employeeId);

class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  final _data = MockDataset.instance;
  Session? _current;

  /// Any employee code from the seed signs in, with any non-empty password.
  /// This lets both roles be explored without a backend: MR1001 for the field
  /// experience, ASM201 for the manager one — which is the whole matrix now
  /// that the office layers live on the web rather than on the phone.
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

  /// The demo answers to an employee's own seeded address, and to their code,
  /// because typing `sai.kiran@mrsales.in` on a phone to look at a demo is a
  /// tax nobody should pay.
  @override
  Future<void> requestSignInCode(String email) async {
    await _latency(500);
    if (_findByEmailOrCode(email) == null) {
      throw const AuthException('Nobody on the roster has that address.');
    }
  }

  @override
  Future<Session> signInWithCode({
    required String email,
    required String code,
  }) async {
    await _latency(600);
    final match = _findByEmailOrCode(email);
    if (match == null) {
      throw const AuthException('Nobody on the roster has that address.');
    }
    if (code.trim() != '123456') {
      throw const AuthException('That code is not right. It is 123456 here.');
    }
    return _current = Session(employee: match, loginAt: DateTime.now());
  }

  Employee? _findByEmailOrCode(String s) {
    final q = s.toLowerCase().trim();
    return _data.employees
        .where((e) => e.email.toLowerCase() == q || e.employeeCode.toLowerCase() == q)
        .firstOrNull;
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
  Future<Client> byId(Session session, String id) async {
    await _latency(140);
    final client = _store.clients.firstWhere((c) => c.id == id);
    final owner = client.ownerEmployeeId;
    if (owner != null) _store.requireVisible(session, owner, 'This client');
    return client;
  }

  @override
  Future<Client> create(Client client) async {
    await _latency(600);
    _store.clients.add(client);
    return client;
  }

  @override
  Future<Client> update(Session session, Client client) async {
    await _latency(400);
    final owner = client.ownerEmployeeId;
    if (owner != null) _store.requireVisible(session, owner, 'This client');
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
    employeeId = employeeId == null ? null : _seeded(employeeId);
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
  Future<Activity> byId(Session session, String id) async {
    await _latency(140);
    final activity = _store.activities.firstWhere((a) => a.id == id);
    _store.requireVisible(session, activity.employeeId, 'This activity');
    return activity;
  }

  @override
  Future<DaySummary> daySummary(String employeeId, DateTime date) async {
    employeeId = _seeded(employeeId);
    await _latency(200);
    // Not `firstWhere` without a fallback. Live, somebody can exist in
    // Supabase and not in this build's seed — a perfectly ordinary state — and
    // an unguarded lookup turned that into "Something went wrong" on Home for
    // a manager who had signed in correctly. They simply have no seeded day.
    final employee = _store.seed.employees
        .where((e) => e.id == employeeId)
        .firstOrNull;

    final items = _store.activities
        .where((a) => _seeded(a.employeeId) == employeeId && _sameDay(a.scheduledStart, date))
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    // The intimation for this date, if the rep has filed one. It is what makes
    // the day "started" and what names a non-field day as a meeting or a
    // training — both facts the rep already typed into My Day Plan and which,
    // until now, reached no screen.
    final plan = _store.dayPlans
        .where((p) => _seeded(p.employeeId) == employeeId && _sameDay(p.date, date))
        .firstOrNull;

    return DaySummary(
      date: date,
      activities: items,
      headquarters: employee?.headquarters ?? '',
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
  Future<Activity> update(Session session, Activity activity) async {
    await _latency(400);
    _store.requireOwner(session, activity.employeeId, 'This activity');
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
    employeeId = _seeded(employeeId);
    await _latency();
    return _store.dayPlans
        .where((p) =>
            _seeded(p.employeeId) == employeeId &&
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
    employeeId = employeeId == null ? null : _seeded(employeeId);
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
    employeeId = employeeId == null ? null : _seeded(employeeId);
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
  Future<TravelPlan> byId(Session session, String id) async =>
      _store.travelPlans.firstWhere((p) => p.id == id);

  @override
  Future<TravelPlan> create(TravelPlan plan) async {
    await _latency(500);
    _store.travelPlans.add(plan);
    return plan;
  }

  @override
  Future<TravelPlan> update(Session session, TravelPlan plan) async {
    _store.requireOwner(session, plan.employeeId, 'This tour plan');
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
    employeeId = employeeId == null ? null : _seeded(employeeId);
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
      // The company's calendar, resolved here rather than in the screen. A
      // holiday is not a fact about one rep's month, and a screen that fetched
      // it separately would be a second place for the answer to live.
      holidays: {
        for (final h in _store.seed.holidays)
          if (h.date.year == month.year && h.date.month == month.month)
            h.date.day: h.name,
      },
      weekOff: MockStore.weekOff,
      // Frozen the moment the month went in, and computed until then.
      //
      // The denominator an approver signed against must not move afterwards.
      // It was recomputed on every read from the week-off rule in force *now*,
      // so moving the company's week off — or adding a holiday to a past date
      // — silently restated every month already approved: a September that
      // was 26 of 26 and complete comes back 25, with the Sundays the rep did
      // plan suddenly counting and the Tuesdays they planned no longer doing.
      // Nobody edited anything; the question changed underneath the answer.
      judgedUnder: _store.tourRules['$id-${month.year}-${month.month}'],
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

    // Keep the rule this month was judged against, before anything can change
    // it. The rule rather than the figures, so everything derived from it
    // stays consistent — see the note on [TourRule].
    _store.tourRules['${session.employee.id}-${month.year}-${month.month}'] =
        TourRule(
      weekOff: MockStore.weekOff,
      holidayDays: current.holidays.keys.toSet(),
    );

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
    employeeId = employeeId == null ? null : _seeded(employeeId);
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
  Future<Expense> byId(Session session, String id) async {
    final expense = _store.expenses.firstWhere((e) => e.id == id);
    _store.requireVisible(session, expense.employeeId, 'This claim');
    return expense;
  }

  @override
  Future<Expense> create(Expense expense) async {
    await _latency(500);
    _store.expenses.add(expense);
    return expense;
  }

  @override
  Future<Expense> update(Session session, Expense expense) async {
    await _latency(400);
    _store.requireOwner(session, expense.employeeId, 'This claim');
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
    employeeId = employeeId == null ? null : _seeded(employeeId);
    await _latency(260);

    final id = employeeId ?? session.employee.id;
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;

    final plans = {
      for (final p in _store.dayPlans)
        if (p.employeeId == id && inMonth(p.date)) p.date.day: p,
    };

    final filed = _store.expenses.where(
      (e) => e.employeeId == id && inMonth(e.date),
    );

    // Everything else that knows what a day was. The claim used to see only
    // the first of these, so a month was the days a rep had filed a plan for
    // and the other twenty were simply not on the screen.
    final holidays = {
      for (final h in _store.seed.holidays)
        if (inMonth(h.date)) h.date.day: h.name,
    };
    final leaves = _store.leaves.where(
      (l) => l.employeeId == id && l.status == ApprovalStatus.approved,
    );
    final tour = {
      for (final p in _store.travelPlans)
        if (p.employeeId == id && inMonth(p.date)) p.date.day: p,
    };

    // A month with nothing in it at all is not a month of missed days.
    //
    // The synthesised days exist to give a *worked* month its context — the
    // Sundays, the holidays, the one Tuesday nobody intimated. A month before
    // the rep joined has none of that to contextualise, and filling it with
    // thirty "No day plan" rows would paint a red calendar and export a sheet
    // of nothing.
    if (plans.isEmpty && filed.isEmpty) return const [];

    final today = _dateOnly(_store.seed.today);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;

    final days = <ClaimDay>[];
    for (var d = 1; d <= lastDay; d++) {
      final date = DateTime(month.year, month.month, d);
      // A day that has not happened cannot have been worked. Listing the rest
      // of the month would put twenty "No day plan" rows under today's.
      if (date.isAfter(today)) break;

      final plan = plans[d];

      // Today is not yet a day anyone missed. It has no day plan because the
      // rep has not filed one *yet* — the day is still in front of him — and
      // a row reading "No intimation filed" against today would be the app
      // telling him at nine in the morning that he had already lost the day.
      if (plan == null && _sameDay(date, today)) continue;

      final calls = _store.activities
          .where((a) =>
              a.employeeId == id &&
              a.status == ActivityStatus.completed &&
              _sameDay(a.scheduledStart, date))
          .length;

      // Resolved in priority order, and the declaration wins.
      //
      // A rep who filed a day plan and worked a Sunday worked it: the day plan
      // is what he said about *this* day, and everything below is what was
      // expected of it. The order below is the same one attendance uses, so
      // the two screens cannot disagree about what a date was.
      final DayKind kind;
      String? note;
      if (plan != null) {
        kind = switch (plan.workType) {
          WorkType.leave => DayKind.leave,
          WorkType.holiday => DayKind.holiday,
          _ => DayKind.worked,
        };
      } else if (holidays.containsKey(d)) {
        kind = DayKind.holiday;
        note = holidays[d];
      } else if (date.weekday == DateTime.sunday) {
        kind = DayKind.weekOff;
      } else {
        final leave = leaves
            .where((l) =>
                !date.isBefore(_dateOnly(l.fromDate)) &&
                !date.isAfter(_dateOnly(l.toDate)))
            .firstOrNull;
        if (leave != null) {
          kind = DayKind.leave;
          note = leave.type.label;
        } else if (tour[d] != null &&
            !tourDayNeedsDetail(tour[d]!.workType)) {
          // Planned as leave or a holiday on the tour plan and never
          // intimated. It is still not a day anyone owes him for.
          kind = DayKind.leave;
          note = 'Planned as ${tour[d]!.workType.label.toLowerCase()}';
        } else {
          kind = DayKind.notDeclared;
        }
      }

      days.add(
        ClaimDay(
          date: date,
          dayPlanId: plan?.id,
          workType: plan?.workType ?? WorkType.fieldWork,
          kind: kind,
          note: note,
          // The cluster is the more useful of the two — an area is a whole
          // city, a cluster is where he actually was.
          place: plan?.clusterName ?? plan?.areaName ?? '—',
          allowance: kind.earnsAllowance ? MockStore.dailyAllowance : 0,
          // Matched on the day plan, not on the date. A claim belongs to the
          // intimation it was filed against, and matching by date would
          // silently attach it to a second plan for the same day.
          expenses: plan == null
              ? const []
              : filed.where((e) => e.dayPlanId == plan.id).toList(),
          calls: calls,
        ),
      );
    }

    return days;
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

    // Asked of the store, not of the screen. The button is disabled on a
    // snapshot taken when the screen loaded, and a month can have gained an
    // unanswered day since — or, on the last day of the month, simply have
    // still been running when the screen opened.
    final gate = claimGate(
      days: await claimMonth(session, month),
      month: month,
      now: DateTime.now(),
    );
    if (gate != ClaimGate.ready) return 0;

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
    employeeId = _seeded(employeeId);
    await _latency();

    final employee = _store.seed.employees
        .where((e) => e.id == employeeId)
        .firstOrNull;
    final derivesFromVisits = employee?.role == UserRole.mr;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final holidays = _store.seed.holidays;
    final approvedLeave = _store.leaves.where(
      (l) => _seeded(l.employeeId) == employeeId && l.status == ApprovalStatus.approved,
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
            _seeded(a.employeeId) == employeeId &&
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
    employeeId = employeeId == null ? null : _seeded(employeeId);
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.leaves
        .where((l) =>
            visible.contains(l.employeeId) &&
            (employeeId == null || _seeded(l.employeeId) == employeeId))
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
  Future<List<Payslip>> payslips(Session session, String employeeId) async {
    employeeId = _seeded(employeeId);
    await _latency();
    // Owner-only, not merely scoped: a manager can see a rep's claim and must
    // not see their pay. The parameter used to be accepted and thrown away,
    // so every employee was served one shared list at one salary — the most
    // sensitive figure in the app, and the same for everybody.
    _store.requireOwner(session, employeeId, 'This payslip');
    return _store.seed.payslips.where((p) => _seeded(p.employeeId) == employeeId).toList();
  }

  @override
  Future<List<AppDocument>> documents(String employeeId) async {
    employeeId = _seeded(employeeId);
    await _latency();
    return _store.seed.documents;
  }
}

// ============================================================== business ==

class MockBusinessRepository implements BusinessRepository {
  final _store = MockStore.instance;

  @override
  Future<List<SalesRecord>> sales(Session session, {String? employeeId, int? year}) async {
    employeeId = employeeId == null ? null : _seeded(employeeId);
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.seed.salesRecords
        .where((s) =>
            visible.contains(s.employeeId) &&
            (employeeId == null || _seeded(s.employeeId) == employeeId) &&
            (year == null || s.month.year == year))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  @override
  Future<List<Target>> targets(Session session, {String? employeeId, DateTime? month}) async {
    employeeId = employeeId == null ? null : _seeded(employeeId);
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.targets
        .where((t) =>
            visible.contains(t.employeeId) &&
            (employeeId == null || _seeded(t.employeeId) == employeeId) &&
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
    employeeId = employeeId == null ? null : _seeded(employeeId);
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.orders
        .where((o) =>
            visible.contains(o.employeeId) &&
            (employeeId == null || _seeded(o.employeeId) == employeeId) &&
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

    // The same two rules `_project` applies to the *list*, applied where the
    // decision is actually written. The screen builds its item from a list
    // that scopes correctly and removes the caller's own records — and none of
    // that protected anything, because `_decide` took whatever item it was
    // handed. A rep with no approval queue at all could approve another
    // employee's leave, and a manager could approve their own expense the
    // moment anything put the item in front of them.
    _store.requireVisible(session, item.employeeId, 'This record');
    if (item.employeeId == session.employee.id) {
      throw StateError('Nobody approves their own record');
    }

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
  Future<List<FieldTask>> list(
    Session session, {
    String? employeeId,
    String? assignedById,
    TaskStatus? status,
  }) async {
    employeeId = employeeId == null ? null : _seeded(employeeId);
    await _latency();
    final visible = _store.visibleEmployeeIds(session);
    return _store.tasks
        .where((t) =>
            visible.contains(t.assignedToId) &&
            (employeeId == null || _seeded(t.assignedToId) == employeeId) &&
            (assignedById == null || t.assignedById == assignedById) &&
            (status == null || t.effectiveStatus() == status))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  Future<FieldTask> create(Session session, FieldTask task) async {
    await _latency(500);
    // An ASM assigning to their own RSM is not a hierarchy, it is a bug — and
    // the picker on the form is a picker, not a permission.
    _store.requireVisible(session, task.assignedToId, 'That person');
    _store.tasks.add(task);
    return task;
  }

  @override
  Future<FieldTask> updateStatus(
    Session session,
    String id,
    TaskStatus status,
  ) async {
    await _latency(300);
    final i = _store.tasks.indexWhere((t) => t.id == id);
    // Only the person it was given to. It took no session at all, so any id
    // was enough to tick off anyone's work — and a manager marking a rep's
    // task done is the manager reporting the rep's progress for them.
    _store.requireOwner(session, _store.tasks[i].assignedToId, 'This task');
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

// ================================================================ export ==

/// Builds the four sheets from records this rep already has.
///
/// Derived, never stored — the same rule reports follow. A sheet is a view of
/// the transactional records at the moment it is asked for, so it cannot go
/// stale and there is nothing to keep in step.
///
/// Two of the client's columns are deliberately absent. **Joint work** was
/// removed from this app outright — the field, both pickers and both display
/// rows — because "who rode along" turned out to be nobody's question, and
/// printing a column of "No" would be inventing data to fill a shape. The
/// client list's **Unlisted** column is the negation of its **Listed** column
/// beside it; one of them is the answer.
class MockExportRepository implements ExportRepository {
  final _store = MockStore.instance;
  final _expenses = MockExpenseRepository();
  final _travel = MockTravelRepository();
  final _clients = MockClientRepository();

  @override
  Future<ExportSheet> build(
    Session session,
    ExportKind kind,
    DateTime month, {
    String? employeeId,
  }) async {
    employeeId = employeeId == null ? null : _seeded(employeeId);
    final target = _target(session, employeeId);

    final rows = switch (kind) {
      ExportKind.expenses => await _expensesRows(session, target, month),
      ExportKind.tourPlan => await _tourRows(session, target, month),
      ExportKind.dcr => await _dcrRows(session, target, month),
      ExportKind.clients => await _clientRows(session, target),
    };

    final stamp = kind.isMonthly
        ? '${month.year}-${_two(month.month)}'
        : _isoDay(_store.seed.today);

    return ExportSheet(
      kind: kind,
      // No extension: the format is chosen when the file is written, and a
      // name carrying `.csv` was still on the workbook the day it became one.
      fileName:
          '${kind.label.replaceAll(' ', '-')}_${target.employeeCode}'
          '_$stamp',
      rows: [..._heading(target, kind), ...rows],
    );
  }

  /// Whose sheet this is — and whether the caller may ask for it.
  ///
  /// Resolved against `visibleEmployeeIds`, the same scope every other read
  /// here goes through, so a manager gets their own team and nobody else's.
  /// An id outside it is a **refusal**, not an empty sheet: an empty file
  /// reads as "that rep did nothing this month", which is a different and far
  /// worse answer than "not yours to ask".
  Employee _target(Session session, String? employeeId) {
    employeeId = employeeId == null ? null : _seeded(employeeId);
    if (employeeId == null || employeeId == _seeded(session.employee.id)) {
      return session.employee;
    }
    if (!_store.visibleEmployeeIds(session).contains(employeeId)) {
      throw StateError('$employeeId is outside this session\'s scope');
    }
    // Same reasoning as `daySummary`: a live employee the seed does not know
    // has nothing to export rather than an exception to throw.
    return _store.seed.employees.where((e) => e.id == employeeId).firstOrNull
        ?? session.employee;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _isoDay(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// The block at the top of every one of the client's sheets.
  ///
  /// The *target's* name and code, not the signed-in user's. A manager
  /// exporting a rep's month is sending the office that rep's sheet, and a
  /// header carrying the manager's own name would misfile it.
  List<List<String>> _heading(Employee e, ExportKind kind) {
    return [
      [kind.title],
      ['Name', e.name],
      ['Emp Code', e.employeeCode],
      ['Designation', e.designation],
      ['Area', e.areaName ?? e.headquarters],
      [],
    ];
  }

  /// The word that stands in for a station on a day nobody worked.
  ///
  /// The client's sheets write SUNDAY, HOLIDAY or LEAVE straight into the
  /// station column with zeroes beside it, and this app already resolves
  /// exactly those three — [DayKind] — from the day plan, the holiday
  /// calendar, the week, HR's approved leave and the tour plan, in that order.
  static String? _offLabel(DayKind kind) => switch (kind) {
    DayKind.weekOff => 'SUNDAY',
    DayKind.holiday => 'HOLIDAY',
    DayKind.leave => 'LEAVE',
    DayKind.notDeclared => 'NOT DECLARED',
    DayKind.worked => null,
  };

  /// Who signed it off, from the append-only approval history.
  static String _approver(List<ApprovalEvent> history) {
    for (final e in history.reversed) {
      if (e.status == ApprovalStatus.approved ||
          e.status == ApprovalStatus.rejected) {
        return e.actorName;
      }
    }
    return '—';
  }

  Future<List<List<String>>> _expensesRows(
    Session session,
    Employee target,
    DateTime month,
  ) async {
    final days = await _expenses.claimMonth(
      session,
      month,
      employeeId: target.id,
    );
    final rows = <List<String>>[
      [
        'Date',
        'Station',
        'Out of territory',
        'Place',
        'Amount',
        'Status',
        'Approved By',
      ],
    ];

    for (final d in days) {
      final off = _offLabel(d.kind);
      if (off != null) {
        rows.add([exportDate(d.date), off, '0', '0', '0', '', '']);
        continue;
      }

      final out = d.expenses
          .where((e) => e.scope == ClaimScope.outOfTerritory)
          .firstOrNull;
      rows.add([
        exportDate(d.date),
        d.place,
        out == null ? 'No' : 'Yes',
        out?.place ?? 'NA',
        d.claimed.toStringAsFixed(0),
        d.status?.label ?? 'Not claimed',
        _approver([for (final e in d.expenses) ...e.approvalHistory]),
      ]);
    }
    return rows;
  }

  Future<List<List<String>>> _tourRows(
    Session session,
    Employee target,
    DateTime month,
  ) async {
    final tour = await _travel.month(session, month, employeeId: target.id);
    final total = DateTime(month.year, month.month + 1, 0).day;

    final rows = <List<String>>[
      [
        'Date',
        'Station',
        'Planned Clients',
        'Client List',
        'Status',
        'Approved By',
      ],
    ];

    for (var d = 1; d <= total; d++) {
      final date = DateTime(month.year, month.month, d);
      final plan = tour.planFor(d);

      // A plan the rep filed outranks the calendar, exactly as it does on the
      // claim: a declared Sunday was worked.
      if (plan == null || !tourDayNeedsDetail(plan.workType)) {
        final off = plan != null
            ? (plan.workType == WorkType.leave ? 'LEAVE' : 'HOLIDAY')
            : tour.holidayName(d) != null
            ? 'HOLIDAY'
            : date.weekday == DateTime.sunday
            ? 'SUNDAY'
            : 'NOT PLANNED';
        rows.add([exportDate(date), off, '0', '0', '', '']);
        continue;
      }

      rows.add([
        exportDate(date),
        plan.areaName ?? plan.territoryName ?? '—',
        // The count is what the rep planned; the names are the ones he wrote
        // down. They differ — a rep plans a round of ten and names the four
        // that matter — so the sheet prints both rather than deriving one
        // from the other and quietly disagreeing with the app.
        '${plan.plannedVisits}',
        plan.clientNames.isEmpty ? 'NA' : plan.clientNames.join('; '),
        plan.status.label,
        _approver(plan.approvalHistory),
      ]);
    }
    return rows;
  }

  Future<List<List<String>>> _dcrRows(
    Session session,
    Employee target,
    DateTime month,
  ) async {
    // The claim month is the one place that already answers "what kind of day
    // was this" for every date, so the DCR is read from it rather than from a
    // second walk over the day plans that could disagree with the first.
    final days = await _expenses.claimMonth(
      session,
      month,
      employeeId: target.id,
    );
    final clients = await _clients.list(session);
    final listing = {for (final c in clients) c.id: c.listing};

    final rows = <List<String>>[
      [
        'Date',
        'Station',
        'Clients Visited',
        'Listed',
        'Unlisted',
        'Unplanned',
        'Day Status',
      ],
    ];

    for (final d in days) {
      final off = _offLabel(d.kind);
      if (off != null) {
        rows.add([exportDate(d.date), off, '0', '0', '0', '0', off]);
        continue;
      }

      final calls = _store.activities.where(
        (a) =>
            a.employeeId == target.id &&
            a.status == ActivityStatus.completed &&
            _sameDay(a.scheduledStart, d.date),
      );

      rows.add([
        exportDate(d.date),
        d.place,
        '${calls.length}',
        '${calls.where((a) => listing[a.clientId] == ClientListing.listed).length}',
        '${calls.where((a) => listing[a.clientId] != ClientListing.listed).length}',
        '${calls.where((a) => a.isUnplanned).length}',
        d.workType.label,
      ]);
    }
    return rows;
  }

  Future<List<List<String>>> _clientRows(
    Session session,
    Employee target,
  ) async {
    // A manager's own client list is their whole territory; a rep's is the
    // clients on their name. Asking for a rep's sheet gives that rep's list,
    // which is the sheet the office expects to receive.
    final all = await _clients.list(session);
    final clients = target.id == session.employee.id
        ? all
        : all.where((c) => c.ownerEmployeeId == target.id).toList();
    final rows = <List<String>>[
      [
        'Sr.No.',
        'Client Name',
        'Client Type',
        'Designation',
        'Speciality',
        'Area',
        'Listed',
        'Status',
        'Special Date',
        'Type of Special Day',
        'Total Visits',
        'Last Visit',
      ],
    ];

    for (var i = 0; i < clients.length; i++) {
      final c = clients[i];
      rows.add([
        '${i + 1}',
        c.name,
        c.type.label,
        c.designation ?? 'NA',
        c.specialty ?? 'NA',
        c.areaName,
        c.listing.label,
        // NA, not 'Active'. The client's own workbook writes the status
        // column that way for an unlisted client, and it is the same rule:
        // there is nothing on the list for the flag to describe.
        c.statusLabel ?? 'NA',
        c.specialDate == null ? 'NA' : exportDate(c.specialDate!),
        c.specialOccasion?.label ?? 'NA',
        '${c.totalVisits}',
        c.lastVisitAt == null ? 'NA' : exportDate(c.lastVisitAt!),
      ]);
    }
    return rows;
  }
}
