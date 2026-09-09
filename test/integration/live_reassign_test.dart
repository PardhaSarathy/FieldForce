/// Does a change made on the website reach an app that is already open?
///
/// The interesting case is not "sign in again and see the new team" — that is
/// obvious. It is whether a session that is *already running* picks the change
/// up, because that is what a rep holding their phone actually has.
///
/// Run it the same way as `live_identity_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pharmaconnect/data/remote/backend.dart';
import 'package:pharmaconnect/data/repositories/api_repositories.dart';

const devPassword = String.fromEnvironment('DEV_PASSWORD');

/// The website's own path: an admin's token calling `reassign_manager`.
/// Deliberately raw HTTP rather than the app's client — the point is that the
/// change comes from somewhere else entirely.
Future<void> websiteMoves(String employeeCode, String toManagerCode) async {
  final http = HttpClient();
  Future<Map<String, dynamic>> post(String path, Object body,
      {String? bearer}) async {
    final r = await http.postUrl(Uri.parse('$supabaseUrl$path'));
    r.headers.set('apikey', supabaseKey);
    r.headers.contentType = ContentType.json;
    if (bearer != null) r.headers.set('Authorization', 'Bearer $bearer');
    r.write(jsonEncode(body));
    final res = await r.close();
    final text = await res.transform(utf8.decoder).join();
    return text.isEmpty ? {} : (jsonDecode(text) as Map<String, dynamic>);
  }

  final auth = await post('/auth/v1/token?grant_type=password', {
    'email': 'dev.console@$orgSlug.mrsales.local',
    'password': devPassword,
  });
  final token = auth['access_token'] as String;

  Future<String> idOf(String code) async {
    final r = await http.getUrl(
        Uri.parse('$supabaseUrl/rest/v1/employees?select=id&code=eq.$code'));
    r.headers.set('apikey', supabaseKey);
    r.headers.set('Authorization', 'Bearer $token');
    final res = await r.close();
    final rows = jsonDecode(await res.transform(utf8.decoder).join()) as List;
    return rows.first['id'] as String;
  }

  final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  await post('/rest/v1/rpc/reassign_manager', {
    'p_employee_id': await idOf(employeeCode),
    'p_new_manager_id': await idOf(toManagerCode),
    'p_effective_from': today,
    'p_until': null,
    'p_reason': 'Integration test: does the phone notice?',
  }, bearer: token);
  http.close();
}

void main() {
  final configured = isLive && devPassword.isNotEmpty;

  test('a move made on the website reaches a session already signed in',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await initBackend();

    final auth = ApiAuthRepository();
    final employees = ApiEmployeeRepository();

    // The manager signs in. This is the app being opened.
    final session = await auth.login(employeeCode: 'ASM201', password: devPassword);
    final before = (await employees.teamOf(session)).map((e) => e.employeeCode).toList();
    expect(before, ['MR1001', 'MR1002', 'MR1003', 'MR1004']);

    // Somebody moves MR1004 away, on the website. The phone is not told.
    await websiteMoves('MR1004', 'ASM202');

    // The same session, no re-login, no new token: just the next read.
    final after = (await employees.teamOf(session)).map((e) => e.employeeCode).toList();
    expect(after, ['MR1001', 'MR1002', 'MR1003'],
        reason: 'the open session should see the move on its next read');

    // And their scope narrowed too — not just the team list.
    final visible = (await employees.visibleTo(session)).map((e) => e.employeeCode).toList();
    expect(visible, isNot(contains('MR1004')));

    // The new manager has them.
    await auth.logout();
    final kavya = await auth.login(employeeCode: 'ASM202', password: devPassword);
    expect((await employees.teamOf(kavya)).map((e) => e.employeeCode), contains('MR1004'));

    // Put it back, and prove the return is seen the same way.
    await websiteMoves('MR1004', 'ASM201');
    expect((await employees.teamOf(kavya)).map((e) => e.employeeCode),
        isNot(contains('MR1004')));

    await auth.logout();
    final ravi = await auth.login(employeeCode: 'ASM201', password: devPassword);
    expect((await employees.teamOf(ravi)).map((e) => e.employeeCode).toList(),
        ['MR1001', 'MR1002', 'MR1003', 'MR1004']);
  }, skip: configured ? false : 'set SUPABASE_URL/KEY and DEV_PASSWORD to run');

  test('but the rep\'s own session still names their old manager until it reloads',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await initBackend();

    final auth = ApiAuthRepository();
    final rep = await auth.login(employeeCode: 'MR1004', password: devPassword);
    final managerAtLogin = rep.employee.managerId;

    await websiteMoves('MR1004', 'ASM202');

    // `Session.employee` is built once, at sign-in. Nothing re-reads it, so the
    // object the screens are holding still carries the old manager. Their
    // *scope* moved immediately — this is only the copy in memory.
    expect(rep.employee.managerId, managerAtLogin,
        reason: 'the in-memory session is a snapshot, not a subscription');

    // Restoring the session re-reads it, which is what a restart does.
    final restored = await auth.restoreSession();
    expect(restored!.employee.managerId, isNot(managerAtLogin),
        reason: 'a reload should pick up the new manager');

    await websiteMoves('MR1004', 'ASM201');
    await auth.logout();
  }, skip: configured ? false : 'set SUPABASE_URL/KEY and DEV_PASSWORD to run');
}
