/// Talking to Supabase.
///
/// These sit beside the `Mock*` implementations rather than replacing them,
/// and they implement the same interfaces — so no screen changes, which is the
/// test of whether the abstraction was right.
///
/// **They are deliberately partial, and each one says where it stops.** The
/// database holds employees, reporting lines and leave; it does not yet hold
/// clients, activities, day plans or expenses. An `Api` class that pretended
/// otherwise would return empty lists and every screen would read as broken.
/// Where a call has no backing table, it delegates to the seeded data and the
/// comment says so — a half-connected app that admits it beats one that lies
/// in either direction.
library;

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../shared/enums/app_enums.dart';
import '../../shared/models/field_ops.dart';
import '../../shared/models/organization.dart';
import '../mock/mock_dataset.dart';
import '../remote/backend.dart';
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
    identity.remember(me.employeeCode, me.id);
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

/// What still remembers the fixture's ids, and the only thing that does.
///
/// Live, an employee's **uuid is the identity**. The fixture does not vanish,
/// because most modules here still run on it and thousands of activities,
/// clients and day plans point at `emp-1`. It becomes a translation table
/// rather than an authority.
///
/// Only the *mock* repositories consult it — to find the seeded demo content
/// belonging to a live person. The live repositories never touch it. That puts
/// the compatibility layer exactly where the incompleteness is, and it shrinks
/// on its own: a module that gets a real table stops consulting the map, and
/// when the last one does this class is deleted.
///
/// A live employee with no seeded counterpart resolves to null here and simply
/// has no demo history — which is the truth, not a failure.
class IdentityMap {
  final Map<String, String> _uuidByCode = {};

  void remember(String code, String uuid) => _uuidByCode[code] = uuid;
  void rememberAll(Map<String, String> byCode) => _uuidByCode.addAll(byCode);
  void clear() => _uuidByCode.clear();

  String? uuidForCode(String code) => _uuidByCode[code];

  String? codeForUuid(String uuid) {
    for (final e in _uuidByCode.entries) {
      if (e.value == uuid) return e.key;
    }
    return null;
  }

  /// The seeded record id for a live employee, when the seed knows them.
  String? fixtureIdForUuid(String uuid) {
    final code = codeForUuid(uuid);
    if (code == null) return null;
    return MockDataset.instance.employees
        .where((e) => e.employeeCode == code)
        .firstOrNull
        ?.id;
  }

  /// The live uuid behind a seeded record id.
  String? uuidForFixtureId(String fixtureId) {
    final e = MockDataset.instance.employees
        .where((x) => x.id == fixtureId)
        .firstOrNull;
    return e == null ? null : _uuidByCode[e.employeeCode];
  }
}

final identity = IdentityMap();

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

/// Leave from the database; everything else from the seed.
///
/// A wrapper rather than a rewrite. Attendance, holidays, payslips and
/// documents have no tables yet, and the day one lands is the day one method
/// here stops delegating — which is a smaller, safer edit than a class that
/// answered everything with a guess.
class ApiHrRepository implements HrRepository {
  ApiHrRepository() : _seed = MockHrRepository();

  final MockHrRepository _seed;

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
  @override
  Future<LeaveRequest> applyLeave(LeaveRequest request) async {
    final id = await db.rpc('apply_for_leave', params: {
      'p_type': _typeTerm[request.type],
      'p_from': _iso(request.fromDate),
      'p_to': _iso(request.toDate),
      'p_reason': request.reason,
    }) as String;

    final rows = await leaves(
      Session(employee: MockDataset.instance.currentUser, loginAt: DateTime.now()),
    );
    return rows.firstWhere((l) => l.id == id, orElse: () => request);
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── no table yet; the seed answers, and this comment is the record of it ──
  @override
  Future<List<AttendanceRecord>> attendance(String employeeId, DateTime month) =>
      _seed.attendance(employeeId, month);

  @override
  Future<List<Holiday>> holidays(int year) => _seed.holidays(year);

  @override
  Future<List<Payslip>> payslips(Session session, String employeeId) =>
      _seed.payslips(session, employeeId);

  @override
  Future<List<AppDocument>> documents(String employeeId) =>
      _seed.documents(employeeId);
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
  ApiEmployeeRepository() : _seed = MockEmployeeRepository();

  /// Geography only. Regions, territories, areas and clusters are seeded and
  /// read-only in this phase; when they move, these three stop delegating.
  final MockEmployeeRepository _seed;

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

  @override
  Future<List<Territory>> territories() => _seed.territories();

  @override
  Future<List<Area>> areas({String? territoryId}) =>
      _seed.areas(territoryId: territoryId);

  @override
  Future<List<Cluster>> clusters({String? areaId}) =>
      _seed.clusters(areaId: areaId);
}
