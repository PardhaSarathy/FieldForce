// The company's rules travel with the session.
//
// The geo-fence radius, the geo-fence policy and the figure above which a
// claim needs a bill are settings an owner saves in the console. They were
// literals in the app, so saving them changed nothing on any phone. They ride
// on [Session] now — and a session that drops them on the way through is the
// same bug in a new place, which is what the second test is for.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

void main() {
  final employee = MockStore.instance.seed.employees
      .firstWhere((e) => e.employeeCode == 'MR1001');

  group('company rules on the session', () {
    test('a fixture session keeps the defaults the demo was built on', () {
      final session = Session(employee: employee, loginAt: DateTime(2026, 9));

      expect(session.geoFencePolicy, GeoFencePolicy.warn);
      expect(session.geoFenceRadiusMeters, 50);
      // Not set: the rule stays what is left of the day's allowance.
      expect(session.billRequiredAbove, isNull);
    });

    test('choosing your own password does not drop them', () {
      final session = Session(
        employee: employee,
        loginAt: DateTime(2026, 9),
        mustChangePassword: true,
        disabledModules: const {'chat'},
        geoFencePolicy: GeoFencePolicy.strict,
        geoFenceRadiusMeters: 200,
        billRequiredAbove: 500,
      ).withOwnPassword();

      expect(session.mustChangePassword, isFalse);
      expect(session.disabledModules, {'chat'});
      expect(session.geoFencePolicy, GeoFencePolicy.strict);
      expect(session.geoFenceRadiusMeters, 200);
      expect(session.billRequiredAbove, 500);
    });
  });
}
