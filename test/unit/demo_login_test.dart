import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';

/// Every account offered on the login screen must actually sign in.
///
/// The demo panel lists five IDs; if one of them is not in the seed, or the
/// seed's code differs by so much as a character, the demo dead-ends on the
/// login form in front of a client. This pins the panel to the seed.
void main() {
  final store = MockStore.instance;

  /// The exact list rendered by `_DemoAccountsHint` on the login screen.
  const demoAccounts = <String, UserRole>{
    'MR1001': UserRole.mr,
    'ASM201': UserRole.asm,
    'RSM301': UserRole.rsm,
    'NSM401': UserRole.nsm,
    'ADM001': UserRole.admin,
  };

  group('every demo account signs in', () {
    for (final entry in demoAccounts.entries) {
      test('${entry.key} authenticates as ${entry.value.shortLabel}',
          () async {
        final session = await MockAuthRepository()
            .login(employeeCode: entry.key, password: 'demo1234');

        expect(session.employee.employeeCode, entry.key);
        expect(session.role, entry.value);
        expect(session.employee.isActive, isTrue);
      });
    }

    test('every demo ID exists in the seed', () {
      final seeded =
          store.seed.employees.map((e) => e.employeeCode).toSet();
      for (final code in demoAccounts.keys) {
        expect(seeded, contains(code),
            reason: 'the login screen offers $code but the seed has no such '
                'employee — the demo would dead-end on the login form');
      }
    });

    test('sign-in tolerates case and surrounding whitespace', () async {
      for (final code in demoAccounts.keys) {
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
        MockAuthRepository().login(employeeCode: 'NSM401s', password: 'x'),
        throwsA(isA<AuthException>()),
      );
    });

    test('an empty password is refused', () async {
      await expectLater(
        MockAuthRepository().login(employeeCode: 'NSM401', password: '  '),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('each role lands somewhere usable', () {
    test('managers resolve to a subtree or global scope', () async {
      for (final code in ['ASM201', 'RSM301', 'NSM401']) {
        final session =
            await MockAuthRepository().login(employeeCode: code, password: 'x');
        expect(session.isManager, isTrue);
        expect(session.scope, isNot(DataScope.self));
      }
    });

    test('the national manager sees the whole organisation', () async {
      final session = await MockAuthRepository()
          .login(employeeCode: 'NSM401', password: 'x');

      expect(session.scope, DataScope.global);
      expect(session.isManager, isTrue);
      expect(session.isAdmin, isFalse);

      final team = await MockEmployeeRepository().teamOf(session);
      expect(team, isNotEmpty, reason: 'NSM would open an empty team screen');
    });

    test('the administrator is an admin, not a sales manager', () async {
      final session = await MockAuthRepository()
          .login(employeeCode: 'ADM001', password: 'x');

      expect(session.isAdmin, isTrue);
      expect(session.isManager, isFalse);
      expect(session.scope, DataScope.global);
    });
  });
}
