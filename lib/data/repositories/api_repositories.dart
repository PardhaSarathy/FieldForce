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
  /// There are no passwords behind a real backend. The screen offers the code
  /// path when live, so this exists to say why rather than to fail obscurely.
  @override
  Future<Session> login({
    required String employeeCode,
    required String password,
  }) async {
    throw const AuthException(
      'This build signs in by email. Ask for a code instead of a password.',
    );
  }

  @override
  Future<void> requestSignInCode(String email) async {
    try {
      await db.auth.signInWithOtp(email: email.trim());
    } catch (e) {
      throw AuthException(_readable(e));
    }
  }

  @override
  Future<Session> signInWithCode({
    required String email,
    required String code,
  }) async {
    try {
      final res = await db.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: sb.OtpType.email,
      );
      if (res.session == null) {
        throw const AuthException('That code did not sign you in.');
      }
      return await _sessionForCurrentUser();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_readable(e));
    }
  }

  /// Turn a signed-in account into the person the app is about.
  ///
  /// Row-level security has already decided what comes back, so this asks for
  /// the account and receives its own row or nothing. "Nothing" is the shape a
  /// half-finished invitation takes — signed in, linked to nobody — and it
  /// must not read as "your data is missing".
  ///
  /// **The session carries the fixture's employee, not the database's.** The
  /// database's uuids are its own; every other repository in this app still
  /// keys on `emp-1`, and thousands of activities, clients and day plans point
  /// there. Handing the session a uuid would empty most of the app in exchange
  /// for connecting one screen. So the person is matched by employee code —
  /// the fixture keeps supplying identity, the database supplies the current
  /// values — and [uuidFor] remembers the other half for the calls that need
  /// it. When the remaining tables land this inverts; today it would be a
  /// trade that loses.
  Future<Session> _sessionForCurrentUser() async {
    final user = db.auth.currentUser;
    if (user == null) throw const AuthException('You are not signed in.');

    final account = await db
        .from('app_users')
        .select('employee_id, role, scope')
        .eq('user_id', user.id)
        .maybeSingle();

    if (account == null || account['employee_id'] == null) {
      throw AuthException(
        '${user.email} has signed in, but is not linked to anybody on the '
        'roster yet. An owner does that from the console.',
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

    final live = employeeFromRow(row);

    // The whole roster this account may read, not just themselves: a manager's
    // team list, their approval queue and every leave row they can act on are
    // all keyed by somebody else's uuid. Row-level security has already
    // decided which people that is.
    final roster = await db.from('employees').select('id, code');
    _uuidByCode
      ..clear()
      ..addEntries(roster.map((r) =>
          MapEntry(r['code'] as String, r['id'] as String)));
    _uuidByCode[live.employeeCode] = live.id;

    final seeded = MockDataset.instance.employees
        .where((e) => e.employeeCode == live.employeeCode)
        .firstOrNull;
    if (seeded == null) {
      throw AuthException(
        '${live.name} (${live.employeeCode}) is in the database but not in '
        'this build. It was seeded from a different world.',
      );
    }

    return Session(employee: seeded, loginAt: DateTime.now());
  }

  @override
  Future<void> logout() async => db.auth.signOut();

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
  Future<void> requestPasswordReset(String employeeCode) async =>
      requestSignInCode(employeeCode);

  @override
  Future<bool> verifyOtp({
    required String employeeCode,
    required String otp,
  }) async {
    await signInWithCode(email: employeeCode, code: otp);
    return true;
  }

  @override
  Future<void> resetPassword({
    required String employeeCode,
    required String password,
  }) async {
    throw const AuthException('This build has no passwords to reset.');
  }

  String _readable(Object e) {
    final s = e.toString();
    // Supabase wraps its message in a type name; the message is the useful
    // half and it is written to be read.
    final m = RegExp(r'message: ([^,)]+)').firstMatch(s);
    return m?.group(1) ?? s.replaceFirst(RegExp(r'^\w+Exception: '), '');
  }
}

/// The database's uuid for an employee code, learned at sign-in.
final Map<String, String> _uuidByCode = {};
String? uuidForCode(String code) => _uuidByCode[code];

/// The fixture id for a database uuid, and the other way round.
String? uuidForFixtureId(String fixtureId) {
  final e = MockDataset.instance.employees
      .where((x) => x.id == fixtureId)
      .firstOrNull;
  return e == null ? null : _uuidByCode[e.employeeCode];
}

String? fixtureIdForUuid(String uuid) {
  final code = _uuidByCode.entries
      .where((e) => e.value == uuid)
      .map((e) => e.key)
      .firstOrNull;
  if (code == null) return null;
  return MockDataset.instance.employees
      .where((e) => e.employeeCode == code)
      .firstOrNull
      ?.id;
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
    // The screen asks in fixture ids, because that is what every other screen
    // in this app speaks. The wire wants uuids.
    if (employeeId != null) {
      final uuid = uuidForFixtureId(employeeId);
      if (uuid == null) return const [];
      q = q.eq('employee_id', uuid);
    }
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
        .where((r) => fixtureIdForUuid(r['employee_id'] as String) != null)
        .map((r) => LeaveRequest(
              id: r['id'] as String,
              employeeId: fixtureIdForUuid(r['employee_id'] as String)!,
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
