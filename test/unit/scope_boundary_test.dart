import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/engagement.dart';
import 'package:pharmaconnect/shared/models/export.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// What one person may do to another person's records.
///
/// Every one of these was reachable before it was written. The screens were
/// right — the approval queue removed the caller's own records, the lists
/// scoped by employee, the pickers offered only the team — and none of that
/// protected anything, because the repository took whatever it was handed.
/// A list that filters correctly is no defence when the record next door is
/// one route parameter away.
void main() {
  final store = MockStore.instance;

  Session sessionFor(String code) => Session(
        employee: store.seed.employees.firstWhere((e) => e.employeeCode == code),
        loginAt: DateTime(2026, 9),
      );

  final rep = sessionFor('MR1001');
  final manager = sessionFor('ASM201');

  /// Somebody the rep cannot see, and the manager can.
  Employee teammate() => store.seed.employees.firstWhere(
        (e) =>
            e.id != rep.employee.id &&
            store.visibleEmployeeIds(manager).contains(e.id) &&
            e.id != manager.employee.id,
      );

  group('nobody decides on a record outside their scope', () {
    test('a rep cannot approve anything, however they got the item', () async {
      // A rep's approval queue is empty, so the screen could never show them
      // this. `_decide` took the item anyway: it was handed an `ApprovalItem`
      // and wrote the decision.
      final approvals = MockApprovalRepository();
      final item = (await approvals.pending(manager)).first;

      expect(
        () => approvals.approve(rep, item),
        throwsStateError,
        reason: 'a rep approving a colleague is money moving sideways',
      );
    });

    test('nobody approves their own record', () async {
      // `_project` removes the caller's own from the *list* and always did.
      // The rule now holds where the decision is written, which is the only
      // place it matters.
      final approvals = MockApprovalRepository();
      final own = ApprovalItem(
        id: 'ap-own',
        kind: ApprovalKind.expense,
        recordId: 'x',
        employeeId: manager.employee.id,
        employeeName: manager.employee.name,
        title: 'Daily allowance',
        submittedAt: DateTime(2026, 9),
        status: ApprovalStatus.submitted,
        date: DateTime(2026, 9),
      );

      expect(() => approvals.approve(manager, own), throwsStateError);
    });

    test('a manager still decides on their own team', () async {
      final approvals = MockApprovalRepository();
      final item = (await approvals.pending(manager)).first;
      await approvals.approve(manager, item, comment: 'fine');
      // No throw: the guard refuses strangers, not the job.
    });
  });

  group('a record is not readable just because you hold its id', () {
    test("a rep cannot open a colleague's call", () async {
      final other = store.activities
          .firstWhere((a) => a.employeeId != rep.employee.id);
      expect(
        () => MockActivityRepository().byId(rep, other.id),
        throwsStateError,
      );
    });

    test("a rep cannot open a colleague's claim", () async {
      final other =
          store.expenses.firstWhere((e) => e.employeeId != rep.employee.id);
      expect(
        () => MockExpenseRepository().byId(rep, other.id),
        throwsStateError,
      );
    });

    test('a manager can open their own rep\'s call', () async {
      final theirs = store.activities
          .firstWhere((a) => a.employeeId == teammate().id);
      final got = await MockActivityRepository().byId(manager, theirs.id);
      expect(got.id, theirs.id, reason: 'this is what a team list is for');
    });
  });

  group('only the owner rewrites a record', () {
    test('a rep cannot rewrite a colleague\'s claim', () async {
      // This one was live: a rep could set another rep's expense to ₹99,999.
      final other =
          store.expenses.firstWhere((e) => e.employeeId != rep.employee.id);
      expect(
        () => MockExpenseRepository().update(rep, other.copyWith(amount: 99999)),
        throwsStateError,
      );
    });

    test('a manager cannot rewrite a rep\'s claim either', () async {
      // Seeing it is the point of an approval queue; rewriting it is not.
      // Approve and reject are the two things they may do, and both leave an
      // append-only trail.
      final theirs =
          store.expenses.firstWhere((e) => e.employeeId == teammate().id);
      expect(
        () => MockExpenseRepository().update(manager, theirs.copyWith(amount: 1)),
        throwsStateError,
      );
    });

    test('the owner still corrects their own', () async {
      final mine =
          store.expenses.firstWhere((e) => e.employeeId == rep.employee.id);
      final saved =
          await MockExpenseRepository().update(rep, mine.copyWith(remarks: 'x'));
      expect(saved.remarks, 'x');
    });
  });

  group('a task belongs to the person it was given to', () {
    test('a rep cannot tick off a colleague\'s task', () async {
      final other =
          store.tasks.firstWhere((t) => t.assignedToId != rep.employee.id);
      expect(
        () => MockTaskRepository()
            .updateStatus(rep, other.id, TaskStatus.completed),
        throwsStateError,
      );
    });

    test('a manager cannot complete a task for their rep', () async {
      // That is the manager reporting the rep's progress on their behalf.
      final theirs =
          store.tasks.firstWhere((t) => t.assignedToId == teammate().id);
      expect(
        () => MockTaskRepository()
            .updateStatus(manager, theirs.id, TaskStatus.completed),
        throwsStateError,
      );
    });

    test('a manager cannot assign outside their own team', () async {
      // ASM201 could assign work to RSM301 — their own manager. A picker that
      // offers only the team is a picker, not a permission.
      final outside = store.seed.employees.firstWhere(
        (e) => !store.visibleEmployeeIds(manager).contains(e.id),
      );
      expect(
        () => MockTaskRepository().create(
          manager,
          FieldTask(
            id: 'probe',
            title: 'Outside the team',
            assignedToId: outside.id,
            assignedToName: outside.name,
            assignedById: manager.employee.id,
            assignedByName: manager.employee.name,
            dueDate: DateTime(2026, 9),
            priority: TaskPriority.medium,
            status: TaskStatus.assigned,
          ),
        ),
        throwsStateError,
      );
    });

    test('a manager still assigns to their own team', () async {
      final saved = await MockTaskRepository().create(
        manager,
        FieldTask(
          id: 'probe-ok',
          title: 'Cover Dadar on Friday',
          assignedToId: teammate().id,
          assignedToName: teammate().name,
          assignedById: manager.employee.id,
          assignedByName: manager.employee.name,
          dueDate: DateTime(2026, 9),
          priority: TaskPriority.medium,
          status: TaskStatus.assigned,
        ),
      );
      expect(saved.id, 'probe-ok');
    });
  });

  group('the export refuses what it cannot show', () {
    test('a rep cannot export their manager', () {
      expect(
        () => MockExportRepository().build(
          rep,
          ExportKind.expenses,
          DateTime(2026, 8),
          employeeId: manager.employee.id,
        ),
        throwsStateError,
      );
    });
  });
}
