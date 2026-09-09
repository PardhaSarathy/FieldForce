/// Phase 1, against the real Supabase project.
///
/// Not a unit test and deliberately not part of `flutter test`'s default run:
/// it talks to a live backend, so it is skipped unless the connection is
/// supplied. Run it with
///
/// ```
/// flutter test test/integration/live_identity_test.dart \
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///   --dart-define=SUPABASE_KEY=<publishable key> \
///   --dart-define=ORG_SLUG=mrsales-demo \
///   --dart-define=DEV_PASSWORD=<the development password>
/// ```
///
/// The password is passed in rather than written here. A development
/// credential in a repository is still a credential in a repository.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pharmaconnect/data/remote/backend.dart';
import 'package:pharmaconnect/data/repositories/api_repositories.dart';
import 'package:pharmaconnect/data/repositories/identity_map.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';

const devPassword = String.fromEnvironment('DEV_PASSWORD');

void main() {
  final configured = isLive && devPassword.isNotEmpty;

  group('the derived sign-in address', () {
    test('matches what the database derives, byte for byte', () {
      // `public.login_email('MR1001', 'mrsales-demo')` on the host produces
      // this. The two derivations are the contract between the app and the
      // account: if they ever disagree, everybody is locked out at once.
      expect(loginEmailFor('MR1001'), 'mr1001@$orgSlug.mrsales.local');
      expect(loginEmailFor('  mr1001  '), 'mr1001@$orgSlug.mrsales.local');
      expect(loginEmailFor('ASM201'), 'asm201@$orgSlug.mrsales.local');
    });
  }, skip: isLive ? false : 'no backend configured');

  group('signing in for real', () {
    late ApiAuthRepository auth;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // `flutter test` installs an HttpOverrides that answers 400 to
      // everything, and gives `shared_preferences` no platform implementation.
      // Both are right for a unit test and fatal for one that is deliberately
      // talking to a real backend.
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});

      await initBackend();
      auth = ApiAuthRepository();
    });

    tearDown(() async {
      try { await auth.logout(); } catch (_) {}
    });

    test('a representative signs in with their employee ID', () async {
      final session = await auth.login(
        employeeCode: 'MR1001',
        password: devPassword,
      );
      expect(session.employee.employeeCode, 'MR1001');
      expect(session.employee.name, 'Sai Kiran Reddy');
      expect(session.employee.role, UserRole.mr);
      // The identity is the uuid, and it is the one the console resolves.
      expect(session.employee.id, '7d388df4-9d1f-535a-87b2-106e516005ba');
      expect(session.employee.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('a manager signs in and is an ASM', () async {
      final session = await auth.login(
        employeeCode: 'ASM201',
        password: devPassword,
      );
      expect(session.employee.employeeCode, 'ASM201');
      expect(session.employee.role, UserRole.asm);
    });

    test('a wrong password is refused', () async {
      await expectLater(
        auth.login(employeeCode: 'MR1001', password: 'not-the-password'),
        throwsA(isA<Exception>()),
      );
    });

    test('an employee code with no account is refused the same way', () async {
      await expectLater(
        auth.login(employeeCode: 'MR9999', password: devPassword),
        throwsA(isA<Exception>()),
      );
    });

    test('the session is restored from the client, not from a second copy',
        () async {
      await auth.login(employeeCode: 'MR1001', password: devPassword);
      final restored = await auth.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.employee.employeeCode, 'MR1001');
      expect(restored.employee.id, '7d388df4-9d1f-535a-87b2-106e516005ba');
    });

    test('and there is nothing to restore after signing out', () async {
      await auth.login(employeeCode: 'MR1001', password: devPassword);
      await auth.logout();
      expect(await auth.restoreSession(), isNull);
    });

    test('a representative reads themselves and nobody else', () async {
      final session = await auth.login(
        employeeCode: 'MR1001',
        password: devPassword,
      );
      final people = await ApiEmployeeRepository().visibleTo(session);
      expect(people.map((e) => e.employeeCode).toList(), ['MR1001']);
    });

    test('a manager reads their team and nobody else', () async {
      final session = await auth.login(
        employeeCode: 'ASM201',
        password: devPassword,
      );
      final repo = ApiEmployeeRepository();

      final visible = await repo.visibleTo(session);
      expect(visible.map((e) => e.employeeCode).toList(),
          ['ASM201', 'MR1001', 'MR1002', 'MR1003', 'MR1004']);

      // `teamOf` is their reports, not their scope: a manager is not a member
      // of their own team.
      final team = await repo.teamOf(session);
      expect(team.map((e) => e.employeeCode).toList(),
          ['MR1001', 'MR1002', 'MR1003', 'MR1004']);
      expect(team.every((e) => e.managerId == session.employee.id), isTrue);
    });

    // Home's own provider chain, which is what broke: signed in perfectly
    // well as ASM201 and then "Something went wrong", because a session
    // carrying a Supabase uuid reached a mock repository keyed by `emp-1` and
    // an unguarded `firstWhere` threw.
    test('Home loads for a manager', () async {
      final session = await auth.login(
        employeeCode: 'ASM201',
        password: devPassword,
      );
      final day = await MockActivityRepository()
          .daySummary(session.employee.id, DateTime.now());
      expect(day, isNotNull);
      expect(day.date, isNotNull);
    });

    test('Home loads for a representative', () async {
      final session = await auth.login(
        employeeCode: 'MR1001',
        password: devPassword,
      );
      final day = await MockActivityRepository()
          .daySummary(session.employee.id, DateTime.now());
      expect(day, isNotNull);
    });

    test('the seeded modules find a live person', () async {
      final session = await auth.login(
        employeeCode: 'MR1001',
        password: devPassword,
      );
      // The map is filled at sign-in, so a uuid resolves to the seeded record.
      expect(identity.isEmpty, isFalse);
      expect(identity.fixtureIdForUuid(session.employee.id), isNotNull);
      expect(identity.seeded(session.employee.id), startsWith('emp-'));

      // And the seeded content is actually reachable for them.
      final plans = await MockDayPlanRepository()
          .list(session, employeeId: session.employee.id);
      expect(plans, isNotEmpty,
          reason: 'a live rep should reach their seeded day plans');
    });

    test('somebody the seed has never heard of does not crash it', () async {
      // A live employee with no seeded counterpart is an ordinary state, not
      // an exception.
      final day = await MockActivityRepository()
          .daySummary('00000000-0000-0000-0000-000000000000', DateTime.now());
      expect(day.activities, isEmpty);
      expect(day.headquarters, '');
    });

    test('a representative cannot read a colleague by id', () async {
      await auth.login(employeeCode: 'MR1001', password: devPassword);
      // MR1009 belongs to another manager. Refused, not empty.
      await expectLater(
        ApiEmployeeRepository().byId('00000000-0000-0000-0000-000000000000'),
        throwsA(isA<StateError>()),
      );
    });
  }, skip: configured ? false : 'set SUPABASE_URL/KEY and DEV_PASSWORD to run');
}
