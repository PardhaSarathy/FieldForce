import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/mock/mock_dataset.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// Demo data coverage.
///
/// This build is shown to clients, and the fastest way to make finished work
/// look broken is a screen that opens empty. These tests assert that every
/// module has something to show for every role — so a thin seed fails CI
/// instead of surfacing live in a demo.
void main() {
  _specialtyMasterData();

  final store = MockStore.instance;
  final seed = store.seed;

  Session sessionFor(String code) {
    final employee =
        seed.employees.firstWhere((e) => e.employeeCode == code);
    return Session(employee: employee, loginAt: DateTime(2026, 8, 26));
  }

  final reps = seed.employees.where((e) => e.role == UserRole.mr).toList();

  group('catalogue and reference data', () {
    test('enough products to make an order screen look real', () {
      expect(seed.products.length, greaterThanOrEqualTo(10));
    });

    test('resources span several categories', () {
      expect(seed.resources.length, greaterThanOrEqualTo(10));
      final categories = seed.resources.map((r) => r.category).toSet();
      expect(categories.length, greaterThanOrEqualTo(4));
    });

    test('a full year of holidays', () {
      expect(seed.holidays.length, greaterThanOrEqualTo(10));
    });

    test('a year of payslips', () {
      expect(seed.payslips.length, greaterThanOrEqualTo(12));
    });

    test('documents cover more than one category', () {
      expect(seed.documents.length, greaterThanOrEqualTo(8));
      expect(seed.documents.map((d) => d.category).toSet().length,
          greaterThanOrEqualTo(3));
    });

    test('every client type is represented', () {
      final types = seed.clients.map((c) => c.type).toSet();
      for (final type in [
        ClientType.doctor,
        ClientType.hospital,
        ClientType.chemist,
        ClientType.stockist,
      ]) {
        expect(types, contains(type), reason: '$type has no clients');
      }
    });
  });

  group('every rep has data in every module', () {
    for (final rep in reps) {
      test('${rep.employeeCode} — ${rep.name}', () async {
        final session = sessionFor(rep.employeeCode);

        final clients = await MockClientRepository().list(session);
        expect(clients, isNotEmpty, reason: 'client list would be empty');

        // Orders are raised against trade clients, so a rep with only doctors
        // cannot demonstrate the order flow at all.
        final tradeClients = clients
            .where((c) => c.type != ClientType.doctor)
            .toList();
        expect(tradeClients, isNotEmpty,
            reason: 'no chemist/hospital/stockist to raise an order against');

        final activities = await MockActivityRepository().list(session);
        expect(activities, isNotEmpty);

        final today = await MockActivityRepository()
            .daySummary(rep.id, seed.today);
        expect(today.planned, greaterThan(0),
            reason: 'Home would show an empty day');
        expect(today.completed, greaterThan(0),
            reason: 'Home progress bar would read zero');
        expect(today.nextAction, isNotNull,
            reason: 'Home would have no next action to show');

        final expenses = await MockExpenseRepository().list(session);
        expect(expenses, isNotEmpty);

        final travel = await MockTravelRepository().list(session);
        expect(travel, isNotEmpty);

        final leaves = await MockHrRepository().leaves(session);
        expect(leaves, isNotEmpty);

        final orders = await MockBusinessRepository().orders(session);
        expect(orders, isNotEmpty);

        final targets = await MockBusinessRepository()
            .targets(session, month: seed.today);
        expect(targets, isNotEmpty, reason: 'no target for the current month');

        final tasks = await MockTaskRepository().list(session);
        expect(tasks, isNotEmpty);

        final attendance =
            await MockHrRepository().attendance(rep.id, seed.today);
        expect(attendance, isNotEmpty);
      });
    }
  });

  group('every account type is demo-ready', () {
    // Screens like Expenses, Travel and Leave filter to the *signed-in user*,
    // not their scope — so a manager with no records of their own opens them
    // empty. These assertions cover each role's own data, which is exactly
    // what an earlier seed was missing.
    // Two roles, which is the whole matrix on the phone.
    for (final code in ['MR1001', 'ASM201']) {
      test('$code has personal records in every personal module', () async {
        final session = sessionFor(code);
        final id = session.employee.id;

        expect(await MockExpenseRepository().list(session, employeeId: id),
            isNotEmpty,
            reason: 'Expenses screen opens empty');
        expect(await MockTravelRepository().list(session, employeeId: id),
            isNotEmpty,
            reason: 'Travel screen opens empty');
        expect(await MockHrRepository().leaves(session, employeeId: id),
            isNotEmpty,
            reason: 'Leave screen opens empty');
        expect(await MockTaskRepository().list(session, employeeId: id),
            isNotEmpty,
            reason: 'Tasks screen opens empty');
      });

      test('$code has an attendance record without phantom absences',
          () async {
        final session = sessionFor(code);
        final attendance = await MockHrRepository()
            .attendance(session.employee.id, seed.today);

        expect(attendance, isNotEmpty);
        // Managers do not log visits, so deriving attendance from visits alone
        // painted their whole month red.
        expect(
          attendance.where((a) => a.status == AttendanceStatus.absent),
          isEmpty,
          reason: 'attendance calendar would be a wall of red',
        );
      });
    }

    test('field-facing managers have a day plan of their own', () async {
      for (final code in ['ASM201']) {
        final session = sessionFor(code);
        final day = await MockActivityRepository()
            .daySummary(session.employee.id, seed.today);

        expect(day.planned, greaterThan(0),
            reason: '$code has no joint calls scheduled');
        expect(day.nextAction, isNotNull);
      }
    });

    test("a manager's team is their own reports and nobody else", () async {
      // There is no administrator on the phone any more, and no layer above
      // an ASM — the office roles live on the web. What replaces the old
      // "the admin is nobody's team member" check is the stronger one: a
      // manager's team is exactly the people who report to them.
      final session = sessionFor('ASM201');
      final team = await MockEmployeeRepository().teamOf(session);

      expect(team, isNotEmpty, reason: 'a manager would open an empty screen');
      expect(
        team.every((e) => e.managerId == session.employee.id),
        isTrue,
        reason: 'somebody outside the reporting line is in the team list',
      );
      expect(
        team.any((e) => e.id == session.employee.id),
        isFalse,
        reason: 'a manager is not a member of their own team',
      );
    });

    test('a representative has no team at all', () async {
      final team = await MockEmployeeRepository().teamOf(sessionFor('MR1001'));
      expect(team, isEmpty,
          reason: 'a rep with a team would be a manager nobody appointed');
    });

    test('managers have approvals waiting and reps do not', () async {
      for (final code in ['ASM201']) {
        expect(await MockApprovalRepository().pending(sessionFor(code)),
            isNotEmpty,
            reason: '$code opens an empty approval centre');
      }
      expect(await MockApprovalRepository().pending(sessionFor('MR1001')),
          isEmpty,
          reason: 'a field rep should have nothing to approve');
    });
  });

  group('manager sees a populated world', () {
    final manager = sessionFor('ASM201');

    test('team, approvals and surveys are all non-empty', () async {
      final team = await MockEmployeeRepository().teamOf(manager);
      expect(team, isNotEmpty);

      final pending = await MockApprovalRepository().pending(manager);
      expect(pending, isNotEmpty,
          reason: 'approval centre would open empty');

      final decided = await MockApprovalRepository().decided(manager);
      expect(decided, isNotEmpty);

      final surveys = await MockSurveyRepository().list(manager);
      expect(surveys, isNotEmpty,
          reason: 'surveys are seeded for one rep only');
    });

    test('pending approvals cover more than one kind', () async {
      final pending = await MockApprovalRepository().pending(manager);
      final kinds = pending.map((p) => p.kind).toSet();
      expect(kinds.length, greaterThanOrEqualTo(3),
          reason: 'the approval filter chips would be mostly empty');
    });

    test('every team member reports a position for the map', () async {
      final team = await MockEmployeeRepository().teamOf(manager);
      final located =
          team.where((e) => e.lastKnownLatitude != null).toList();
      expect(located.length, team.length,
          reason: 'team map would show gaps');
    });
  });

  group('communication modules are not empty', () {
    test('every chat thread has message history', () async {
      final repo = MockChatRepository();
      final threads = await repo.threads();
      expect(threads, isNotEmpty);

      for (final thread in threads) {
        final messages = await repo.messages(thread.id);
        expect(messages, isNotEmpty,
            reason: 'thread "${thread.title}" opens empty');
      }
    });

    test('complaints span every status', () async {
      final complaints =
          await MockComplaintRepository().list(sessionFor('MR1001'));
      expect(complaints.length, greaterThanOrEqualTo(6));
      expect(complaints.map((c) => c.status).toSet().length,
          greaterThanOrEqualTo(3));
    });

    test('notifications include unread ones', () async {
      final repo = MockNotificationRepository();
      final all = await repo.list();
      expect(all.length, greaterThanOrEqualTo(10));
      expect(await repo.unreadCount(), greaterThan(0),
          reason: 'the bell badge would never show');
    });
  });

  group('expense and approval variety', () {
    test('expenses cover every category and status', () async {
      final expenses =
          await MockExpenseRepository().list(sessionFor('ASM201'));

      expect(expenses.map((e) => e.category).toSet().length,
          ExpenseCategory.values.length);

      final statuses = expenses.map((e) => e.status).toSet();
      for (final status in [
        ApprovalStatus.draft,
        ApprovalStatus.submitted,
        ApprovalStatus.approved,
        ApprovalStatus.rejected,
      ]) {
        expect(statuses, contains(status),
            reason: 'the "$status" filter chip would be empty');
      }
    });

    test('a rejected expense carries its reason', () async {
      final expenses =
          await MockExpenseRepository().list(sessionFor('ASM201'));
      final rejected = expenses
          .where((e) => e.status == ApprovalStatus.rejected)
          .toList();

      expect(rejected, isNotEmpty);
      final reasons = rejected.first.approvalHistory
          .where((e) => e.reason != null && e.reason!.isNotEmpty);
      expect(reasons, isNotEmpty,
          reason: 'rejection without a reason breaks the §66.4 rule');
    });
  });
}

