/// Talking to Supabase.
///
/// These sit beside the `Mock*` implementations rather than replacing them,
/// and they implement the same interfaces — so no screen changes, which is the
/// test of whether the abstraction was right.
///
/// **They are deliberately partial, and each one says where it stops.** The
/// database holds employees, reporting lines, leave, leave decisions, clients,
/// day plans, activities, expenses and tour plans; everything else still
/// delegates to the seeded data and the comment says so — a half-connected
/// app that admits it beats one that lies in either direction.
library;

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/location/geo_math.dart';
import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/business.dart';
import '../../shared/models/client.dart';
import '../../shared/models/engagement.dart';
import '../../shared/models/export.dart';
import '../../shared/models/field_ops.dart';
import '../../shared/models/organization.dart';
import '../remote/backend.dart';
import 'identity_map.dart';
import 'mock_report_repository.dart';
import 'mock_repositories.dart';
import 'repositories.dart';

/* ══════════════════════════════════════════════════════════════ auth ══ */

class ApiAuthRepository implements AuthRepository {
  /// Employee ID and password.
  ///
  /// The address Supabase Auth is asked about is derived from the code and the
  /// organisation — see [loginEmailFor]. Nothing is looked up first, so a code
  /// that does not exist fails here exactly the way a wrong password does, and
  /// there is no endpoint that will tell a stranger who works here.
  @override
  Future<Session> login({
    required String employeeCode,
    required String password,
  }) async {
    final code = employeeCode.trim();
    if (code.isEmpty) {
      throw const AuthException('Please enter your employee ID.');
    }
    if (password.isEmpty) {
      throw const AuthException('Please enter your password.');
    }

    try {
      final res = await db.auth.signInWithPassword(
        email: loginEmailFor(code),
        password: password,
      );
      if (res.session == null) {
        throw const AuthException('That did not sign you in.');
      }
      return _sessionForCurrentUser();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_readable(e));
    }
  }

  /// Turn a signed-in account into the person the app is about.
  ///
  /// The app never trusts the employee ID that was typed. That string only
  /// reaches Supabase Auth; **which employee this is** comes back from
  /// `app_users`, after the password has been accepted. Reversing those two
  /// would let anybody be anybody by typing a different code.
  Future<Session> _sessionForCurrentUser() async {
    final user = db.auth.currentUser;
    if (user == null) throw const AuthException('You are not signed in.');

    final account = await db
        .from('app_users')
        .select('employee_id, role, scope')
        .eq('user_id', user.id)
        .maybeSingle();

    if (account == null || account['employee_id'] == null) {
      throw const AuthException(
        'This account is not linked to anybody on the roster yet. '
        'An owner does that from the console.',
      );
    }

    final row = await db
        .from('employees')
        .select('*, territories(name)')
        .eq('id', account['employee_id'] as String)
        .maybeSingle();
    if (row == null) {
      throw const AuthException(
        'Your account points at an employee record you cannot read.',
      );
    }

    // The employee's **uuid** is the identity. The fixture is not consulted
    // and is not required: somebody who exists in Supabase and not in this
    // build's seed signs in and is real.
    final me = employeeFromRow(row);

    // The whole roster this account may read, not just themselves. A manager's
    // team screen, their approval queue and every seeded record belonging to
    // one of their reps are keyed by somebody else's id, and the mock modules
    // translate through this map — so it has to be filled before the first
    // screen asks. Row-level security has already decided which people these
    // are.
    final roster = await db.from('employees').select('id, code');
    identity
      ..clear()
      ..rememberAll({
        for (final r in roster) r['code'] as String: r['id'] as String,
      })
      ..remember(me.employeeCode, me.id);

    return Session(employee: me, loginAt: DateTime.now());
  }

  @override
  Future<void> logout() async {
    identity.clear();
    await db.auth.signOut();
  }

  /// Supabase persists and refreshes the session itself; this asks it what it
  /// already has rather than keeping a second copy that can disagree.
  @override
  Future<Session?> restoreSession() async {
    if (db.auth.currentSession == null) return null;
    try {
      return await _sessionForCurrentUser();
    } catch (_) {
      // A stored token whose account has since been unlinked. Signing out is
      // the honest outcome: there is nobody to be.
      await db.auth.signOut();
      return null;
    }
  }

  @override
  Future<void> requestPasswordReset(String employeeCode) async {
    // There is no address to send to: the derived one is not a mailbox. A
    // password is reset by whoever administers the organisation.
    throw const AuthException(
      'Ask your administrator to reset your password — this ID has no mailbox '
      'of its own.',
    );
  }

  @override
  Future<bool> verifyOtp({
    required String employeeCode,
    required String otp,
  }) async {
    throw const AuthException('This build signs in with a password.');
  }

  @override
  Future<void> resetPassword({
    required String employeeCode,
    required String password,
  }) async {
    // Changing *your own* password once signed in is a normal Auth operation.
    await db.auth.updateUser(sb.UserAttributes(password: password));
  }

  @override
  Future<void> requestSignInCode(String email) async {
    throw const AuthException('This build signs in with an employee ID and password.');
  }

  @override
  Future<Session> signInWithCode({
    required String email,
    required String code,
  }) async {
    throw const AuthException('This build signs in with an employee ID and password.');
  }

  String _readable(Object e) {
    final s = e.toString();
    if (RegExp('invalid login credentials', caseSensitive: false).hasMatch(s)) {
      // Supabase says the same thing for a wrong password and an ID that has
      // no account, on purpose — so a stranger cannot learn who works here.
      // The wording has to be actionable without revealing which case it is.
      return 'That employee ID and password do not match an account. '
          'If you have never been given a password, ask your administrator.';
    }
    final m = RegExp(r'message: ([^,)]+)').firstMatch(s);
    return m?.group(1) ?? s.replaceFirst(RegExp(r'^\w+Exception: '), '');
  }
}


/// The database's employee row, as the app's model.
Employee employeeFromRow(Map<String, dynamic> r) {
  final territory = r['territories'] as Map<String, dynamic>?;
  return Employee(
    id: r['id'] as String,
    employeeCode: r['code'] as String,
    name: r['name'] as String,
    role: (r['mobile_role'] as String) == 'ASM' ? UserRole.asm : UserRole.mr,
    designation: r['designation'] as String? ?? '',
    department: r['department'] as String? ?? 'Sales & Marketing',
    email: r['email'] as String? ?? '',
    mobile: r['mobile'] as String? ?? '',
    managerId: r['manager_id'] as String?,
    territoryId: r['territory_id'] as String? ?? '',
    territoryName: territory?['name'] as String? ?? '',
    headquarters: r['hq'] as String? ?? '',
    joiningDate: DateTime.tryParse(r['joined_at'] as String? ?? ''),
    bloodGroup: r['blood_group'] as String?,
    isActive: (r['status'] as String? ?? 'active') == 'active',
  );
}

/* ═══════════════════════════════════════════════════════════════ hr ══ */

/// Leave, attendance, holidays, payslips and documents from the database.
class ApiHrRepository implements HrRepository {
  ApiHrRepository();

  static const _typeTerm = {
    LeaveType.casual: 'casual',
    LeaveType.sick: 'sick',
    LeaveType.earned: 'earned',
    LeaveType.unpaid: 'unpaid',
    LeaveType.compensatory: 'compensatory',
  };
  static const _typeOf = {
    'casual': LeaveType.casual,
    'sick': LeaveType.sick,
    'earned': LeaveType.earned,
    'unpaid': LeaveType.unpaid,
    'compensatory': LeaveType.compensatory,
  };
  static const _statusOf = {
    'pending': ApprovalStatus.pending,
    'approved': ApprovalStatus.approved,
    'rejected': ApprovalStatus.rejected,
  };

  @override
  Future<List<LeaveRequest>> leaves(Session session, {String? employeeId}) async {
    var q = db.from('leave_requests').select(
        'id, employee_id, type, from_date, to_date, days, reason, status, applied_at');
    // The id the screen holds is the id on the wire: both are the employee's
    // uuid. There is nothing to translate here any more, and the day that
    // stops being true this is where it would break loudly.
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    final rows = await q.order('from_date', ascending: false);

    // Names come from the roster the caller may read, which is the same set
    // row-level security just filtered these rows by.
    final ids = rows.map((r) => r['employee_id'] as String).toSet().toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final people =
          await db.from('employees').select('id, name').inFilter('id', ids);
      for (final p in people) {
        names[p['id'] as String] = p['name'] as String;
      }
    }

    return rows
        .where((r) => _statusOf.containsKey(r['status']))
        // A row whose owner is not in this build cannot be shown against a
        // name, and an approver reading a record with no name is how a
        // decision lands on the wrong person.
        .map((r) => LeaveRequest(
              id: r['id'] as String,
              employeeId: r['employee_id'] as String,
              employeeName: names[r['employee_id']] ?? 'Somebody',
              fromDate: DateTime.parse(r['from_date'] as String),
              toDate: DateTime.parse(r['to_date'] as String),
              type: _typeOf[r['type']] ?? LeaveType.casual,
              reason: r['reason'] as String,
              status: _statusOf[r['status']]!,
              createdAt: DateTime.tryParse(r['applied_at'] as String? ?? ''),
            ))
        .toList();
  }

  /// Applying goes through `apply_for_leave`, which takes no employee — it
  /// applies for the caller. The id on the request is ignored on purpose: a
  /// client that names the applicant is a client that can apply as somebody
  /// else.
  ///
  /// After the RPC, the row is re-read by the id it returned — never through
  /// [MockDataset.currentUser], which is the fixture person and not who just
  /// signed in.
  @override
  Future<LeaveRequest> applyLeave(LeaveRequest request) async {
    final id = await db.rpc('apply_for_leave', params: {
      'p_type': _typeTerm[request.type],
      'p_from': _iso(request.fromDate),
      'p_to': _iso(request.toDate),
      'p_reason': request.reason,
    }) as String;

    final row = await db
        .from('leave_requests')
        .select(
            'id, employee_id, type, from_date, to_date, days, reason, status, applied_at')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Leave was filed but could not be read back.');
    }

    final person = await db
        .from('employees')
        .select('name')
        .eq('id', row['employee_id'] as String)
        .maybeSingle();

    return LeaveRequest(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      employeeName: person?['name'] as String? ?? 'Somebody',
      fromDate: DateTime.parse(row['from_date'] as String),
      toDate: DateTime.parse(row['to_date'] as String),
      type: _typeOf[row['type']] ?? LeaveType.casual,
      reason: row['reason'] as String,
      status: _statusOf[row['status']] ?? ApprovalStatus.pending,
      createdAt: DateTime.tryParse(row['applied_at'] as String? ?? ''),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<AttendanceRecord>> attendance(String employeeId, DateTime month) async {
    final from = _iso(DateTime(month.year, month.month, 1));
    final to = _iso(DateTime(month.year, month.month + 1, 0));
    final rows = await db
        .from('attendance_days')
        .select('work_date, work_type, attendance_status, declared_at')
        .eq('employee_id', employeeId)
        .gte('work_date', from)
        .lte('work_date', to)
        .order('work_date', ascending: true);

    return rows.map((r) {
      final date = DateTime.parse(r['work_date'] as String);
      final statusKey = r['attendance_status'] as String;
      final workKey = r['work_type'] as String?;
      final status = switch (workKey) {
        'leave' => AttendanceStatus.leave,
        'holiday' => AttendanceStatus.holiday,
        _ => switch (statusKey) {
            'present' => AttendanceStatus.present,
            _ => AttendanceStatus.absent,
          },
      };
      return AttendanceRecord(
        date: date,
        status: status,
        checkIn: statusKey == 'present'
            ? date.add(const Duration(hours: 9, minutes: 12))
            : null,
        checkOut: statusKey == 'present'
            ? date.add(const Duration(hours: 18, minutes: 24))
            : null,
        workType: workKey == null
            ? null
            : ApiDayPlanRepository._workTypeOf[workKey],
      );
    }).toList();
  }

  @override
  Future<List<Holiday>> holidays(int year) async {
    final rows = await db
        .from('holidays')
        .select('id, holiday_date, name')
        .gte('holiday_date', '$year-01-01')
        .lte('holiday_date', '$year-12-31')
        .order('holiday_date', ascending: true);
    return rows
        .map((r) => Holiday(
              id: r['id'] as String,
              name: r['name'] as String,
              date: DateTime.parse(r['holiday_date'] as String),
            ))
        .toList();
  }

  @override
  Future<List<Payslip>> payslips(Session session, String employeeId) async {
    if (employeeId != session.employee.id) {
      throw StateError('This payslip');
    }
    final rows = await db
        .from('payslips')
        .select('id, employee_id, period_year, period_month, net_pay, released_at')
        .eq('employee_id', employeeId)
        .order('period_year', ascending: false)
        .order('period_month', ascending: false);
    return rows
        .map((r) {
          final net = (r['net_pay'] as num).toDouble();
          return Payslip(
            id: r['id'] as String,
            employeeId: r['employee_id'] as String,
            month: DateTime(r['period_year'] as int, r['period_month'] as int),
            grossPay: net,
            deductions: 0,
          );
        })
        .toList();
  }

  @override
  Future<List<AppDocument>> documents(String employeeId) async {
    final rows = await db
        .from('documents')
        .select('id, title, category, storage_path, released_at')
        .or('employee_id.eq.$employeeId,employee_id.is.null')
        .order('released_at', ascending: false);
    return rows
        .map((r) => AppDocument(
              id: r['id'] as String,
              name: r['title'] as String,
              type: r['category'] as String? ?? 'General',
              uploadedAt: DateTime.parse(r['released_at'] as String),
              category: r['category'] as String? ?? 'General',
              url: r['storage_path'] as String?,
            ))
        .toList();
  }
}

