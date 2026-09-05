import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/field_ops.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// The rules a claim has to obey, none of which a render test can see.
void main() {
  Expense claim(double amount, {ApprovalStatus? status}) => Expense(
        id: 'e-$amount-${status?.name}',
        employeeId: 'emp-1',
        employeeName: 'Rahul',
        date: DateTime(2026, 9, 3),
        categories: const [ExpenseCategory.dailyAllowance],
        amount: amount,
        status: status ?? ApprovalStatus.draft,
        allowance: 250,
      );

  ClaimDay day(List<Expense> expenses, {WorkType type = WorkType.fieldWork}) =>
      ClaimDay(
        date: DateTime(2026, 9, 3),
        dayPlanId: 'dp-1',
        workType: type,
        place: 'Hyderabad',
        allowance: ClaimDay.isClaimable(type) ? 250 : 0,
        kind: switch (type) {
          WorkType.leave => DayKind.leave,
          WorkType.holiday => DayKind.holiday,
          _ => DayKind.worked,
        },
        expenses: expenses,
      );

  group('the allowance is per day, not per line', () {
    test('a fully claimed day has nothing left', () {
      expect(day([claim(250)]).remainingAllowance, 0);
    });

    test('a second line cannot re-spend the same allowance', () {
      // The hole this closes: measured against the *full* allowance, a rep
      // could file ₹250 twice — each line at the allowance, each needing no
      // bill — and take ₹500 for a ₹250 day.
      final d = day([claim(250)]);
      const second = 250.0;
      expect(second - d.remainingAllowance, 250,
          reason: 'the whole of a second ₹250 is excess and needs a bill');
    });

    test('a part-claimed day leaves the remainder', () {
      expect(day([claim(100)]).remainingAllowance, 150);
    });

    test('an excess day leaves nothing, never a negative', () {
      expect(day([claim(1450)]).remainingAllowance, 0);
    });
  });

  group('the day shows the news the rep has to act on', () {
    test('a rejected line beats an approved one', () {
      final d = day([
        claim(250, status: ApprovalStatus.approved),
        claim(600, status: ApprovalStatus.rejected),
      ]);
      expect(d.status, ApprovalStatus.rejected);
    });

    test('a draft beats a submitted one — it is the one still in his hands',
        () {
      final d = day([
        claim(250, status: ApprovalStatus.submitted),
        claim(100, status: ApprovalStatus.draft),
      ]);
      expect(d.status, ApprovalStatus.draft);
    });

    test('all approved reads as approved', () {
      final d = day([claim(250, status: ApprovalStatus.approved)]);
      expect(d.status, ApprovalStatus.approved);
    });

    test('an unclaimed day has no status at all', () {
      expect(day(const []).status, isNull);
    });
  });

  group('no worked day, no claim', () {
    test('leave and holidays are not claimable', () {
      expect(ClaimDay.isClaimable(WorkType.leave), isFalse);
      expect(ClaimDay.isClaimable(WorkType.holiday), isFalse);
      expect(day(const [], type: WorkType.leave).isOpen, isFalse);
    });

    test('every declared working type is', () {
      for (final t in [
        WorkType.fieldWork,
        WorkType.officeWork,
        WorkType.meeting,
        WorkType.training,
      ]) {
        expect(ClaimDay.isClaimable(t), isTrue, reason: t.label);
      }
    });
  });

  group('confirming cannot pay a day twice', () {
    test('a repeated confirm adds nothing the second time', () async {
      final repo = MockExpenseRepository();
      final store = MockStore.instance;
      final employee =
          store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
      final session = Session(employee: employee, loginAt: DateTime(2026, 9));

      final now = DateTime.now();
      final days = await repo.claimMonth(session, DateTime(now.year, now.month));
      final open = days.where((d) => d.isOpen).toList();
      if (open.isEmpty) return; // nothing open in the seeded month

      final first = await repo.confirmStandardDays(session, open);
      expect(first, open.length);

      // The same stale list again — exactly what a second tap sends, and the
      // button is the sort a rep taps twice when unsure it worked.
      final second = await repo.confirmStandardDays(session, open);
      expect(second, 0, reason: 'a day already claimed must be skipped');
    });
  });

  group('a month is read from everything that knows about it', () {
    // The claim used to be a list of the days a rep had filed a day plan for.
    // A Sunday, a company holiday, a week of approved leave and a day he
    // simply forgot to intimate were indistinguishable: none of them were on
    // the screen. Only the last of those is money he has lost.
    late List<ClaimDay> days;
    late DateTime month;

    setUpAll(() async {
      final store = MockStore.instance;
      final employee =
          store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
      final session = Session(employee: employee, loginAt: DateTime(2026, 9));
      // The month before this one: complete, so every weekday shape is in it
      // — Sundays, holidays and any leave — and none of it is still running.
      final today = store.seed.today;
      month = DateTime(today.year, today.month - 1);
      days = await MockExpenseRepository().claimMonth(session, month);
    });

    ClaimDay on(int d) => days.firstWhere((x) => x.date.day == d);

    test('a finished month comes back whole, not just its intimated days', () {
      final last = DateTime(month.year, month.month + 1, 0).day;
      expect(days.map((d) => d.date.day), List.generate(last, (i) => i + 1),
          reason: 'a month is a month, not the subset that was intimated');
    });

    test('today is never listed as a day the rep missed', () async {
      // It has no day plan because he has not filed one *yet*. Telling him at
      // nine in the morning that the day is lost is the same mistake as
      // painting a rep at 40% of target in error red.
      final store = MockStore.instance;
      final employee =
          store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
      final session = Session(employee: employee, loginAt: DateTime(2026, 9));
      final today = store.seed.today;

      final thisMonth = await MockExpenseRepository()
          .claimMonth(session, DateTime(today.year, today.month));

      expect(thisMonth.every((d) => !d.date.isAfter(today)), isTrue,
          reason: 'a day that has not happened cannot have been worked');
      final todayRow =
          thisMonth.where((d) => d.date.day == today.day).firstOrNull;
      expect(todayRow == null || todayRow.kind != DayKind.notDeclared, isTrue);
    });

    test('Sunday comes back as the week off, and earns nothing', () {
      final sundays = days.where(
        (d) => d.date.weekday == DateTime.sunday && d.dayPlanId == null,
      );
      expect(sundays, isNotEmpty, reason: 'a month has Sundays in it');
      for (final d in sundays) {
        expect(d.kind, DayKind.weekOff);
        expect(d.claimable, isFalse);
        expect(d.allowance, 0);
        expect(d.isOpen, isFalse, reason: 'it must never hold the month back');
      }
    });

    test('a company holiday comes back named', () {
      final holiday = MockStore.instance.seed.holidays
          .where((h) => h.date.year == month.year && h.date.month == month.month)
          .firstOrNull;
      if (holiday == null) return;

      final d = on(holiday.date.day);
      // Unless the rep declared a day plan on it — working a holiday is
      // allowed and the declaration wins.
      if (d.dayPlanId != null) return;
      expect(d.kind, DayKind.holiday);
      expect(d.note, holiday.name,
          reason: 'the row has to say which holiday it was');
      expect(d.claimable, isFalse);
    });

    test('approved leave reaches the claim without being re-entered', () {
      final store = MockStore.instance;
      final employee =
          store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
      final leave = store.leaves
          .where((l) =>
              l.employeeId == employee.id &&
              l.status == ApprovalStatus.approved &&
              l.fromDate.year == month.year &&
              l.fromDate.month == month.month)
          .firstOrNull;
      if (leave == null) return;

      final d = on(leave.fromDate.day);
      if (d.dayPlanId != null) return; // declared work wins
      expect(d.claimable, isFalse,
          reason: 'HR approved it; the rep should not have to say so again');
      expect(d.kind, anyOf(DayKind.leave, DayKind.holiday, DayKind.weekOff));
    });

    test('a working day with no intimation is shown, not hidden', () {
      // The one case that costs money. It must be findable on the calendar
      // and say what happened, rather than being a gap in a list.
      final missed = days.where((d) => d.kind == DayKind.notDeclared);
      for (final d in missed) {
        expect(d.claimable, isFalse);
        expect(d.dayPlanId, isNull);
        expect(d.date.weekday, isNot(DateTime.sunday));
      }
    });

    test('nothing unclaimable can hold the month back', () {
      for (final d in days) {
        if (d.claimable) continue;
        expect(d.isOpen, isFalse, reason: '${d.date} is ${d.kind}');
      }
    });

    test('the calls on a day come from the activities, not from the plan', () {
      final store = MockStore.instance;
      final employee =
          store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
      for (final d in days) {
        final actual = store.activities
            .where((a) =>
                a.employeeId == employee.id &&
                a.status == ActivityStatus.completed &&
                a.scheduledStart.year == d.date.year &&
                a.scheduledStart.month == d.date.month &&
                a.scheduledStart.day == d.date.day)
            .length;
        expect(d.calls, actual, reason: '${d.date}');
      }
    });
  });

  group('the month goes in one piece', () {
    ClaimDay day({required int date, bool claimed = true, ApprovalStatus s =
        ApprovalStatus.draft}) {
      return ClaimDay(
        date: DateTime(2026, 8, date),
        dayPlanId: 'dp$date',
        workType: WorkType.fieldWork,
        place: 'Dadar',
        allowance: 250,
        kind: DayKind.worked,
        expenses: claimed
            ? [
                Expense(
                  id: 'e$date',
                  employeeId: 'MR1001',
                  employeeName: 'Rep',
                  date: DateTime(2026, 8, date),
                  amount: 250,
                  status: s,
                  allowance: 250,
                  dayPlanId: 'dp$date',
                ),
              ]
            : const [],
      );
    }

    test('a month still running cannot be sent, however tidy it is', () {
      // Every declared day answered, on the 20th — and it still cannot go,
      // because the ten days after it have not happened yet. This is the whole
      // difference from the old behaviour, which sent whatever was ready.
      final gate = claimGate(
        days: [day(date: 3), day(date: 4)],
        month: DateTime(2026, 8),
        now: DateTime(2026, 8, 20),
      );
      expect(gate, ClaimGate.monthRunning);
    });

    test('an unanswered day holds the month back once it has ended', () {
      final gate = claimGate(
        days: [day(date: 3), day(date: 4, claimed: false)],
        month: DateTime(2026, 8),
        now: DateTime(2026, 9, 1),
      );
      expect(gate, ClaimGate.daysOpen);
    });

    test('a finished, fully answered month is ready on the 1st', () {
      final gate = claimGate(
        days: [day(date: 3), day(date: 4)],
        month: DateTime(2026, 8),
        now: DateTime(2026, 9, 1),
      );
      expect(gate, ClaimGate.ready);
    });

    test('leave does not hold a month back — it was never claimable', () {
      final leave = ClaimDay(
        date: DateTime(2026, 8, 5),
        dayPlanId: 'dp5',
        workType: WorkType.leave,
        place: '-',
        allowance: 0,
        kind: DayKind.leave,
      );
      expect(
        claimGate(
          days: [day(date: 3), leave],
          month: DateTime(2026, 8),
          now: DateTime(2026, 9, 1),
        ),
        ClaimGate.ready,
      );
    });

    test('nothing in draft means no bar at all', () {
      expect(
        claimGate(
          days: [day(date: 3, s: ApprovalStatus.submitted)],
          month: DateTime(2026, 8),
          now: DateTime(2026, 9, 1),
        ),
        ClaimGate.nothingToSend,
      );
    });

    test('the repository refuses a month the screen would have let through',
        () async {
      // The button works from a snapshot taken when the screen loaded. A rep
      // who opened the claim at 23:58 on the 31st and tapped at 00:01 would
      // have sent a month the gate had since re-opened — and the reverse, a
      // month that gained an unanswered day while the screen sat open.
      final repo = MockExpenseRepository();
      final store = MockStore.instance;
      final employee =
          store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
      final session = Session(employee: employee, loginAt: DateTime(2026, 9));

      final now = DateTime.now();
      final month = DateTime(now.year, now.month);
      final days = await repo.claimMonth(session, month);
      final open = days.where((d) => d.isOpen).toList();
      if (open.isEmpty) return;

      await repo.confirmStandardDays(session, open);
      final sent = await repo.submitMonth(session, month);
      expect(sent, 0, reason: 'this month has not ended');
    });
  });
}