/// Specialty is master data, not typed text.
///
/// Free text arrives as "Cardiologist", "cardiologist" and "Cardio" — the same
/// thing to a rep, three separate rows to every report that groups by
/// specialty. The list has to come from the repository so the client form and
/// the admin master-data screen cannot disagree about it.
void _specialtyMasterData() {
  group('specialty master data', () {
    test('the repository serves a sorted, de-duplicated list', () async {
      final specialties = await MockClientRepository().specialties();

      expect(specialties, isNotEmpty);
      expect(specialties.toSet().length, specialties.length,
          reason: 'a duplicate would appear twice in the picker');
      final sorted = List.of(specialties)..sort();
      expect(specialties, sorted, reason: 'the picker relies on the order');
    });

    test('it is long enough that the picker offers search', () {
      // DropdownField grows a search box past eight options; below that the
      // field would be a plain scroll and the promise of search would be a lie.
      expect(MockStore.specialties.length, greaterThan(8));
    });

    test('every specialty the seed uses is on the list', () {
      // Otherwise editing a seeded doctor would show a value the picker cannot
      // reproduce, and saving would silently drop it.
      final seeded = MockDataset.instance.clients
          .map((c) => c.specialty)
          .whereType<String>()
          .where((s) => s != 'Multi-speciality')
          .toSet();

      for (final s in seeded) {
        expect(MockStore.specialties, contains(s), reason: '$s is not offered');
      }
    });
  });
}