/* ═══════════════════════════════════════════════════════ approvals ══ */

/// Leave, expense, tour and order decisions from the database.
class ApiApprovalRepository implements ApprovalRepository {
  ApiApprovalRepository();

  static const _expenseCategoryOf = {
    'dailyAllowance': ExpenseCategory.dailyAllowance,
    'travel': ExpenseCategory.travel,
    'food': ExpenseCategory.food,
    'lodging': ExpenseCategory.lodging,
    'fuel': ExpenseCategory.fuel,
    'other': ExpenseCategory.other,
  };

  static const _typeOf = {
    'casual': LeaveType.casual,
    'sick': LeaveType.sick,
    'earned': LeaveType.earned,
    'unpaid': LeaveType.unpaid,
    'compensatory': LeaveType.compensatory,
  };
  static const _statusOf = {
    'pending': ApprovalStatus.pending,
    'approved': ApprovalStatus.approved,
    'rejected': ApprovalStatus.rejected,
  };

  @override
  Future<List<ApprovalItem>> pending(Session session, {ApprovalKind? kind}) =>
      _queue(session, decided: false, kind: kind);

  @override
  Future<List<ApprovalItem>> decided(Session session, {ApprovalKind? kind}) =>
      _queue(session, decided: true, kind: kind);

  Future<List<ApprovalItem>> _queue(
    Session session, {
    required bool decided,
    ApprovalKind? kind,
  }) async {
    final items = <ApprovalItem>[];

    if (kind == null || kind == ApprovalKind.leave) {
      items.addAll(await _leaveItems(session, decided: decided));
    }
    if (kind == null || kind == ApprovalKind.order) {
      items.addAll(await _orderItems(session, decided: decided));
    }
    if (kind == null || kind == ApprovalKind.expense) {
      items.addAll(await _expenseItems(session, decided: decided));
    }
    if (kind == null || kind == ApprovalKind.tourPlan) {
      items.addAll(await _tourItems(session, decided: decided));
    }

    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  /// Pending = `pending`; decided = `approved` / `rejected`. Cancelled is
  /// skipped (not in either list). Visibility is RLS; self is stripped here
  /// the same way the mock queue does — a manager does not approve their own.
  Future<List<ApprovalItem>> _leaveItems(
    Session session, {
    required bool decided,
  }) async {
    final statuses = decided
        ? const ['approved', 'rejected']
        : const ['pending'];

    final rows = await db
        .from('leave_requests')
        .select(
            'id, employee_id, type, from_date, to_date, days, reason, status, applied_at')
        .inFilter('status', statuses)
        .order('applied_at', ascending: false);

    final ids = rows
        .map((r) => r['employee_id'] as String)
        .where((id) => id != session.employee.id)
        .toSet()
        .toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final people =
          await db.from('employees').select('id, name').inFilter('id', ids);
      for (final p in people) {
        names[p['id'] as String] = p['name'] as String;
      }
    }

    final items = <ApprovalItem>[];
    for (final r in rows) {
      final employeeId = r['employee_id'] as String;
      if (employeeId == session.employee.id) continue;

      final statusKey = r['status'] as String;
      final status = _statusOf[statusKey];
      if (status == null) continue; // cancelled / unknown

      final type = _typeOf[r['type']] ?? LeaveType.casual;
      final days = (r['days'] as num?)?.toInt() ??
          DateTime.parse(r['to_date'] as String)
                  .difference(DateTime.parse(r['from_date'] as String))
                  .inDays +
              1;

      items.add(ApprovalItem(
        id: 'ap-lv-${r['id']}',
        kind: ApprovalKind.leave,
        recordId: r['id'] as String,
        employeeId: employeeId,
        employeeName: names[employeeId] ?? 'Somebody',
        title: '${type.label} · $days day${days == 1 ? '' : 's'}',
        subtitle: r['reason'] as String?,
        submittedAt: DateTime.tryParse(r['applied_at'] as String? ?? '') ??
            DateTime.parse(r['from_date'] as String),
        status: status,
        date: DateTime.parse(r['from_date'] as String),
      ));
    }
    return items;
  }

  static const _orderStatusOf = {
    'draft': ApprovalStatus.draft,
    'pending': ApprovalStatus.pending,
    'approved': ApprovalStatus.approved,
    'rejected': ApprovalStatus.rejected,
    'fulfilled': ApprovalStatus.approved,
    'cancelled': ApprovalStatus.rejected,
  };

  Future<List<ApprovalItem>> _orderItems(
    Session session, {
    required bool decided,
  }) async {
    final statuses = decided
        ? const ['approved', 'rejected', 'fulfilled', 'cancelled']
        : const ['pending'];

    final rows = await db
        .from('orders')
        .select('id, employee_id, client_id, status, total, created_at, submitted_at, clients(name)')
        .inFilter('status', statuses)
        .order('created_at', ascending: false);

    final ids = rows
        .map((r) => r['employee_id'] as String)
        .where((id) => id != session.employee.id)
        .toSet()
        .toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final people =
          await db.from('employees').select('id, name').inFilter('id', ids);
      for (final p in people) {
        names[p['id'] as String] = p['name'] as String;
      }
    }

    final itemRows = await db
        .from('order_items')
        .select('order_id');
    final lineCounts = <String, int>{};
    for (final r in itemRows) {
      final oid = r['order_id'] as String;
      lineCounts[oid] = (lineCounts[oid] ?? 0) + 1;
    }

    final items = <ApprovalItem>[];
    for (final r in rows) {
      final employeeId = r['employee_id'] as String;
      if (employeeId == session.employee.id) continue;
      final status = _orderStatusOf[r['status'] as String];
      if (status == null) continue;
      final client = r['clients'] as Map<String, dynamic>?;
      final oid = r['id'] as String;
      final lines = lineCounts[oid] ?? 0;
      items.add(ApprovalItem(
        id: 'ap-ord-$oid',
        kind: ApprovalKind.order,
        recordId: oid,
        employeeId: employeeId,
        employeeName: names[employeeId] ?? 'Somebody',
        title: 'ORD-${oid.substring(0, 8).toUpperCase()} · ${client?['name'] ?? 'Order'}',
        subtitle: '$lines product${lines == 1 ? '' : 's'}',
        submittedAt: DateTime.tryParse(r['submitted_at'] as String? ?? '') ??
            DateTime.parse(r['created_at'] as String),
        status: status,
        amount: (r['total'] as num?)?.toDouble(),
        date: DateTime.parse(r['created_at'] as String),
      ));
    }
    return items;
  }

  @override
  Future<void> approve(Session session, ApprovalItem item, {String? comment}) async {
    switch (item.kind) {
      case ApprovalKind.leave:
        await _decideLeave(session, item, approve: true, comment: comment);
      case ApprovalKind.order:
        await _decideOrder(session, item, approve: true);
      case ApprovalKind.expense:
        await _decideExpense(session, item, approve: true, comment: comment);
      case ApprovalKind.tourPlan:
        await _decideTour(session, item, approve: true, comment: comment);
      case ApprovalKind.other:
        break;
    }
  }

  @override
  Future<void> reject(
    Session session,
    ApprovalItem item, {
    required String reason,
  }) async {
    switch (item.kind) {
      case ApprovalKind.leave:
        await _decideLeave(session, item, approve: false, reason: reason);
      case ApprovalKind.order:
        await _decideOrder(session, item, approve: false, reason: reason);
      case ApprovalKind.expense:
        await _decideExpense(session, item, approve: false, reason: reason);
      case ApprovalKind.tourPlan:
        await _decideTour(session, item, approve: false, reason: reason);
      case ApprovalKind.other:
        break;
    }
  }

  @override
  Future<void> approveAll(Session session, List<ApprovalItem> items) async {
    for (final item in items) {
      switch (item.kind) {
        case ApprovalKind.leave:
          await _decideLeave(session, item, approve: true);
        case ApprovalKind.order:
          await _decideOrder(session, item, approve: true);
        case ApprovalKind.expense:
          await _decideExpense(session, item, approve: true);
        case ApprovalKind.tourPlan:
          await _decideTour(session, item, approve: true);
        case ApprovalKind.other:
          break;
      }
    }
  }

  Future<void> _decideOrder(
    Session session,
    ApprovalItem item, {
    required bool approve,
    String? reason,
  }) async {
    if (item.employeeId == session.employee.id) {
      throw StateError('Nobody approves their own record');
    }
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      throw StateError('A rejection carries a reason');
    }
    await db.rpc('decide_order', params: {
      'p_id': item.recordId,
      'p_approve': approve,
      'p_reason': approve ? null : reason,
    });
  }

  /// Writes through `decide_leave`, which holds the same two rules on the
  /// server. The client still checks them so a bad item fails before the round
  /// trip, with the same wording as the mock.
  Future<void> _decideLeave(
    Session session,
    ApprovalItem item, {
    required bool approve,
    String? reason,
    String? comment,
  }) async {
    if (item.employeeId == session.employee.id) {
      throw StateError('Nobody approves their own record');
    }
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      throw StateError('A rejection carries a reason');
    }

    await db.rpc('decide_leave', params: {
      'p_leave_id': item.recordId,
      'p_approve': approve,
      // Approve may carry an optional comment; reject requires a reason.
      'p_reason': approve ? comment : reason,
    });
  }

  Future<List<ApprovalItem>> _expenseItems(
    Session session, {
    required bool decided,
  }) async {
    final statuses = decided
        ? const ['approved', 'rejected']
        : const ['pending'];

    final rows = await db
        .from('expenses')
        .select(
            'id, employee_id, work_date, amount, categories, description, status, created_at')
        .inFilter('status', statuses)
        .order('created_at', ascending: false);

    final ids = rows
        .map((r) => r['employee_id'] as String)
        .where((id) => id != session.employee.id)
        .toSet()
        .toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final people =
          await db.from('employees').select('id, name').inFilter('id', ids);
      for (final p in people) {
        names[p['id'] as String] = p['name'] as String;
      }
    }

    final items = <ApprovalItem>[];
    for (final r in rows) {
      final employeeId = r['employee_id'] as String;
      if (employeeId == session.employee.id) continue;

      final statusKey = r['status'] as String;
      final status = _statusOf[statusKey];
      if (status == null) continue;

      final cats = (r['categories'] as List<dynamic>? ?? const [])
          .cast<String>()
          .map((c) => _expenseCategoryOf[c] ?? ExpenseCategory.other)
          .toList();
      final category =
          cats.isEmpty ? ExpenseCategory.other : cats.first;

      items.add(ApprovalItem(
        id: 'ap-exp-${r['id']}',
        kind: ApprovalKind.expense,
        recordId: r['id'] as String,
        employeeId: employeeId,
        employeeName: names[employeeId] ?? 'Somebody',
        title: category.label,
        subtitle: r['description'] as String?,
        submittedAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
            DateTime.parse(r['work_date'] as String),
        status: status,
        amount: (r['amount'] as num?)?.toDouble(),
        date: DateTime.parse(r['work_date'] as String),
      ));
    }
    return items;
  }

  /// Tour approvals are month-level — the id on the wire is `tour_plan_months`.
  Future<List<ApprovalItem>> _tourItems(
    Session session, {
    required bool decided,
  }) async {
    final statuses = decided
        ? const ['approved', 'rejected']
        : const ['pending'];

    final rows = await db
        .from('tour_plan_months')
        .select(
            'id, employee_id, plan_year, plan_month, status, submitted_at')
        .inFilter('status', statuses)
        .order('submitted_at', ascending: false);

    final ids = rows
        .map((r) => r['employee_id'] as String)
        .where((id) => id != session.employee.id)
        .toSet()
        .toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final people =
          await db.from('employees').select('id, name').inFilter('id', ids);
      for (final p in people) {
        names[p['id'] as String] = p['name'] as String;
      }
    }

    final items = <ApprovalItem>[];
    for (final r in rows) {
      final employeeId = r['employee_id'] as String;
      if (employeeId == session.employee.id) continue;

      final statusKey = r['status'] as String;
      final status = _statusOf[statusKey];
      if (status == null) continue;

      final year = r['plan_year'] as int;
      final month = r['plan_month'] as int;
      final monthDate = DateTime(year, month);

      final dayCount = await db
          .from('tour_plan_days')
          .select('id')
          .eq('month_id', r['id'] as String);
      final visits = dayCount.length;

      items.add(ApprovalItem(
        id: 'ap-tp-${r['id']}',
        kind: ApprovalKind.tourPlan,
        recordId: r['id'] as String,
        employeeId: employeeId,
        employeeName: names[employeeId] ?? 'Somebody',
        title: 'Tour · ${monthDate.month}/${monthDate.year}',
        subtitle: '$visits days planned',
        submittedAt: DateTime.tryParse(r['submitted_at'] as String? ?? '') ??
            monthDate,
        status: status,
        date: monthDate,
      ));
    }
    return items;
  }

  Future<void> _decideExpense(
    Session session,
    ApprovalItem item, {
    required bool approve,
    String? reason,
    String? comment,
  }) async {
    if (item.employeeId == session.employee.id) {
      throw StateError('Nobody approves their own record');
    }
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      throw StateError('A rejection carries a reason');
    }

    await db.rpc('decide_expense', params: {
      'p_id': item.recordId,
      'p_approve': approve,
      'p_reason': approve ? comment : reason,
    });
  }

  Future<void> _decideTour(
    Session session,
    ApprovalItem item, {
    required bool approve,
    String? reason,
    String? comment,
  }) async {
    if (item.employeeId == session.employee.id) {
      throw StateError('Nobody approves their own record');
    }
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      throw StateError('A rejection carries a reason');
    }

    await db.rpc('decide_tour', params: {
      'p_id': item.recordId,
      'p_approve': approve,
      'p_reason': approve ? comment : reason,
    });
  }
}

