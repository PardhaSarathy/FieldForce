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
    test('levels are strictly ordered from MR to admin', () {
      expect(UserRole.mr.level, lessThan(UserRole.asm.level));
      expect(UserRole.asm.level, lessThan(UserRole.rsm.level));
      expect(UserRole.rsm.level, lessThan(UserRole.zsm.level));
      expect(UserRole.zsm.level, lessThan(UserRole.nsm.level));
      expect(UserRole.nsm.level, lessThan(UserRole.admin.level));
    });

    test('identifies manager roles correctly', () {
      expect(UserRole.mr.isManager, isFalse);
      expect(UserRole.asm.isManager, isTrue);
      expect(UserRole.rsm.isManager, isTrue);
      expect(UserRole.nsm.isManager, isTrue);
      // Admin manages the system, not a sales team.
      expect(UserRole.admin.isManager, isFalse);
      expect(UserRole.admin.isAdmin, isTrue);
    });

    test('a role can only manage strictly lower roles', () {
      expect(UserRole.asm.canManage(UserRole.mr), isTrue);
      expect(UserRole.asm.canManage(UserRole.asm), isFalse);
      expect(UserRole.mr.canManage(UserRole.asm), isFalse);
      expect(UserRole.rsm.canManage(UserRole.asm), isTrue);
    });
  });

  group('DataScope.forRole', () {
    test('a field user sees only themselves', () {
      expect(DataScope.forRole(UserRole.mr), DataScope.self);
    });

    test('mid-level managers see their reporting subtree', () {
      expect(DataScope.forRole(UserRole.asm), DataScope.subtree);
      expect(DataScope.forRole(UserRole.rsm), DataScope.subtree);
      expect(DataScope.forRole(UserRole.zsm), DataScope.subtree);
    });

    test('national and admin roles see everything', () {
      expect(DataScope.forRole(UserRole.nsm), DataScope.global);
      expect(DataScope.forRole(UserRole.admin), DataScope.global);
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

    test('an ASM cannot see their own manager', () {
      final session = sessionFor('ASM201');
      final visible = store.visibleEmployeeIds(session);
      final rsm = store.seed.employees
          .firstWhere((e) => e.employeeCode == 'RSM301');

      expect(visible, isNot(contains(rsm.id)));
    });

    test('an RSM sees the whole subtree, including indirect reports', () {
      final rsmVisible = store.visibleEmployeeIds(sessionFor('RSM301'));
      final asmVisible = store.visibleEmployeeIds(sessionFor('ASM201'));

      // Everything the ASM can see, the RSM above them can see too.
      for (final id in asmVisible) {
        expect(rsmVisible, contains(id));
      }
      expect(rsmVisible.length, greaterThan(asmVisible.length));
    });

    test('an MR cannot see a peer MR', () {
      final mine = store.visibleEmployeeIds(sessionFor('MR1001'));
      final peer = store.seed.employees
          .firstWhere((e) => e.employeeCode == 'MR1002');

      expect(mine, isNot(contains(peer.id)));
    });

    test('admin sees every employee', () {
      final visible = store.visibleEmployeeIds(sessionFor('ADM001'));
      expect(visible, hasLength(store.seed.employees.length));
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
