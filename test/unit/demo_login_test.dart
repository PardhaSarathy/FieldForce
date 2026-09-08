import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/features/authentication/presentation/login_screen.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';

/// Every account offered on the login screen must actually sign in.
///
/// If one of them is not in the seed, or the seed's code differs by so much as
/// a character, the demo dead-ends on the login form in front of a client.
///
/// It reads `demoAccounts` **from the login screen** rather than restating the
/// list here. The old version kept its own copy, the two drifted the moment
/// the office roles were cut from the app, and the test that existed to catch
/// exactly that failed to *compile* instead of failing to pass — so three
/// rows that could never sign in shipped on the login screen and nothing said
/// a word. A test with its own copy of the thing it is checking is checking
/// its copy.
void main() {
  final store = MockStore.instance;

  /// What the panel actually renders.
  final offered = demoAccounts.map((a) => a.$1).toList();

  group('every demo account signs in', () {
    test('the panel offers both roles and no more', () {
      // Two mobile roles, deliberately. The office layers live on the web.
      expect(offered, ['MR1001', 'ASM201']);
    });

    for (final code in demoAccounts.map((a) => a.$1)) {
      test('$code authenticates', () async {
        final session = await MockAuthRepository()
            .login(employeeCode: code, password: 'demo1234');

        expect(session.employee.employeeCode, code);
        expect(session.employee.isActive, isTrue);
      });
    }

    test('every offered ID exists in the seed', () {
      final seeded = store.seed.employees.map((e) => e.employeeCode).toSet();
      for (final code in offered) {
        expect(seeded, contains(code),
            reason: 'the login screen offers $code but the seed has no such '
                'employee — the demo would dead-end on the login form');
      }
    });

    test('sign-in tolerates case and surrounding whitespace', () async {
      for (final code in offered) {
        final lower = await MockAuthRepository()
            .login(employeeCode: code.toLowerCase(), password: 'x');
        expect(lower.employee.employeeCode, code);

        final padded = await MockAuthRepository()
            .login(employeeCode: '  $code  ', password: 'x');
        expect(padded.employee.employeeCode, code);
      }
    });
  });

  group('sign-in rejects what it should', () {
    test('an unknown ID is refused, not silently matched', () async {
      // A trailing character must not fuzzy-match a real employee: signing a
      // user in as somebody else would be far worse than a failed login.
      await expectLater(
        MockAuthRepository().login(employeeCode: 'ASM201s', password: 'x'),
        throwsA(isA<AuthException>()),
      );
    });

    test('a role that no longer exists is refused', () async {
      // RSM, NSM and Administrator were removed from the app. Their codes must
      // not quietly resolve to somebody — these were live rows on the login
      // panel until the day this was written.
      for (final gone in ['RSM301', 'NSM401', 'ADM001']) {
        await expectLater(
          MockAuthRepository().login(employeeCode: gone, password: 'x'),
          throwsA(isA<AuthException>()),
          reason: '$gone is not an account any more',
        );
      }
    });

    test('an empty password is refused', () async {
      await expectLater(
        MockAuthRepository().login(employeeCode: 'ASM201', password: '  '),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('each role lands somewhere usable', () {
    test('a representative sees their own records and no further', () async {
      final session = await MockAuthRepository()
          .login(employeeCode: 'MR1001', password: 'x');

      expect(session.role, UserRole.mr);
      expect(session.isManager, isFalse);
      expect(session.scope, DataScope.self);
    });

    test('a manager sees a subtree, and it is not empty', () async {
      final session = await MockAuthRepository()
          .login(employeeCode: 'ASM201', password: 'x');

      expect(session.role, UserRole.asm);
      expect(session.isManager, isTrue);
      expect(session.scope, DataScope.subtree);

      final team = await MockEmployeeRepository().teamOf(session);
      expect(team, isNotEmpty,
          reason: 'a manager would open an empty team screen');
    });

    test('the two roles are the whole matrix', () {
      // Written down so that adding a third is a deliberate act with a test
      // to update, rather than something that drifts back in.
      expect(UserRole.values, [UserRole.mr, UserRole.asm]);
    });
  });
}