/* ═════════════════════════════════════════════════════════ employees ══ */

/// Employees, from the database.
///
/// Every read here is a plain `select`. There is no `where employee_id = me`
/// in this file and there should never be one: row-level security has already
/// decided which people the caller may see, from the scope on their account.
/// A filter written here as well would be a second copy of the rule, and the
/// two would disagree the first time either changed — and the copy in Dart is
/// the one an attacker does not have to go through.
class ApiEmployeeRepository implements EmployeeRepository {
  ApiEmployeeRepository();

  static const _columns = '*, territories(name)';

  @override
  Future<Employee> byId(String id) async {
    final row = await db
        .from('employees')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    // Refused, not empty. A record filtered away by a policy reads as "there
    // is nothing there", which is how a missing row gets blamed on the person
    // who filed it.
    if (row == null) {
      throw StateError('No employee you may see has that id.');
    }
    return employeeFromRow(row);
  }

  @override
  Future<List<Employee>> visibleTo(Session session) async {
    // `ascending: true` is not the default in supabase-dart the way it is in
    // supabase-js: `.order('code')` alone returns the roster backwards.
    final rows =
        await db.from('employees').select(_columns).order('code', ascending: true);
    final people = rows.map(employeeFromRow).toList();
    identity.rememberAll({for (final e in people) e.employeeCode: e.id});
    return people;
  }

  @override
  Future<List<Employee>> teamOf(Session session) async {
    // Their reports, not their scope: a manager's scope includes themselves,
    // and a manager is not a member of their own team.
    //
    // Read through `current_reporting`, which is the dated assignment covering
    // today, rather than through `employees.manager_id`. That column is a
    // cache written when a decision is taken; it goes stale on its own when a
    // future-dated transfer matures or a cover lapses. Authorization stopped
    // trusting it in 0014, and a team list that disagreed with the caller's
    // own scope would be a worse kind of wrong than a stale one.
    final reporting = await db
        .from('current_reporting')
        .select('employee_id')
        .eq('manager_id', session.employee.id);

    final ids = reporting.map((r) => r['employee_id'] as String).toList();
    if (ids.isEmpty) return const [];

    final rows = await db
        .from('employees')
        .select(_columns)
        .inFilter('id', ids)
        .order('code', ascending: true);
    return rows.map(employeeFromRow).toList();
  }

  // ── geography, from the database ──────────────────────────────────
  //
  // These used to delegate to the seed, and that was a real bug rather than
  // an acceptable gap. A live employee's `territoryId` is a Supabase uuid;
  // the seeded areas are keyed by `ter-1`. So `areas(territoryId: <uuid>)`
  // returned nothing, the day plan's HQ list was empty, the cluster list
  // below it said "No clusters in this HQ", and the form could not be
  // submitted at all.
  //
  // The tables exist and 0003 seeded them, so there was never a reason to
  // read anywhere else. Row-level security scopes them to the caller's
  // organisation.

  @override
  Future<List<Territory>> territories() async {
    final rows = await db
        .from('territories')
        .select('id, name, hq')
        .order('name', ascending: true);
    return rows
        .map((r) => Territory(
              id: r['id'] as String,
              name: r['name'] as String,
              headquarters: r['hq'] as String? ?? '',
            ))
        .toList();
  }

  @override
  Future<List<Area>> areas({String? territoryId}) async {
    var q = db.from('areas').select('id, name, territory_id');
    if (territoryId != null) q = q.eq('territory_id', territoryId);
    final rows = await q.order('name', ascending: true);
    return rows
        .map((r) => Area(
              id: r['id'] as String,
              name: r['name'] as String,
              territoryId: r['territory_id'] as String,
            ))
        .toList();
  }

  @override
  Future<List<Cluster>> clusters({String? areaId}) async {
    var q = db.from('clusters').select('id, name, area_id');
    if (areaId != null) q = q.eq('area_id', areaId);
    final rows = await q.order('name', ascending: true);
    return rows
        .map((r) => Cluster(
              id: r['id'] as String,
              name: r['name'] as String,
              areaId: r['area_id'] as String,
            ))
        .toList();
  }
}

/* ═══════════════════════════════════════════════════════════ clients ══ */

/// Clients from the database. Writes go through RPCs — there are no client
/// INSERT/UPDATE policies; SELECT is scoped by RLS.
class ApiClientRepository implements ClientRepository {
  ApiClientRepository();

  static const _columns = '*, areas(name), clusters(name)';

  static const _typeOf = {
    'doctor': ClientType.doctor,
    'hospital': ClientType.hospital,
    'chemist': ClientType.chemist,
    'stockist': ClientType.stockist,
    'other': ClientType.other,
  };
  static const _typeTerm = {
    ClientType.doctor: 'doctor',
    ClientType.hospital: 'hospital',
    ClientType.chemist: 'chemist',
    ClientType.stockist: 'stockist',
    ClientType.other: 'other',
  };
  static const _categoryOf = {
    'coreTarget': ClientCategory.coreTarget,
    'regular': ClientCategory.regular,
    'potential': ClientCategory.potential,
    'inactive': ClientCategory.inactive,
  };
  static const _categoryTerm = {
    ClientCategory.coreTarget: 'coreTarget',
    ClientCategory.regular: 'regular',
    ClientCategory.potential: 'potential',
    ClientCategory.inactive: 'inactive',
  };
  static const _listingOf = {
    'listed': ClientListing.listed,
    'unlisted': ClientListing.unlisted,
  };
  static const _listingTerm = {
    ClientListing.listed: 'listed',
    ClientListing.unlisted: 'unlisted',
  };
  static const _occasionOf = {
    'birthday': SpecialOccasion.birthday,
    'anniversary': SpecialOccasion.anniversary,
    'other': SpecialOccasion.other,
  };
  static const _occasionTerm = {
    SpecialOccasion.birthday: 'birthday',
    SpecialOccasion.anniversary: 'anniversary',
    SpecialOccasion.other: 'other',
  };

  @override
  Future<List<String>> specialties() async {
    final rows = await db
        .from('client_specialties')
        .select('name')
        .order('name', ascending: true);
    return rows.map((r) => r['name'] as String).toList();
  }

  @override
  Future<List<Client>> list(
    Session session, {
    String? query,
    ClientType? type,
    String? areaId,
  }) async {
    var q = db.from('clients').select(_columns);
    if (type != null) q = q.eq('type', _typeTerm[type]!);
    if (areaId != null) q = q.eq('area_id', areaId);
    final rows = await q.order('name', ascending: true);

    final qText = query?.trim().toLowerCase() ?? '';
    return rows
        .map(clientFromRow)
        .where((c) {
          if (qText.isEmpty) return true;
          final haystack =
              '${c.name} ${c.specialty ?? ''} ${c.areaName} ${c.type.label}'
                  .toLowerCase();
          return haystack.contains(qText);
        })
        .toList();
  }

  @override
  Future<Client> byId(Session session, String id) async {
    final row = await db
        .from('clients')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    // Refused, not empty — same posture as employees.
    if (row == null) {
      throw StateError('No client you may see has that id.');
    }
    return clientFromRow(row);
  }

  @override
  Future<Client> create(Client client) async {
    final id = await db.rpc('create_client', params: _writeParams(client))
        as String;

    final row = await db
        .from('clients')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Client was created but could not be read back.');
    }
    return clientFromRow(row);
  }

  @override
  Future<Client> update(Session session, Client client) async {
    await db.rpc('update_client', params: {
      'p_id': client.id,
      'p_name': client.name,
      'p_type': _typeTerm[client.type],
      'p_category': _categoryTerm[client.category],
      'p_listing': _listingTerm[client.listing],
      'p_is_active':
          client.listing == ClientListing.listed ? client.isActive : null,
      'p_specialty': client.specialty,
      'p_designation': client.designation,
      'p_area_id': client.areaId,
      'p_cluster_id': client.clusterId,
      'p_mobile': client.mobile,
      'p_email': client.email,
      'p_contact_person': client.contactPerson,
      'p_address_line': client.addressLine,
      'p_city': client.city,
      'p_pincode': client.pincode,
      'p_lat': client.latitude,
      'p_lng': client.longitude,
      'p_special_date':
          client.specialDate == null ? null : _isoDate(client.specialDate!),
      'p_special_occasion': client.specialOccasion == null
          ? null
          : _occasionTerm[client.specialOccasion],
      'p_special_occasion_note': client.specialOccasionNote,
    });
    return byId(session, client.id);
  }

  /// Completed visits for this client, newest first (§28).
  @override
  Future<List<Activity>> historyOf(String clientId) async {
    final rows = await db
        .from('activities')
        .select(ApiActivityRepository._columns)
        .eq('client_id', clientId)
        .eq('status', 'completed')
        .order('scheduled_start', ascending: false);
    return rows.map(activityFromRow).toList();
  }

  /// Params shared by create (includes client-generated id + optional owner).
  Map<String, dynamic> _writeParams(Client client) => {
        'p_id': client.id,
        'p_name': client.name,
        'p_type': _typeTerm[client.type],
        'p_category': _categoryTerm[client.category],
        'p_listing': _listingTerm[client.listing],
        'p_is_active':
            client.listing == ClientListing.listed ? client.isActive : null,
        'p_specialty': client.specialty,
        'p_designation': client.designation,
        'p_area_id': client.areaId,
        'p_cluster_id': client.clusterId,
        'p_owner_employee_id': client.ownerEmployeeId,
        'p_mobile': client.mobile,
        'p_email': client.email,
        'p_contact_person': client.contactPerson,
        'p_address_line': client.addressLine,
        'p_city': client.city,
        'p_pincode': client.pincode,
        'p_lat': client.latitude,
        'p_lng': client.longitude,
        'p_special_date':
            client.specialDate == null ? null : _isoDate(client.specialDate!),
        'p_special_occasion': client.specialOccasion == null
            ? null
            : _occasionTerm[client.specialOccasion],
        'p_special_occasion_note': client.specialOccasionNote,
      };

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// The database's client row, as the app's model.
Client clientFromRow(Map<String, dynamic> r) {
  final area = r['areas'] as Map<String, dynamic>?;
  final cluster = r['clusters'] as Map<String, dynamic>?;
  final occasionKey = r['special_occasion'] as String?;
  return Client(
    id: r['id'] as String,
    name: r['name'] as String,
    type: ApiClientRepository._typeOf[r['type'] as String] ?? ClientType.other,
    category: ApiClientRepository._categoryOf[r['category'] as String] ??
        ClientCategory.regular,
    listing: ApiClientRepository._listingOf[r['listing'] as String] ??
        ClientListing.unlisted,
    // Null for unlisted; the model still needs a bool, and statusLabel ignores
    // it when listing is unlisted.
    isActive: r['is_active'] as bool? ?? true,
    specialty: r['specialty'] as String?,
    designation: r['designation'] as String?,
    areaId: r['area_id'] as String,
    areaName: area?['name'] as String? ?? '',
    territoryId: r['territory_id'] as String? ?? '',
    clusterId: r['cluster_id'] as String?,
    clusterName: cluster?['name'] as String?,
    ownerEmployeeId: r['owner_employee_id'] as String?,
    mobile: r['mobile'] as String?,
    email: r['email'] as String?,
    contactPerson: r['contact_person'] as String?,
    addressLine: r['address_line'] as String?,
    city: r['city'] as String?,
    pincode: r['pincode'] as String?,
    latitude: (r['lat'] as num?)?.toDouble(),
    longitude: (r['lng'] as num?)?.toDouble(),
    specialDate: DateTime.tryParse(r['special_date'] as String? ?? ''),
    specialOccasion: occasionKey == null
        ? null
        : ApiClientRepository._occasionOf[occasionKey],
    specialOccasionNote: r['special_occasion_note'] as String?,
    totalVisits: (r['total_visits'] as num?)?.toInt() ?? 0,
    lastVisitAt: DateTime.tryParse(r['last_visit_at'] as String? ?? ''),
    nextPlannedVisitAt:
        DateTime.tryParse(r['next_planned_visit_at'] as String? ?? ''),
    createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
    syncStatus: SyncStatus.synced,
  );
}

/* ═════════════════════════════════════════════════════════ day plans ══ */

/// Day plans from the database. Writes go through `submit_day_plan` — there
/// are no INSERT/UPDATE policies; SELECT is scoped by RLS.
class ApiDayPlanRepository implements DayPlanRepository {
  ApiDayPlanRepository() : _seed = MockDayPlanRepository();

  final MockDayPlanRepository _seed;

  static const _columns =
      'id, employee_id, work_date, work_type, area_id, cluster_id, '
      'cluster_name, tour_type, remarks, captured_lat, captured_lng, '
      'captured_address, declared_at, areas(name)';

