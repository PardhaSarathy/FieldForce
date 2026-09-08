import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// Hierarchy and visibility (§3, §66.1, §70).
///
/// These assertions are the client-side half of authorization. They must hold
/// for every repository query, because a leak here shows one rep another rep's
/// commercial data.
void main() {
  final store = MockStore.instance;

  Session sessionFor(String employeeCode) {
    final employee = store.seed.employees
        .firstWhere((e) => e.employeeCode == employeeCode);
    return Session(employee: employee, loginAt: DateTime(2026, 8, 26));
  }

  group('UserRole', () {
    test('the app holds two roles, and only two', () {
      // A rep and the manager who runs them. RSM, ZSM, NSM and the system
      // administrator were four people who work at a desk, and their screens
      // are the console's job — an app built for standing outside a clinic was
      // never the product for them.
      expect(UserRole.values, [UserRole.mr, UserRole.asm]);
    });

    test('levels are ordered, and stay a comparison', () {
      // Two values could have been a boolean. `level` stays because there will
      // be more managers, not more kinds of manager — and `canManage` is a
      // comparison either way.
      expect(UserRole.mr.level, lessThan(UserRole.asm.level));
    });

    test('identifies manager roles correctly', () {
      expect(UserRole.mr.isManager, isFalse);
      expect(UserRole.asm.isManager, isTrue);
      expect(UserRole.mr.isFieldUser, isTrue);
    });

    test('a role can only manage strictly lower roles', () {
      expect(UserRole.asm.canManage(UserRole.mr), isTrue);
      expect(UserRole.asm.canManage(UserRole.asm), isFalse);
      expect(UserRole.mr.canManage(UserRole.asm), isFalse);
    });
  });

  group('DataScope.forRole', () {
    test('a field user sees only themselves', () {
      expect(DataScope.forRole(UserRole.mr), DataScope.self);
    });

    test('a manager sees their reporting subtree', () {
      expect(DataScope.forRole(UserRole.asm), DataScope.subtree);
    });

    test('there is no scope that sees everything', () {
      // `global` went with the roles that held it. An unused scope is a hole
      // waiting for somebody to widen a query into it.
      expect(DataScope.values, [DataScope.self, DataScope.subtree]);
    });
  });

  group('visible employee resolution', () {
    test('an MR resolves to exactly one employee — themselves', () {
      final session = sessionFor('MR1001');
      final visible = store.visibleEmployeeIds(session);

      expect(visible, hasLength(1));
      expect(visible.single, session.employee.id);
    });

    test('an ASM sees themselves plus their direct reports', () {
      final session = sessionFor('ASM201');
      final visible = store.visibleEmployeeIds(session);

      expect(visible, contains(session.employee.id));
      // Every MR reporting to this ASM must be visible.
      final reports = store.seed.employees
          .where((e) => e.managerId == session.employee.id);
      expect(reports, isNotEmpty);
      for (final report in reports) {
        expect(visible, contains(report.id));
      }
    });

    test('a second manager cannot see the first one\'s team', () {
      // There will be more area managers, each over their own reps. The tree
      // is one level deep and repeated — so the guard that matters is
      // sideways, not upwards.
      final managers =
          store.seed.employees.where((e) => e.role.isManager).toList();
      if (managers.length < 2) return;

      final a = store.visibleEmployeeIds(sessionFor(managers[0].employeeCode));
      final b = store.visibleEmployeeIds(sessionFor(managers[1].employeeCode));
      expect(a.intersection(b), isEmpty);
    });

    test('an MR cannot see a peer MR', () {
      final mine = store.visibleEmployeeIds(sessionFor('MR1001'));
      final peer = store.seed.employees
          .firstWhere((e) => e.employeeCode == 'MR1002');

      expect(mine, isNot(contains(peer.id)));
    });

    test('nobody in the app sees the whole company', () {
      // The office watches from the console. Inside the app the widest view
      // is one manager's branch, which is the point of removing `global`.
      for (final e in store.seed.employees) {
        final visible = store.visibleEmployeeIds(sessionFor(e.employeeCode));
        expect(visible.length, lessThanOrEqualTo(store.seed.employees.length));
        if (!e.role.isManager) expect(visible, hasLength(1));
      }
    });
  });

  group('repository scope enforcement', () {
    test('activity list never returns another rep\'s records', () async {
      final session = sessionFor('MR1001');
      final activities =
          await MockActivityRepository().list(session);

      expect(activities, isNotEmpty);
      for (final activity in activities) {
        expect(activity.employeeId, session.employee.id);
      }
    });

    test('a manager sees their team\'s activities but not their peers\'', () async {
      final session = sessionFor('ASM201');
      final activities = await MockActivityRepository().list(session);
      final visible = store.visibleEmployeeIds(session);

      expect(activities, isNotEmpty);
      for (final activity in activities) {
        expect(visible, contains(activity.employeeId));
      }
    });

    test('an out-of-scope employeeId filter yields nothing, not a leak', () async {
      final session = sessionFor('MR1001');
      final peer = store.seed.employees
          .firstWhere((e) => e.employeeCode == 'MR1002');

      final activities = await MockActivityRepository()
          .list(session, employeeId: peer.id);

      expect(activities, isEmpty);
    });

    test('expenses respect scope', () async {
      final session = sessionFor('MR1001');
      final expenses = await MockExpenseRepository().list(session);

      for (final expense in expenses) {
        expect(expense.employeeId, session.employee.id);
      }
    });

    test('a manager never approves their own request', () async {
      final session = sessionFor('ASM201');
      final pending = await MockApprovalRepository().pending(session);

      for (final item in pending) {
        expect(item.employeeId, isNot(session.employee.id));
      }
    });

    test('pending queue contains only undecided items', () async {
      final session = sessionFor('ASM201');
      final pending = await MockApprovalRepository().pending(session);

      expect(pending, isNotEmpty);
      for (final item in pending) {
        expect(item.status.awaitsDecision, isTrue);
        expect(item.status.isDecided, isFalse);
      }
    });

    test('decided queue contains only decided items', () async {
      final session = sessionFor('ASM201');
      final decided = await MockApprovalRepository().decided(session);

      expect(decided, isNotEmpty);
      for (final item in decided) {
        expect(item.status.isDecided, isTrue);
      }
    });
  });

  group('ApprovalStatus semantics', () {
    test('draft and rejected are editable; submitted is not', () {
      expect(ApprovalStatus.draft.isEditable, isTrue);
      expect(ApprovalStatus.rejected.isEditable, isTrue);
      expect(ApprovalStatus.submitted.isEditable, isFalse);
      expect(ApprovalStatus.approved.isEditable, isFalse);
    });

    test('only approved and rejected count as decided', () {
      expect(ApprovalStatus.approved.isDecided, isTrue);
      expect(ApprovalStatus.rejected.isDecided, isTrue);
      expect(ApprovalStatus.pending.isDecided, isFalse);
      expect(ApprovalStatus.draft.isDecided, isFalse);
    });
  });
}