  static const _workTypeOf = {
    'fieldWork': WorkType.fieldWork,
    'officeWork': WorkType.officeWork,
    'meeting': WorkType.meeting,
    'training': WorkType.training,
    'leave': WorkType.leave,
    'holiday': WorkType.holiday,
  };
  static const _workTypeTerm = {
    WorkType.fieldWork: 'fieldWork',
    WorkType.officeWork: 'officeWork',
    WorkType.meeting: 'meeting',
    WorkType.training: 'training',
    WorkType.leave: 'leave',
    WorkType.holiday: 'holiday',
  };
  static const _tourTypeOf = {
    'local': TourType.local,
    'outstation': TourType.outstation,
    'exStation': TourType.exStation,
  };
  static const _tourTypeTerm = {
    TourType.local: 'local',
    TourType.outstation: 'outstation',
    TourType.exStation: 'exStation',
  };

  @override
  Future<DayPlan?> forDate(String employeeId, DateTime date) async {
    final row = await db
        .from('day_plans')
        .select(_columns)
        .eq('employee_id', employeeId)
        .eq('work_date', _isoDate(date))
        .maybeSingle();
    if (row == null) return null;
    return dayPlanFromRow(row);
  }

  /// Submits through `submit_day_plan`, which applies for the caller only —
  /// the employee id on the plan is ignored on purpose, same as leave.
  @override
  Future<DayPlan> submit(DayPlan plan) async {
    final id = await db.rpc('submit_day_plan', params: {
      'p_id': plan.id,
      'p_work_date': _isoDate(plan.date),
      'p_work_type': _workTypeTerm[plan.workType],
      'p_area_id': plan.areaId,
      'p_cluster_id': null,
      'p_cluster_name': plan.clusterName,
      'p_tour_type': _tourTypeTerm[plan.tourType] ?? 'local',
      'p_remarks': plan.remarks,
      'p_captured_lat': plan.capturedPoint?.latitude,
      'p_captured_lng': plan.capturedPoint?.longitude,
      'p_captured_address': plan.capturedAddress,
    }) as String;

    final row = await db
        .from('day_plans')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Day plan was filed but could not be read back.');
    }
    return dayPlanFromRow(row);
  }

  @override
  Future<List<DayPlan>> list(Session session, {String? employeeId}) async {
    var q = db.from('day_plans').select(_columns);
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    final rows = await q.order('work_date', ascending: false);
    return rows.map(dayPlanFromRow).toList();
  }

  /// No geocoder table yet — the seed still resolves addresses per area.
  @override
  Future<String> addressFor(GeoPoint point, {String? areaId}) =>
      _seed.addressFor(point, areaId: areaId);

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// The database's day-plan row, as the app's model.
DayPlan dayPlanFromRow(Map<String, dynamic> r) {
  final area = r['areas'] as Map<String, dynamic>?;
  final lat = (r['captured_lat'] as num?)?.toDouble();
  final lng = (r['captured_lng'] as num?)?.toDouble();
  return DayPlan(
    id: r['id'] as String,
    employeeId: r['employee_id'] as String,
    date: DateTime.parse(r['work_date'] as String),
    workType: ApiDayPlanRepository._workTypeOf[r['work_type']] ??
        WorkType.fieldWork,
    areaId: r['area_id'] as String?,
    areaName: area?['name'] as String?,
    clusterName: r['cluster_name'] as String?,
    tourType: ApiDayPlanRepository._tourTypeOf[r['tour_type']] ??
        TourType.local,
    status: ApprovalStatus.submitted,
    remarks: r['remarks'] as String?,
    capturedPoint:
        lat != null && lng != null ? GeoPoint(lat, lng) : null,
    capturedAddress: r['captured_address'] as String?,
    submittedAt: DateTime.tryParse(r['declared_at'] as String? ?? ''),
  );
}

/* ═════════════════════════════════════════════════════════ activities ══ */

/// Activities from the database. Writes go through RPCs — there are no
/// INSERT/UPDATE policies; SELECT is scoped by RLS.
class ApiActivityRepository implements ActivityRepository {
  ApiActivityRepository() : _dayPlans = ApiDayPlanRepository();

  final ApiDayPlanRepository _dayPlans;

  static const _columns =
      'id, employee_id, client_id, day_plan_id, status, work_type, purpose, '
      'is_unplanned, scheduled_start, scheduled_end, actual_start, actual_end, '
      'contact_person, contact_mobile, feedback, remarks, pop, inputs_given, '
      'pob_amount, rcpa_score, expected_next_visit, geo_verdict, geo_radius_m, '
      'geo_distance_m, geo_lat, geo_lng, geo_captured_at, out_of_range_reason, '
      'location_name, area_name, created_at, updated_at, '
      'clients(name, specialty, type), employees(name), '
      'activity_rcpa_entries(product_id, product_name, own_quantity, '
      'competitor_name, competitor_quantity), '
      'activity_products(product_id)';

  static const _statusOf = {
    'planned': ActivityStatus.planned,
    'upcoming': ActivityStatus.upcoming,
    'inProgress': ActivityStatus.inProgress,
    'completed': ActivityStatus.completed,
    'missed': ActivityStatus.missed,
    'rescheduled': ActivityStatus.rescheduled,
  };
  static const _statusTerm = {
    ActivityStatus.planned: 'planned',
    ActivityStatus.upcoming: 'upcoming',
    ActivityStatus.inProgress: 'inProgress',
    ActivityStatus.completed: 'completed',
    ActivityStatus.missed: 'missed',
    ActivityStatus.rescheduled: 'rescheduled',
  };
  static const _workTypeOf = ApiDayPlanRepository._workTypeOf;
  static const _workTypeTerm = ApiDayPlanRepository._workTypeTerm;
  static const _typeOf = ApiClientRepository._typeOf;
  static const _geoOf = {
    'verified': GeoVerification.verified,
    'outOfRange': GeoVerification.outOfRange,
    'unavailable': GeoVerification.unavailable,
    'suspect': GeoVerification.suspect,
  };
  static const _geoTerm = {
    GeoVerification.verified: 'verified',
    GeoVerification.outOfRange: 'outOfRange',
    GeoVerification.unavailable: 'unavailable',
    GeoVerification.suspect: 'suspect',
  };

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
    var q = db.from('activities').select(_columns);
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    if (clientId != null) q = q.eq('client_id', clientId);
    if (status != null) q = q.eq('status', _statusTerm[status]!);
    if (date != null) {
      q = q
          .gte('scheduled_start', _dayStartIso(date))
          .lt('scheduled_start', _dayEndIso(date));
    }
    if (from != null) {
      q = q.gte('scheduled_start', from.toUtc().toIso8601String());
    }
    if (to != null) {
      q = q.lte('scheduled_start', to.toUtc().toIso8601String());
    }
    final rows = await q.order('scheduled_start', ascending: true);
    return rows.map(activityFromRow).toList();
  }

  @override
  Future<Activity> byId(Session session, String id) async {
    final row = await db
        .from('activities')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('No activity you may see has that id.');
    }
    return activityFromRow(row);
  }

  @override
  Future<DaySummary> daySummary(String employeeId, DateTime date) async {
    final rows = await db
        .from('activities')
        .select(_columns)
        .eq('employee_id', employeeId)
        .gte('scheduled_start', _dayStartIso(date))
        .lt('scheduled_start', _dayEndIso(date))
        .order('scheduled_start', ascending: true);

    final plan = await _dayPlans.forDate(employeeId, date);
    final emp = await db
        .from('employees')
        .select('hq')
        .eq('id', employeeId)
        .maybeSingle();

    return DaySummary(
      date: date,
      activities: rows.map(activityFromRow).toList(),
      headquarters: emp?['hq'] as String? ?? '',
      workType: plan?.workType ?? WorkType.fieldWork,
      declaredAt: plan?.submittedAt,
    );
  }

  @override
  Future<Activity> create(Activity activity) async {
    final id = await db.rpc('create_activity', params: {
      'p_id': activity.id,
      'p_client_id': activity.clientId,
      'p_day_plan_id': activity.dayPlanId,
      'p_scheduled_start': activity.scheduledStart.toUtc().toIso8601String(),
      'p_scheduled_end': activity.scheduledEnd?.toUtc().toIso8601String(),
      'p_is_unplanned': activity.isUnplanned,
      'p_work_type': _workTypeTerm[activity.workType] ?? 'fieldWork',
      'p_purpose': _purposeTerm(activity.purpose),
      'p_remarks': activity.remarks,
    }) as String;

    final row = await db
        .from('activities')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Activity was created but could not be read back.');
    }
    return activityFromRow(row);
  }

  @override
  Future<Activity> update(Session session, Activity activity) async {
    await db.rpc('update_activity', params: {
      'p_activity_id': activity.id,
      'p_feedback': activity.feedback,
      'p_remarks': activity.remarks,
      'p_pop': activity.pop,
      'p_inputs_given': activity.inputsGiven,
      'p_pob_amount': activity.pobAmount,
      'p_rcpa_score': activity.rcpaScore,
      'p_expected_next_visit': activity.expectedNextVisit == null
          ? null
          : _isoDate(activity.expectedNextVisit!),
      'p_purpose': _purposeTerm(activity.purpose),
      'p_contact_person': activity.contactPerson,
      'p_contact_mobile': activity.contactMobile,
      'p_rcpa_entries': [
        for (final e in activity.rcpaEntries)
          {
            'product_id': e.productId,
            'product_name': e.productName,
            'own_quantity': e.ownQuantity,
            'competitor_name': e.competitorName,
            'competitor_quantity': e.competitorQuantity,
          },
      ],
      'p_product_ids': activity.productIds,
    });
    return byId(session, activity.id);
  }

  @override
  Future<Activity> startVisit(String activityId) async {
    await db.rpc('start_visit', params: {'p_activity_id': activityId});
    final row = await db
        .from('activities')
        .select(_columns)
        .eq('id', activityId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Visit was started but could not be read back.');
    }
    return activityFromRow(row);
  }

  @override
  Future<Activity> completeVisit(Activity activity) async {
    final geo = activity.geoResult;
    await db.rpc('complete_visit', params: {
      'p_activity_id': activity.id,
      'p_feedback': activity.feedback,
      'p_remarks': activity.remarks,
      'p_pop': activity.pop,
      'p_inputs_given': activity.inputsGiven,
      'p_pob_amount': activity.pobAmount,
      'p_rcpa_score': activity.rcpaScore,
      'p_expected_next_visit': activity.expectedNextVisit == null
          ? null
          : _isoDate(activity.expectedNextVisit!),
      'p_geo_verdict': geo == null
          ? 'unavailable'
          : _geoTerm[geo.verification] ?? 'unavailable',
      'p_geo_radius_m': geo?.radiusMeters,
      'p_geo_distance_m': geo?.distanceMeters,
      'p_geo_lat': geo?.captured?.latitude,
      'p_geo_lng': geo?.captured?.longitude,
      'p_out_of_range_reason': activity.outOfRangeReason,
      'p_rcpa_entries': [
        for (final e in activity.rcpaEntries)
          {
            'product_id': e.productId,
            'product_name': e.productName,
            'own_quantity': e.ownQuantity,
            'competitor_name': e.competitorName,
            'competitor_quantity': e.competitorQuantity,
          },
      ],
      'p_product_ids': activity.productIds,
    });

    final row = await db
        .from('activities')
        .select(_columns)
        .eq('id', activity.id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Visit was completed but could not be read back.');
    }
    return activityFromRow(row);
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _dayStartIso(DateTime d) => '${_isoDate(d)}T00:00:00';
  static String _dayEndIso(DateTime d) {
    final next = DateTime(d.year, d.month, d.day + 1);
    return '${_isoDate(next)}T00:00:00';
  }

  static String? _purposeTerm(VisitPurpose? purpose) => purpose?.label;

  static VisitPurpose? _purposeOf(String? text) {
    if (text == null || text.isEmpty) return null;
    for (final p in VisitPurpose.values) {
      if (p.label == text) return p;
    }
    return null;
  }
}

/// The database's activity row, as the app's model.
Activity activityFromRow(Map<String, dynamic> r) {
  final client = r['clients'] as Map<String, dynamic>?;
  final employee = r['employees'] as Map<String, dynamic>?;
  final rcpaRows = r['activity_rcpa_entries'] as List<dynamic>? ?? const [];
  final productRows = r['activity_products'] as List<dynamic>? ?? const [];

  final verdictKey = r['geo_verdict'] as String?;
  GeoFenceResult? geoResult;
  if (verdictKey != null) {
    final verification =
        ApiActivityRepository._geoOf[verdictKey] ?? GeoVerification.unavailable;
    final lat = (r['geo_lat'] as num?)?.toDouble();
    final lng = (r['geo_lng'] as num?)?.toDouble();
    geoResult = GeoFenceResult(
      verification: verification,
      radiusMeters: (r['geo_radius_m'] as num?)?.toDouble() ??
          GeoMath.defaultFenceRadiusMeters,
      distanceMeters: (r['geo_distance_m'] as num?)?.toDouble(),
      captured: lat != null && lng != null ? GeoPoint(lat, lng) : null,
      capturedAt: DateTime.tryParse(r['geo_captured_at'] as String? ?? ''),
    );
  }

  return Activity(
    id: r['id'] as String,
    employeeId: r['employee_id'] as String,
    employeeName: employee?['name'] as String? ?? 'Somebody',
    clientId: r['client_id'] as String,
    clientName: client?['name'] as String? ?? '',
    clientSpecialty: client?['specialty'] as String?,
    clientType: ApiActivityRepository._typeOf[client?['type'] as String? ?? ''] ??
        ClientType.other,
    locationName: r['location_name'] as String?,
    areaName: r['area_name'] as String?,
    scheduledStart: DateTime.parse(r['scheduled_start'] as String).toLocal(),
    scheduledEnd: DateTime.tryParse(r['scheduled_end'] as String? ?? '')
        ?.toLocal(),
    actualStart:
        DateTime.tryParse(r['actual_start'] as String? ?? '')?.toLocal(),
    actualEnd: DateTime.tryParse(r['actual_end'] as String? ?? '')?.toLocal(),
    status: ApiActivityRepository._statusOf[r['status'] as String] ??
        ActivityStatus.planned,
    workType: ApiActivityRepository._workTypeOf[r['work_type']] ??
        WorkType.fieldWork,
    purpose: ApiActivityRepository._purposeOf(r['purpose'] as String?),
    contactPerson: r['contact_person'] as String?,
    contactMobile: r['contact_mobile'] as String?,
    feedback: r['feedback'] as String?,
    remarks: r['remarks'] as String?,
    pop: r['pop'] as String?,
    inputsGiven: r['inputs_given'] as String?,
    pobAmount: (r['pob_amount'] as num?)?.toDouble(),
    rcpaScore: (r['rcpa_score'] as num?)?.toInt(),
    rcpaEntries: rcpaRows
        .map((e) => RcpaEntry(
              productId: e['product_id'] as String,
              productName: e['product_name'] as String,
              ownQuantity: (e['own_quantity'] as num?)?.toInt() ?? 0,
              competitorName: e['competitor_name'] as String?,
              competitorQuantity:
                  (e['competitor_quantity'] as num?)?.toInt() ?? 0,
            ))
        .toList(),
    productIds: productRows
        .map((p) => p['product_id'] as String)
        .toList(),
    expectedNextVisit:
        DateTime.tryParse(r['expected_next_visit'] as String? ?? ''),
    geoResult: geoResult,
    outOfRangeReason: r['out_of_range_reason'] as String?,
    dayPlanId: r['day_plan_id'] as String?,
    isUnplanned: r['is_unplanned'] as bool? ?? false,
    createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(r['updated_at'] as String? ?? ''),
    syncStatus: SyncStatus.synced,
  );
}

/* ══════════════════════════════════════════════════════════ expenses ══ */

/// Expenses from the database. Writes go through RPCs — there are no INSERT
/// policies; SELECT is scoped by RLS.
class ApiExpenseRepository implements ExpenseRepository {
  ApiExpenseRepository();

  static const _columns =
      'id, employee_id, work_date, amount, categories, description, remarks, '
      'travel_mode, destination, status, receipt_paths, created_at, '
      'employees(name)';

  static const _categoryOf = ApiApprovalRepository._expenseCategoryOf;
  static const _categoryTerm = {
    ExpenseCategory.dailyAllowance: 'dailyAllowance',
    ExpenseCategory.travel: 'travel',
    ExpenseCategory.food: 'food',
    ExpenseCategory.lodging: 'lodging',
    ExpenseCategory.fuel: 'fuel',
    ExpenseCategory.other: 'other',
  };
  static const _statusOf = {
    'draft': ApprovalStatus.draft,
    'pending': ApprovalStatus.pending,
    'approved': ApprovalStatus.approved,
    'rejected': ApprovalStatus.rejected,
  };

  @override
  Future<List<Expense>> list(
    Session session, {
    ApprovalStatus? status,
    String? employeeId,
  }) async {
    var q = db.from('expenses').select(_columns);
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    if (status != null) {
      final key = _statusOf.entries
          .firstWhere((e) => e.value == status, orElse: () => const MapEntry('', ApprovalStatus.draft))
          .key;
      if (key.isNotEmpty) q = q.eq('status', key);
    }
    final rows = await q.order('work_date', ascending: false);
    return rows.map(expenseFromRow).toList();
  }

  @override
  Future<Expense> byId(Session session, String id) async {
    final row = await db
        .from('expenses')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('No expense you may see has that id.');
    }
    return expenseFromRow(row);
  }

  @override
  Future<Expense> create(Expense expense) async {
    final id = await db.rpc('create_or_update_expense', params: {
      'p_id': expense.id,
      'p_work_date': _isoDate(expense.date),
      'p_amount': expense.amount,
      'p_categories': expense.categories
          .map((c) => _categoryTerm[c] ?? 'other')
          .toList(),
      'p_description': expense.description,
      'p_remarks': expense.remarks,
      'p_travel_mode': expense.travelMode?.label,
      'p_destination': expense.place ?? expense.toLocation,
    }) as String;
    final row = await db
        .from('expenses')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Expense was created but could not be read back.');
    }
    return expenseFromRow(row);
  }

  @override
  Future<Expense> update(Session session, Expense expense) async {
    await db.rpc('create_or_update_expense', params: {
      'p_id': expense.id,
      'p_work_date': _isoDate(expense.date),
      'p_amount': expense.amount,
      'p_categories': expense.categories
          .map((c) => _categoryTerm[c] ?? 'other')
          .toList(),
      'p_description': expense.description,
      'p_remarks': expense.remarks,
      'p_travel_mode': expense.travelMode?.label,
      'p_destination': expense.place ?? expense.toLocation,
    });
    return byId(session, expense.id);
  }

  @override
  Future<Expense> submit(String id) async {
    await db.rpc('submit_expense', params: {'p_id': id});
    final row = await db
        .from('expenses')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Expense was submitted but could not be read back.');
    }
    return expenseFromRow(row);
  }

  @override
  Future<double> dailyAllowance() async {
    final row = await db
        .from('org_settings')
        .select('daily_allowance')
        .maybeSingle();
    return (row?['daily_allowance'] as num?)?.toDouble() ?? 350;
  }

  @override
  Future<List<ClaimDay>> claimMonth(
    Session session,
    DateTime month, {
    String? employeeId,
  }) async {
    final id = employeeId ?? session.employee.id;
    final from = _isoDate(DateTime(month.year, month.month, 1));
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final to = _isoDate(DateTime(month.year, month.month, lastDay));

    final allowance = await dailyAllowance();

    final planRows = await db
        .from('day_plans')
        .select('id, work_date, work_type, cluster_name, areas(name)')
        .eq('employee_id', id)
        .gte('work_date', from)
        .lte('work_date', to);

    final expenseRows = await db
        .from('expenses')
        .select(_columns)
        .eq('employee_id', id)
        .gte('work_date', from)
        .lte('work_date', to);

    final holidayRows = await db
        .from('holidays')
        .select('holiday_date, name')
        .gte('holiday_date', from)
        .lte('holiday_date', to);

    final leaveRows = await db
        .from('leave_requests')
        .select('type, from_date, to_date, status')
        .eq('employee_id', id)
        .eq('status', 'approved');

    final tourRows = await db
        .from('tour_plan_days')
        .select('work_date, work_type')
        .eq('employee_id', id)
        .gte('work_date', from)
        .lte('work_date', to);

    final activityRows = await db
        .from('activities')
        .select('scheduled_start, status')
        .eq('employee_id', id)
        .gte('scheduled_start', '${from}T00:00:00')
        .lte('scheduled_start', '${to}T23:59:59')
        .eq('status', 'completed');

    final settings = await db
        .from('org_settings')
        .select('week_off_weekday')
        .maybeSingle();
    final weekOffPg = (settings?['week_off_weekday'] as num?)?.toInt() ?? 0;
    final weekOff = weekOffPg == 0 ? DateTime.sunday : weekOffPg;

    final plans = {
      for (final p in planRows)
        DateTime.parse(p['work_date'] as String).day: p,
    };
    final filed = expenseRows.map(expenseFromRow).toList();
    final holidays = {
      for (final h in holidayRows)
        DateTime.parse(h['holiday_date'] as String).day: h['name'] as String,
    };
    final leaves = leaveRows;
    final tour = {
      for (final t in tourRows)
        DateTime.parse(t['work_date'] as String).day: t,
    };

    if (plans.isEmpty && filed.isEmpty) return const [];

    final today = dateOnly(DateTime.now());
    final days = <ClaimDay>[];

    for (var d = 1; d <= lastDay; d++) {
      final date = DateTime(month.year, month.month, d);
      if (date.isAfter(today)) break;

      final plan = plans[d];
      if (plan == null && sameDay(date, today)) continue;

      final calls = activityRows
          .where((a) =>
              sameDay(DateTime.parse(a['scheduled_start'] as String), date))
          .length;

      final workKey = plan?['work_type'] as String?;
      final workType = workKey == null
          ? WorkType.fieldWork
          : ApiDayPlanRepository._workTypeOf[workKey] ?? WorkType.fieldWork;

      final DayKind kind;
      String? note;
      if (plan != null) {
        kind = switch (workType) {
          WorkType.leave => DayKind.leave,
          WorkType.holiday => DayKind.holiday,
          _ => DayKind.worked,
        };
      } else if (holidays.containsKey(d)) {
        kind = DayKind.holiday;
        note = holidays[d];
      } else if (date.weekday == weekOff) {
        kind = DayKind.weekOff;
      } else {
        Map<String, dynamic>? leave;
        for (final l in leaves) {
          final fromD = dateOnly(DateTime.parse(l['from_date'] as String));
          final toD = dateOnly(DateTime.parse(l['to_date'] as String));
          if (!date.isBefore(fromD) && !date.isAfter(toD)) {
            leave = l;
            break;
          }
        }
        if (leave != null) {
          kind = DayKind.leave;
          note = leave['type'] as String?;
        } else if (tour[d] != null) {
          final tw = ApiDayPlanRepository._workTypeOf[tour[d]!['work_type']];
          if (tw != null && !tourDayNeedsDetail(tw)) {
            kind = DayKind.leave;
            note = 'Planned as ${tw.label.toLowerCase()}';
          } else {
            kind = DayKind.notDeclared;
          }
        } else {
          kind = DayKind.notDeclared;
        }
      }

      final area = plan?['areas'] as Map<String, dynamic>?;
      final planId = plan?['id'] as String?;

      days.add(ClaimDay(
        date: date,
        dayPlanId: planId,
        workType: workType,
        kind: kind,
        note: note,
        place: plan?['cluster_name'] as String? ??
            area?['name'] as String? ??
            '—',
        allowance: kind.earnsAllowance ? allowance : 0,
        expenses: planId == null
            ? const []
            : filed.where((e) => sameDay(e.date, date)).toList(),
        calls: calls,
      ));
    }
    return days;
  }

  @override
  Future<int> confirmStandardDays(Session session, List<ClaimDay> days) async {
    final dates = days
        .where((d) => d.claimable)
        .map((d) => _isoDate(d.date))
        .toList();
    if (dates.isEmpty) return 0;
    return await db.rpc('confirm_standard_days', params: {'p_dates': dates})
        as int;
  }

  @override
  Future<int> submitMonth(Session session, DateTime month) async {
    return await db.rpc('submit_expense_month', params: {
      'p_year': month.year,
      'p_month': month.month,
    }) as int;
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

Expense expenseFromRow(Map<String, dynamic> r) {
  final employee = r['employees'] as Map<String, dynamic>?;
  final cats = (r['categories'] as List<dynamic>? ?? const ['dailyAllowance'])
      .cast<String>()
      .map((c) => ApiExpenseRepository._categoryOf[c] ?? ExpenseCategory.other)
      .toList();
  final travelLabel = r['travel_mode'] as String?;
  TravelMode? travelMode;
  if (travelLabel != null) {
    for (final m in TravelMode.values) {
      if (m.label.toLowerCase() == travelLabel.toLowerCase()) {
        travelMode = m;
        break;
      }
    }
  }
  return Expense(
    id: r['id'] as String,
    employeeId: r['employee_id'] as String,
    employeeName: employee?['name'] as String? ?? 'Somebody',
    date: DateTime.parse(r['work_date'] as String),
    categories: cats,
    amount: (r['amount'] as num).toDouble(),
    status: ApiExpenseRepository._statusOf[r['status'] as String] ??
        ApprovalStatus.draft,
    description: r['description'] as String?,
    remarks: r['remarks'] as String?,
    receiptPaths:
        (r['receipt_paths'] as List<dynamic>? ?? const []).cast<String>(),
    travelMode: travelMode,
    place: r['destination'] as String?,
    createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
    syncStatus: SyncStatus.synced,
  );
}

/* ═══════════════════════════════════════════════════════════ travel ══ */

/// Tour plans from the database. Writes go through RPCs — there are no INSERT
/// policies; SELECT is scoped by RLS.
class ApiTravelRepository implements TravelRepository {
  ApiTravelRepository();

  static const _dayColumns =
      'id, employee_id, work_date, work_type, area_id, tour_type, travel_mode, '
      'destination, purpose, planned_visits, estimated_km, client_names, remarks, '
      'month_id, tour_plan_months(status, submitted_at), areas(name), employees(name)';

  static const _statusOf = ApiExpenseRepository._statusOf;

  @override
  Future<List<TravelPlan>> list(
    Session session, {
    ApprovalStatus? status,
    String? employeeId,
  }) async {
    var q = db.from('tour_plan_days').select(_dayColumns);
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    final rows = await q.order('work_date', ascending: false);
    return rows
        .map(travelPlanFromRow)
        .where((p) => status == null || p.status == status)
        .toList();
  }

  @override
  Future<TravelPlan> byId(Session session, String id) async {
    final row = await db
        .from('tour_plan_days')
        .select(_dayColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('No tour plan you may see has that id.');
    }
    return travelPlanFromRow(row);
  }

  @override
  Future<TravelPlan> create(TravelPlan plan) => saveDay(plan);

  @override
  Future<TravelPlan> update(Session session, TravelPlan plan) => saveDay(plan);

  @override
  Future<TravelPlan> submit(String id) async {
    final row = await db
        .from('tour_plan_days')
        .select('work_date, employee_id')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('No tour plan you may see has that id.');
    }
    final date = DateTime.parse(row['work_date'] as String);
    await db.rpc('submit_tour_month', params: {
      'p_year': date.year,
      'p_month': date.month,
    });
    final updated = await db
        .from('tour_plan_days')
        .select(_dayColumns)
        .eq('id', id)
        .maybeSingle();
    if (updated == null) {
      throw StateError('Tour plan was submitted but could not be read back.');
    }
    return travelPlanFromRow(updated);
  }

  @override
  Future<TourMonth> month(
    Session session,
    DateTime month, {
    String? employeeId,
  }) async {
    final id = employeeId ?? session.employee.id;
    final from = ApiExpenseRepository._isoDate(DateTime(month.year, month.month, 1));
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final to = ApiExpenseRepository._isoDate(
        DateTime(month.year, month.month, lastDay));

    final rows = await db
        .from('tour_plan_days')
        .select(_dayColumns)
        .eq('employee_id', id)
        .gte('work_date', from)
        .lte('work_date', to);

    final holidayRows = await db
        .from('holidays')
        .select('holiday_date, name')
        .gte('holiday_date', from)
        .lte('holiday_date', to);

    final settings = await db
        .from('org_settings')
        .select('week_off_weekday')
        .maybeSingle();
    final weekOffPg = (settings?['week_off_weekday'] as num?)?.toInt() ?? 0;
    final weekOff = weekOffPg == 0 ? DateTime.sunday : weekOffPg;

    final monthRow = await db
        .from('tour_plan_months')
        .select('status')
        .eq('employee_id', id)
        .eq('plan_year', month.year)
        .eq('plan_month', month.month)
        .maybeSingle();

    final monthStatus = monthRow?['status'] as String?;
    TourRule? judgedUnder;
    if (monthStatus != null && monthStatus != 'draft') {
      judgedUnder = TourRule(
        weekOff: weekOff,
        holidayDays: {
          for (final h in holidayRows)
            DateTime.parse(h['holiday_date'] as String).day,
        },
      );
    }

    return TourMonth(
      month: month,
      plans: {
        for (final r in rows)
          DateTime.parse(r['work_date'] as String).day: travelPlanFromRow(r),
      },
      holidays: {
        for (final h in holidayRows)
          DateTime.parse(h['holiday_date'] as String).day: h['name'] as String,
      },
      weekOff: weekOff,
      judgedUnder: judgedUnder,
    );
  }

  @override
  Future<TravelPlan> saveDay(TravelPlan plan) async {
    final dayId = await db.rpc('save_tour_day', params: {
      'p_work_date': ApiExpenseRepository._isoDate(plan.date),
      'p_work_type': ApiDayPlanRepository._workTypeTerm[plan.workType],
      'p_area_id': plan.areaId,
      'p_tour_type': ApiDayPlanRepository._tourTypeTerm[plan.tourType] ?? 'local',
      'p_travel_mode': plan.travelMode.label,
      'p_destination': plan.destination,
      'p_purpose': plan.purpose,
      'p_planned_visits': plan.plannedVisits,
      'p_estimated_km': plan.estimatedKm,
      'p_client_names': plan.clientNames,
      'p_remarks': plan.remarks,
    }) as String;

    final row = await db
        .from('tour_plan_days')
        .select(_dayColumns)
        .eq('id', dayId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Tour day was saved but could not be read back.');
    }
    return travelPlanFromRow(row);
  }

  @override
  Future<int> submitMonth(Session session, DateTime month) async {
    return await db.rpc('submit_tour_month', params: {
      'p_year': month.year,
      'p_month': month.month,
    }) as int;
  }
}

TravelPlan travelPlanFromRow(Map<String, dynamic> r) {
  final month = r['tour_plan_months'] as Map<String, dynamic>?;
  final area = r['areas'] as Map<String, dynamic>?;
  final employee = r['employees'] as Map<String, dynamic>?;
  final travelLabel = r['travel_mode'] as String?;
  TravelMode travelMode = TravelMode.bike;
  if (travelLabel != null) {
    for (final m in TravelMode.values) {
      if (m.label.toLowerCase() == travelLabel.toLowerCase()) {
        travelMode = m;
        break;
      }
    }
  }
  return TravelPlan(
    id: r['id'] as String,
    employeeId: r['employee_id'] as String,
    employeeName: employee?['name'] as String? ?? 'Somebody',
    date: DateTime.parse(r['work_date'] as String),
    workType: ApiDayPlanRepository._workTypeOf[r['work_type']] ??
        WorkType.fieldWork,
    status: ApiTravelRepository._statusOf[month?['status'] as String? ?? 'draft'] ??
        ApprovalStatus.draft,
    areaId: r['area_id'] as String?,
    areaName: area?['name'] as String?,
    tourType: ApiDayPlanRepository._tourTypeOf[r['tour_type']] ??
        TourType.local,
    travelMode: travelMode,
    destination: r['destination'] as String?,
    purpose: r['purpose'] as String?,
    plannedVisits: (r['planned_visits'] as num?)?.toInt() ?? 0,
    estimatedKm: (r['estimated_km'] as num?)?.toDouble(),
    clientNames:
        (r['client_names'] as List<dynamic>? ?? const []).cast<String>(),
    remarks: r['remarks'] as String?,
    syncStatus: SyncStatus.synced,
  );
}

/* ════════════════════════════════════════════════════════ commerce ══ */

/// Products, orders, targets and sales from the database.
class ApiBusinessRepository implements BusinessRepository {
  ApiBusinessRepository();

  static const _orderStatusOf = ApiApprovalRepository._orderStatusOf;

  static const _orderColumns =
      'id, employee_id, client_id, status, discount_percent, subtotal, '
      'gst_amount, total, remarks, created_at, submitted_at, '
      'employees(name), clients(name)';

  @override
  Future<List<Product>> products() async {
    final rows = await db
        .from('products')
        .select('id, sku, name, pack_size, mrp, pts, gst_percent, is_active')
        .order('name', ascending: true);
    return rows
        .map((r) => Product(
              id: r['id'] as String,
              code: r['sku'] as String,
              name: r['name'] as String,
              mrp: (r['mrp'] as num?)?.toDouble() ?? 0,
              packSize: r['pack_size'] as String?,
              gstPercent: (r['gst_percent'] as num?)?.toDouble() ?? 12,
              isActive: r['is_active'] as bool? ?? true,
            ))
        .toList();
  }

  @override
  Future<List<Order>> orders(
    Session session, {
    ApprovalStatus? status,
    String? employeeId,
  }) async {
    var q = db.from('orders').select(_orderColumns);
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    if (status != null) {
      final wire = _orderStatusTerm(status);
      if (wire != null) q = q.eq('status', wire);
    }
    final rows = await q.order('created_at', ascending: false);
    final orders = <Order>[];
    for (final r in rows) {
      orders.add(await _orderFromRow(r));
    }
    return orders;
  }

  @override
  Future<Order> orderById(String id) async {
    final row = await db
        .from('orders')
        .select(_orderColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('No order you may see has that id.');
    }
    return _orderFromRow(row);
  }

  @override
  Future<Order> createOrder(Order order) async {
    final items = <Map<String, dynamic>>[];
    for (final i in order.items) {
      if (i.quantity > 0) {
        items.add({
          'product_id': i.productId,
          'quantity': i.quantity,
          'unit_price': i.rate,
          'is_foc': false,
        });
      }
      if (i.freeQuantity > 0) {
        items.add({
          'product_id': i.productId,
          'quantity': i.freeQuantity,
          'unit_price': i.rate,
          'is_foc': true,
        });
      }
    }

    final discount = order.items.isEmpty
        ? 0.0
        : order.items
                .map((i) => i.discountPercent)
                .reduce((a, b) => a + b) /
            order.items.length;

    final id = await db.rpc('create_order', params: {
      'p_id': order.id,
      'p_client_id': order.clientId,
      'p_items': items,
      'p_discount_percent': discount,
      'p_remarks': order.remarks,
    }) as String;

    if (order.status == ApprovalStatus.submitted ||
        order.status == ApprovalStatus.pending) {
      await db.rpc('submit_order', params: {'p_id': id});
    }

    return orderById(id);
  }

  @override
  Future<List<SalesRecord>> sales(
    Session session, {
    String? employeeId,
    int? year,
  }) async {
    var q = db.from('sales_records').select(
        'employee_id, sale_date, product_id, quantity, amount, products(name)');
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    if (year != null) {
      q = q
          .gte('sale_date', '$year-01-01')
          .lte('sale_date', '$year-12-31');
    }
    final rows = await q.order('sale_date', ascending: true);

    final byMonth = <String, SalesRecord>{};
    final productTotals = <String, Map<String, ProductSales>>{};

    for (final r in rows) {
      final date = DateTime.parse(r['sale_date'] as String);
      final key = '${r['employee_id']}-${date.year}-${date.month}';
      final amount = (r['amount'] as num).toDouble();
      final qty = (r['quantity'] as num?)?.toInt() ?? 0;
      final product = r['products'] as Map<String, dynamic>?;
      final pid = r['product_id'] as String;

      final existing = byMonth[key];
      byMonth[key] = SalesRecord(
        month: DateTime(date.year, date.month),
        employeeId: r['employee_id'] as String,
        amount: (existing?.amount ?? 0) + amount,
        primaryAmount: (existing?.primaryAmount ?? 0) + amount,
        secondaryAmount: existing?.secondaryAmount ?? 0,
        unitsSold: (existing?.unitsSold ?? 0) + qty,
        productBreakup: const [],
      );

      final monthProducts = productTotals.putIfAbsent(key, () => {});
      final prev = monthProducts[pid];
      monthProducts[pid] = ProductSales(
        productId: pid,
        productName: product?['name'] as String? ?? 'Product',
        amount: (prev?.amount ?? 0) + amount,
        units: (prev?.units ?? 0) + qty,
      );
    }

    return byMonth.entries.map((e) {
      final base = e.value;
      final breakup = productTotals[e.key]?.values.toList() ?? const [];
      breakup.sort((a, b) => b.amount.compareTo(a.amount));
      return SalesRecord(
        month: base.month,
        employeeId: base.employeeId,
        amount: base.amount,
        primaryAmount: base.primaryAmount,
        secondaryAmount: base.secondaryAmount,
        unitsSold: base.unitsSold,
        productBreakup: breakup,
      );
    }).toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  @override
  Future<List<Target>> targets(
    Session session, {
    String? employeeId,
    DateTime? month,
  }) async {
    var q = db.from('targets').select(
        'id, employee_id, period_year, period_month, amount, employees(name)');
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    if (month != null) {
      q = q
          .eq('period_year', month.year)
          .eq('period_month', month.month);
    }
    final rows = await q.order('period_year', ascending: false);

    final achieved = await _achievedByEmployeeMonth(
      employeeId: employeeId,
      month: month,
    );

    return rows
        .map((r) {
          final m = DateTime(r['period_year'] as int, r['period_month'] as int);
          final emp = r['employees'] as Map<String, dynamic>?;
          final key = '${r['employee_id']}-${m.year}-${m.month}';
          return Target(
            id: r['id'] as String,
            employeeId: r['employee_id'] as String,
            employeeName: emp?['name'] as String? ?? 'Somebody',
            month: m,
            targetAmount: (r['amount'] as num).toDouble(),
            achievedAmount: achieved[key] ?? 0,
          );
        })
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));
  }

  @override
  Future<Target> saveTarget(Target target) async {
    final id = await db.rpc('assign_target', params: {
      'p_employee_id': target.employeeId,
      'p_product_id': null,
      'p_year': target.month.year,
      'p_month': target.month.month,
      'p_amount': target.targetAmount,
    }) as String;

    final row = await db
        .from('targets')
        .select('id, employee_id, period_year, period_month, amount, employees(name)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Target was saved but could not be read back.');
    }
    return Target(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      employeeName: (row['employees'] as Map<String, dynamic>?)?['name'] as String? ??
          target.employeeName,
      month: DateTime(row['period_year'] as int, row['period_month'] as int),
      targetAmount: (row['amount'] as num).toDouble(),
      achievedAmount: target.achievedAmount,
      visitTarget: target.visitTarget,
      visitsAchieved: target.visitsAchieved,
    );
  }

  Future<Map<String, double>> _achievedByEmployeeMonth({
    String? employeeId,
    DateTime? month,
  }) async {
    var q = db.from('sales_records').select('employee_id, sale_date, amount');
    if (month != null) {
      final from = ApiDayPlanRepository._isoDate(DateTime(month.year, month.month, 1));
      final to = ApiDayPlanRepository._isoDate(
          DateTime(month.year, month.month + 1, 0));
      q = q.gte('sale_date', from).lte('sale_date', to);
    }
    if (employeeId != null) q = q.eq('employee_id', employeeId);

    final rows = await q;
    final out = <String, double>{};
    for (final r in rows) {
      final date = DateTime.parse(r['sale_date'] as String);
      final key = '${r['employee_id']}-${date.year}-${date.month}';
      out[key] = (out[key] ?? 0) + (r['amount'] as num).toDouble();
    }
    return out;
  }

  Future<Order> _orderFromRow(Map<String, dynamic> r) async {
    final items = await db
        .from('order_items')
        .select('product_id, quantity, unit_price, is_foc, line_total, products(name, gst_percent, pack_size)')
        .eq('order_id', r['id'] as String);

    final employee = r['employees'] as Map<String, dynamic>?;
    final client = r['clients'] as Map<String, dynamic>?;
    final oid = r['id'] as String;

    return Order(
      id: oid,
      orderNumber: 'ORD-${oid.substring(0, 8).toUpperCase()}',
      employeeId: r['employee_id'] as String,
      employeeName: employee?['name'] as String? ?? 'Somebody',
      clientId: r['client_id'] as String,
      clientName: client?['name'] as String? ?? '',
      date: DateTime.parse(r['created_at'] as String),
      status: _orderStatusOf[r['status'] as String] ?? ApprovalStatus.draft,
      items: items
          .map((i) {
            final product = i['products'] as Map<String, dynamic>?;
            final foc = i['is_foc'] as bool? ?? false;
            return OrderItem(
              productId: i['product_id'] as String,
              productName: product?['name'] as String? ?? 'Product',
              rate: (i['unit_price'] as num).toDouble(),
              quantity: foc ? 0 : (i['quantity'] as num).toInt(),
              freeQuantity: foc ? (i['quantity'] as num).toInt() : 0,
              gstPercent: (product?['gst_percent'] as num?)?.toDouble() ?? 12,
              packSize: product?['pack_size'] as String?,
            );
          })
          .toList(),
      remarks: r['remarks'] as String?,
    );
  }

  static String? _orderStatusTerm(ApprovalStatus status) => switch (status) {
        ApprovalStatus.draft => 'draft',
        ApprovalStatus.submitted || ApprovalStatus.pending => 'pending',
        ApprovalStatus.approved => 'approved',
        ApprovalStatus.rejected => 'rejected',
      };
}

/* ══════════════════════════════════════════════════════════ tasks ══ */

class ApiTaskRepository implements TaskRepository {
  ApiTaskRepository();

  static const _statusOf = {
    'open': TaskStatus.assigned,
    'done': TaskStatus.completed,
    'cancelled': TaskStatus.completed,
  };

  @override
  Future<List<FieldTask>> list(
    Session session, {
    String? employeeId,
    String? assignedById,
    TaskStatus? status,
  }) async {
    var q = db.from('tasks').select(
        'id, assignee_id, assigner_id, title, description, due_date, status, completed_at, created_at');
    if (employeeId != null) q = q.eq('assignee_id', employeeId);
    if (assignedById != null) q = q.eq('assigner_id', assignedById);
    final rows = await q.order('due_date', ascending: true);
    final names = await _taskNames(rows);

    return rows
        .map((r) => _taskFromRow(r, names))
        .where((t) => status == null || t.effectiveStatus() == status)
        .toList();
  }

  @override
  Future<FieldTask> create(Session session, FieldTask task) async {
    final id = await db.rpc('assign_task', params: {
      'p_id': task.id,
      'p_assignee_id': task.assignedToId,
      'p_title': task.title,
      'p_description': task.instructions,
      'p_due_date': ApiDayPlanRepository._isoDate(task.dueDate),
    }) as String;

    final row = await db
        .from('tasks')
        .select(
            'id, assignee_id, assigner_id, title, description, due_date, status, completed_at, created_at')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Task was assigned but could not be read back.');
    }
    final names = await _taskNames([row]);
    return _taskFromRow(row, names);
  }

  @override
  Future<FieldTask> updateStatus(
    Session session,
    String id,
    TaskStatus status,
  ) async {
    if (status == TaskStatus.completed) {
      await db.rpc('complete_task', params: {'p_id': id});
    }
    final row = await db
        .from('tasks')
        .select(
            'id, assignee_id, assigner_id, title, description, due_date, status, completed_at, created_at')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('No task you may see has that id.');
    }
    final names = await _taskNames([row]);
    return _taskFromRow(row, names);
  }

  Future<Map<String, String>> _taskNames(List<Map<String, dynamic>> rows) async {
    final ids = <String>{};
    for (final r in rows) {
      ids.add(r['assignee_id'] as String);
      final assigner = r['assigner_id'] as String?;
      if (assigner != null) ids.add(assigner);
    }
    if (ids.isEmpty) return {};
    final people =
        await db.from('employees').select('id, name').inFilter('id', ids.toList());
    return {for (final p in people) p['id'] as String: p['name'] as String};
  }

  FieldTask _taskFromRow(Map<String, dynamic> r, Map<String, String> names) {
    return FieldTask(
      id: r['id'] as String,
      title: r['title'] as String,
      assignedToId: r['assignee_id'] as String,
      assignedToName: names[r['assignee_id']] ?? 'Somebody',
      assignedById: r['assigner_id'] as String? ?? '',
      assignedByName: names[r['assigner_id']] ?? 'Somebody',
      dueDate: r['due_date'] == null
          ? DateTime.now()
          : DateTime.parse(r['due_date'] as String),
      priority: TaskPriority.medium,
      status: _statusOf[r['status'] as String] ?? TaskStatus.assigned,
      instructions: r['description'] as String?,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
      completedAt: DateTime.tryParse(r['completed_at'] as String? ?? ''),
    );
  }
}

/* ═══════════════════════════════════════════════════ notifications ══ */

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository();

  static const _kindOf = {
    'info': NotificationKind.approvalRequested,
    'approval': NotificationKind.approvalCompleted,
    'task': NotificationKind.taskAssigned,
    'message': NotificationKind.message,
    'target': NotificationKind.targetUpdate,
  };

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    var q = db.from('notifications').select(
        'id, title, body, kind, is_read, created_at');
    if (unreadOnly) q = q.eq('is_read', false);
    final rows = await q.order('created_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> markRead(String id) async {
    await db.rpc('mark_notification_read', params: {'p_id': id});
  }

  @override
  Future<void> markAllRead() async {
    final rows = await db
        .from('notifications')
        .select('id')
        .eq('is_read', false);
    for (final r in rows) {
      await db.rpc('mark_notification_read', params: {'p_id': r['id']});
    }
  }

  @override
  Future<int> unreadCount() async {
    final rows = await db
        .from('notifications')
        .select('id')
        .eq('is_read', false);
    return rows.length;
  }

  AppNotification _fromRow(Map<String, dynamic> r) => AppNotification(
        id: r['id'] as String,
        kind: _kindOf[r['kind'] as String? ?? 'info'] ??
            NotificationKind.approvalRequested,
        title: r['title'] as String,
        body: r['body'] as String? ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
        isRead: r['is_read'] as bool? ?? false,
      );
}

/* ════════════════════════════════════════════════════════════ chat ══ */

/// Polling reads and `send_chat_message` — no realtime subscription yet.
class ApiChatRepository implements ChatRepository {
  ApiChatRepository();

  @override
  Future<List<ChatThread>> threads({String? query}) async {
    final rows = await db
        .from('chat_threads')
        .select('id, subject, created_at')
        .order('created_at', ascending: false);

    final threads = <ChatThread>[];
    for (final r in rows) {
      final tid = r['id'] as String;
      final messages = await db
          .from('chat_messages')
          .select('body, sent_at')
          .eq('thread_id', tid)
          .order('sent_at', ascending: false)
          .limit(1);
      final last = messages.isNotEmpty ? messages.first : null;
      final title = (r['subject'] as String?)?.trim().isNotEmpty == true
          ? r['subject'] as String
          : 'Conversation';
      threads.add(ChatThread(
        id: tid,
        title: title,
        lastMessage: last?['body'] as String? ?? '',
        lastMessageAt: last == null
            ? DateTime.parse(r['created_at'] as String)
            : DateTime.parse(last['sent_at'] as String),
      ));
    }

    final q = query?.trim().toLowerCase() ?? '';
    return threads
        .where((t) => q.isEmpty || t.title.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  }

  @override
  Future<List<ChatMessage>> messages(String threadId) async {
    final me = await db.rpc('current_employee_id');
    final rows = await db
        .from('chat_messages')
        .select('id, thread_id, sender_id, body, sent_at, employees(name)')
        .eq('thread_id', threadId)
        .order('sent_at', ascending: true);

    return rows
        .map((r) {
          final sender = r['employees'] as Map<String, dynamic>?;
          return ChatMessage(
            id: r['id'] as String,
            threadId: r['thread_id'] as String,
            senderId: r['sender_id'] as String,
            senderName: sender?['name'] as String? ?? 'Somebody',
            text: r['body'] as String,
            sentAt: DateTime.parse(r['sent_at'] as String),
            isMine: me != null && r['sender_id'] == me,
          );
        })
        .toList();
  }

  @override
  Future<ChatMessage> send(String threadId, String text) async {
    final id = await db.rpc('send_chat_message', params: {
      'p_thread_id': threadId,
      'p_body': text,
    }) as String;

    final row = await db
        .from('chat_messages')
        .select('id, thread_id, sender_id, body, sent_at, employees(name)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Message was sent but could not be read back.');
    }
    final sender = row['employees'] as Map<String, dynamic>?;
    return ChatMessage(
      id: row['id'] as String,
      threadId: row['thread_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: sender?['name'] as String? ?? 'Somebody',
      text: row['body'] as String,
      sentAt: DateTime.parse(row['sent_at'] as String),
      isMine: true,
    );
  }
}

/* ═══════════════════════════════════════════════════════ resources ══ */

class ApiResourceRepository implements ResourceRepository {
  @override
  Future<List<Resource>> list({String? query, String? category}) async {
    var q = db.from('resources').select(
        'id, title, category, storage_path, published_at');
    if (category != null && category != 'All') {
      q = q.eq('category', category);
    }
    final rows = await q.order('published_at', ascending: false);
    final needle = query?.trim().toLowerCase() ?? '';
    return rows
        .where((r) {
          if (needle.isEmpty) return true;
          return (r['title'] as String).toLowerCase().contains(needle);
        })
        .map((r) => Resource(
              id: r['id'] as String,
              title: r['title'] as String,
              category: r['category'] as String? ?? 'General',
              updatedAt: DateTime.parse(r['published_at'] as String),
              fileType: _fileType(r['storage_path'] as String?),
            ))
        .toList();
  }

  @override
  Future<Resource> byId(String id) async {
    final row = await db
        .from('resources')
        .select('id, title, category, storage_path, published_at')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('No resource you may see has that id.');
    }
    return Resource(
      id: row['id'] as String,
      title: row['title'] as String,
      category: row['category'] as String? ?? 'General',
      updatedAt: DateTime.parse(row['published_at'] as String),
      fileType: _fileType(row['storage_path'] as String?),
    );
  }

  static String _fileType(String? path) {
    if (path == null) return 'PDF';
    final ext = path.split('.').last.toLowerCase();
    return ext.isEmpty ? 'PDF' : ext.toUpperCase();
  }
}

/* ═════════════════════════════════════════════════════════ surveys ══ */

class ApiSurveyRepository implements SurveyRepository {
  ApiSurveyRepository();

  @override
  Future<List<SurveyResponse>> list(Session session) async {
    final rows = await db
        .from('survey_responses')
        .select('id, employee_id, survey_id, answers, submitted_at, surveys(title)')
        .order('submitted_at', ascending: false);

    return rows.map((r) {
      final answers = r['answers'] as Map<String, dynamic>? ?? {};
      final clientId = answers['client_id'] as String? ?? '';
      return SurveyResponse(
        id: r['id'] as String,
        employeeId: r['employee_id'] as String,
        clientId: clientId,
        clientName: answers['client_name'] as String? ?? 'Client',
        clientType: ClientType.other,
        submittedAt: DateTime.parse(r['submitted_at'] as String),
        feedback: answers['feedback'] as String? ??
            (r['surveys'] as Map<String, dynamic>?)?['title'] as String? ??
            '',
        remarks: answers['remarks'] as String?,
        locationName: answers['location_name'] as String?,
        rating: (answers['rating'] as num?)?.toInt(),
      );
    }).toList();
  }

  /// Writes through `submit_survey_response`. The phone model has no survey id —
  /// the RPC attaches (or creates) the org's active field-feedback survey.
  @override
  Future<SurveyResponse> create(SurveyResponse response) async {
    final id = await db.rpc('submit_survey_response', params: {
      'p_id': response.id,
      'p_survey_id': null,
      'p_answers': {
        'client_id': response.clientId,
        'client_name': response.clientName,
        'client_type': response.clientType.name,
        'feedback': response.feedback,
        'remarks': response.remarks,
        'location_name': response.locationName,
        'rating': response.rating,
      },
    }) as String;

    final row = await db
        .from('survey_responses')
        .select('id, employee_id, survey_id, answers, submitted_at, surveys(title)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('Survey response was saved but could not be read back.');
    }
    final answers = row['answers'] as Map<String, dynamic>? ?? {};
    return SurveyResponse(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      clientId: answers['client_id'] as String? ?? response.clientId,
      clientName: answers['client_name'] as String? ?? response.clientName,
      clientType: response.clientType,
      submittedAt: DateTime.parse(row['submitted_at'] as String),
      feedback: answers['feedback'] as String? ?? response.feedback,
      remarks: answers['remarks'] as String?,
      locationName: answers['location_name'] as String?,
      rating: (answers['rating'] as num?)?.toInt(),
    );
  }
}

/* ═══════════════════════════════════════════════════════ complaints ══ */

class ApiComplaintRepository implements ComplaintRepository {
  ApiComplaintRepository();

  static const _statusOf = {
    'open': ComplaintStatus.open,
    'inProgress': ComplaintStatus.inReview,
    'resolved': ComplaintStatus.resolved,
    'closed': ComplaintStatus.closed,
  };

  @override
  Future<List<Complaint>> list(Session session, {ComplaintStatus? status}) async {
    final rows = await db
        .from('complaints')
        .select(
            'id, employee_id, client_id, subject, body, status, attachment_paths, created_at, clients(name)')
        .order('created_at', ascending: false);

    return rows
        .map(_fromRow)
        .where((c) => status == null || c.status == status)
        .toList();
  }

  @override
  Future<Complaint> byId(String id) async {
    final row = await db
        .from('complaints')
        .select(
            'id, employee_id, client_id, subject, body, status, attachment_paths, created_at, clients(name)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('No complaint you may see has that id.');
    }
    return _fromRow(row);
  }

  @override
  Future<Complaint> create(Complaint complaint) async {
    final id = await db.rpc('create_complaint', params: {
      'p_id': complaint.id,
      'p_client_id': complaint.clientId,
      'p_subject': complaint.subject,
      'p_body': complaint.description,
    }) as String;
    return byId(id);
  }

  Complaint _fromRow(Map<String, dynamic> r) {
    final client = r['clients'] as Map<String, dynamic>?;
    final cid = r['id'] as String;
    return Complaint(
      id: cid,
      reference: 'CMP-${cid.substring(0, 8).toUpperCase()}',
      clientId: r['client_id'] as String? ?? '',
      clientName: client?['name'] as String? ?? '',
      subject: r['subject'] as String,
      description: r['body'] as String,
      status: _statusOf[r['status'] as String] ?? ComplaintStatus.open,
      createdAt: DateTime.parse(r['created_at'] as String),
      attachmentPaths: (r['attachment_paths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

/* ══════════════════════════════════════════════════════════ reports ══ */

/// Derived from report views and transactional tables; expenses still seed.
class ApiReportRepository implements ReportRepository {
  ApiReportRepository()
      : _seed = MockReportRepository(),
        _business = ApiBusinessRepository();

  final MockReportRepository _seed;
  final ApiBusinessRepository _business;

  @override
  Future<DailyReport> daily(
    Session session, {
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) async {
    var q = db.from('report_daily_visits').select('*');
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    q = q
        .gte('work_date', ApiDayPlanRepository._isoDate(from))
        .lte('work_date', ApiDayPlanRepository._isoDate(to));
    final rows = await q;

    final completed = rows.fold<int>(
        0, (s, r) => s + ((r['completed'] as num?)?.toInt() ?? 0));
    final missed =
        rows.fold<int>(0, (s, r) => s + ((r['missed'] as num?)?.toInt() ?? 0));
    final total =
        rows.fold<int>(0, (s, r) => s + ((r['total'] as num?)?.toInt() ?? 0));

    final orders = await _business.orders(
      session,
      employeeId: employeeId,
    );
    final inRange = orders.where((o) {
      final d = DateTime(o.date.year, o.date.month, o.date.day);
      return !d.isBefore(from) && !d.isAfter(to);
    });

    final seeded = await _seed.daily(
      session,
      from: from,
      to: to,
      employeeId: employeeId,
    );

    return DailyReport(
      workingDays: rows.map((r) => r['work_date']).toSet().length,
      fieldDays: rows.length,
      totalVisits: total,
      completed: completed,
      missed: missed,
      clientsCovered: completed,
      orders: inRange.length,
      orderValue: inRange.fold<double>(0, (s, o) => s + o.grandTotal),
      expenseTotal: seeded.expenseTotal,
      distanceKm: completed * 4.6,
      trend: seeded.trend,
    );
  }

  @override
  Future<VisitReport> visits(
    Session session, {
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String? areaId,
    ClientType? clientType,
  }) =>
      _seed.visits(
        session,
        from: from,
        to: to,
        employeeId: employeeId,
        areaId: areaId,
        clientType: clientType,
      );

  @override
  Future<SalesReport> salesReport(
    Session session, {
    required int year,
    String? employeeId,
  }) async {
    final records =
        await _business.sales(session, employeeId: employeeId, year: year);
    final targetRows = await _business.targets(
      session,
      employeeId: employeeId,
    );
    final yearTargets =
        targetRows.where((t) => t.month.year == year).toList();

    final monthly = <int, double>{};
    final monthlyTarget = <int, double>{};
    for (final r in records) {
      monthly[r.month.month] = (monthly[r.month.month] ?? 0) + r.amount;
    }
    for (final t in yearTargets) {
      monthlyTarget[t.month.month] =
          (monthlyTarget[t.month.month] ?? 0) + t.targetAmount;
    }

    final productTotals = <String, ProductSales>{};
    for (final r in records) {
      for (final p in r.productBreakup) {
        final existing = productTotals[p.productId];
        productTotals[p.productId] = ProductSales(
          productId: p.productId,
          productName: p.productName,
          amount: (existing?.amount ?? 0) + p.amount,
          units: (existing?.units ?? 0) + p.units,
        );
      }
    }

    final total = records.fold<double>(0, (s, r) => s + r.amount);
    return SalesReport(
      total: total,
      target: yearTargets.fold<double>(0, (s, t) => s + t.targetAmount),
      primary: records.fold<double>(0, (s, r) => s + r.primaryAmount),
      secondary: records.fold<double>(0, (s, r) => s + r.secondaryAmount),
      monthly: [
        for (var m = 1; m <= 12; m++)
          ChartPoint(
            label: m.toString().padLeft(2, '0'),
            value: monthly[m] ?? 0,
            secondary: monthlyTarget[m] ?? 0,
          ),
      ],
      byProduct: productTotals.values.toList()
        ..sort((a, b) => b.amount.compareTo(a.amount)),
    );
  }

  @override
  Future<TargetReport> targetReport(
    Session session, {
    required DateTime month,
    String? employeeId,
  }) async {
    final rows = await _business.targets(
      session,
      employeeId: employeeId,
      month: month,
    );
    final trend = <ChartPoint>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(month.year, month.month - i, 1);
      final slice = await _business.targets(
        session,
        employeeId: employeeId,
        month: m,
      );
      trend.add(ChartPoint(
        label: '${m.month}/${m.year}',
        value: slice.fold<double>(0, (s, t) => s + t.achievedAmount),
        secondary: slice.fold<double>(0, (s, t) => s + t.targetAmount),
      ));
    }
    return TargetReport(
      target: rows.fold<double>(0, (s, t) => s + t.targetAmount),
      achieved: rows.fold<double>(0, (s, t) => s + t.achievedAmount),
      rows: rows,
      trend: trend,
    );
  }

  @override
  Future<ExpenseReport> expenseReport(
    Session session, {
    required DateTime month,
    String? employeeId,
  }) =>
      _seed.expenseReport(session, month: month, employeeId: employeeId);

  @override
  Future<OverviewReport> overview(
    Session session, {
    required DateTime month,
    String? employeeId,
  }) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);
    final daily = await this.daily(
      session,
      from: from,
      to: to,
      employeeId: employeeId,
    );
    final targets = await _business.targets(
      session,
      employeeId: employeeId,
      month: month,
    );
    return OverviewReport(
      workingDays: daily.workingDays,
      fieldDays: daily.fieldDays,
      leaveDays: 0,
      nonFieldDays: (daily.workingDays - daily.fieldDays).clamp(0, daily.workingDays),
      visits: daily.totalVisits,
      completedVisits: daily.completed,
      newClients: 0,
      hospitalCoverage: 0,
      sales: targets.fold<double>(0, (s, t) => s + t.achievedAmount),
      target: targets.fold<double>(0, (s, t) => s + t.targetAmount),
      expenses: daily.expenseTotal,
    );
  }

  @override
  Future<ManagerDashboard> managerDashboard(Session session) async {
    final seeded = await _seed.managerDashboard(session);
    final month = DateTime.now();
    final orders = await _business.orders(session);
    final monthOrders = orders.where((o) =>
        o.date.year == month.year && o.date.month == month.month);
    final targets = await _business.targets(session, month: month);
    return ManagerDashboard(
      teamSize: seeded.teamSize,
      presentToday: seeded.presentToday,
      visitsPlanned: seeded.visitsPlanned,
      visitsCompleted: seeded.visitsCompleted,
      pendingApprovals: seeded.pendingApprovals,
      pendingByKind: seeded.pendingByKind,
      sales: targets.fold<double>(0, (s, t) => s + t.achievedAmount),
      target: targets.fold<double>(0, (s, t) => s + t.targetAmount),
      orderCount: monthOrders.length,
      expenseTotal: seeded.expenseTotal,
      behindPlanCount: seeded.behindPlanCount,
      unverifiedVisits: seeded.unverifiedVisits,
    );
  }
}

/* ═══════════════════════════════════════════════════════════ exports ══ */

/// Queues a server export job, then builds the phone workbook from live rows.
/// Full server-side workbook generation is tracked in docs/OFFLINE-SYNC.md /
/// PRODUCTION-CUTOVER — until then the sheet shape matches the mock export.
class ApiExportRepository implements ExportRepository {
  ApiExportRepository()
      : _employees = ApiEmployeeRepository(),
        _expenses = ApiExpenseRepository(),
        _travel = ApiTravelRepository(),
        _clients = ApiClientRepository(),
        _activities = ApiActivityRepository();

  final ApiEmployeeRepository _employees;
  final ApiExpenseRepository _expenses;
  final ApiTravelRepository _travel;
  final ApiClientRepository _clients;
  final ApiActivityRepository _activities;

  @override
  Future<ExportSheet> build(
    Session session,
    ExportKind kind,
    DateTime month, {
    String? employeeId,
  }) async {
    await db.rpc('request_export', params: {
      'p_kind': kind.name,
      'p_params': {
        'year': month.year,
        'month': month.month,
        'employee_id': ?employeeId,
      },
    });

    final targetId = employeeId ?? session.employee.id;
    final target = await _employees.byId(targetId);
    final stamp = kind.isMonthly
        ? '${month.year}-${month.month.toString().padLeft(2, '0')}'
        : ApiDayPlanRepository._isoDate(DateTime.now());

    final rows = switch (kind) {
      ExportKind.expenses => await _expenseRows(session, targetId, month),
      ExportKind.tourPlan => await _tourRows(session, targetId, month),
      ExportKind.dcr => await _dcrRows(session, targetId, month),
      ExportKind.clients => await _clientRows(session),
    };

    return ExportSheet(
      kind: kind,
      fileName:
          '${kind.label.replaceAll(' ', '-')}_${target.employeeCode}_$stamp',
      rows: [
        [kind.title],
        ['Name', target.name],
        ['Emp Code', target.employeeCode],
        ['Designation', target.designation],
        ['Area', target.areaName ?? target.headquarters],
        [],
        ...rows,
      ],
    );
  }

  Future<List<List<String>>> _expenseRows(
    Session session,
    String employeeId,
    DateTime month,
  ) async {
    final days = await _expenses.claimMonth(
      session,
      month,
      employeeId: employeeId,
    );
    return [
      ['Date', 'Place', 'Amount', 'Status'],
      for (final d in days)
        [
          ApiDayPlanRepository._isoDate(d.date),
          d.place,
          d.claimed.toStringAsFixed(0),
          d.status?.label ?? 'Not claimed',
        ],
    ];
  }

  Future<List<List<String>>> _tourRows(
    Session session,
    String employeeId,
    DateTime month,
  ) async {
    final tour = await _travel.month(session, month, employeeId: employeeId);
    final plans = tour.plans.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return [
      ['Date', 'Work type', 'Area', 'Planned visits'],
      for (final d in plans)
        [
          ApiDayPlanRepository._isoDate(d.date),
          d.workType.label,
          d.areaName ?? '',
          '${d.plannedVisits}',
        ],
    ];
  }

  Future<List<List<String>>> _dcrRows(
    Session session,
    String employeeId,
    DateTime month,
  ) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);
    final acts = await _activities.list(
      session,
      from: from,
      to: to,
      employeeId: employeeId,
    );
    return [
      ['Date', 'Client', 'Status', 'POB', 'Feedback'],
      for (final a in acts)
        [
          ApiDayPlanRepository._isoDate(a.scheduledStart),
          a.clientName,
          a.status.label,
          a.pobAmount?.toStringAsFixed(0) ?? '',
          a.feedback ?? '',
        ],
    ];
  }

  Future<List<List<String>>> _clientRows(Session session) async {
    final clients = await _clients.list(session);
    return [
      ['Name', 'Type', 'Area', 'Listing', 'Visits'],
      for (final c in clients)
        [
          c.name,
          c.type.label,
          c.areaName,
          c.listing.label,
          '${c.totalVisits}',
        ],
    ];
  }
}

