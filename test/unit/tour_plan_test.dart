import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/field_ops.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// The rules a month of tour plan obeys, none of which a render test can see.
void main() {
  final store = MockStore.instance;
  final employee =
      store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
  final session = Session(employee: employee, loginAt: DateTime(2026, 9));

  // Far enough out that the seed has planned none of it.
  final month = DateTime(2031, 3);

  TravelPlan day(int d, WorkType type, {String? areaId}) => TravelPlan(
        id: 'probe-$d',
        employeeId: employee.id,
        employeeName: employee.name,
        date: DateTime(month.year, month.month, d),
        workType: type,
        status: ApprovalStatus.draft,
        areaId: areaId,
        areaName: areaId == null ? null : 'Bandra',
      );

  group('a day can be changed until the month goes', () {
    test('saving the same date twice replaces it, it does not fork', () async {
      final repo = MockTravelRepository();

      // 1 March is leave...
      await repo.saveDay(day(1, WorkType.leave));
      var tour = await repo.month(session, month);
      expect(tour.planFor(1)!.workType, WorkType.leave);
      expect(tour.plans.length, 1);

      // ...the rep plans other days...
      await repo.saveDay(day(2, WorkType.fieldWork, areaId: 'ar-1'));

      // ...then comes back and changes 1 March to field work.
      await repo.saveDay(day(1, WorkType.fieldWork, areaId: 'ar-1'));

      tour = await repo.month(session, month);
      expect(tour.planFor(1)!.workType, WorkType.fieldWork,
          reason: 'the change must stick');
      expect(tour.plans.length, 2,
          reason: 'editing a day must not leave a second record behind — the '
              'manager would have two answers for one date');
    });

    test('switching to leave clears the area it used to carry', () async {
      final repo = MockTravelRepository();
      await repo.saveDay(day(5, WorkType.fieldWork, areaId: 'ar-1'));
      await repo.saveDay(day(5, WorkType.leave));

      final tour = await repo.month(session, month);
      expect(tour.planFor(5)!.areaId, isNull);
    });
  });

  group('the month goes in one piece', () {
    test('an incomplete month is refused, and nothing is sent', () async {
      final repo = MockTravelRepository();
      await repo.saveDay(day(10, WorkType.fieldWork, areaId: 'ar-1'));

      final tour = await repo.month(session, month);
      expect(tour.isComplete, isFalse);

      final sent = await repo.submitMonth(session, month);
      expect(sent, 0, reason: 'a plan with gaps is one nobody can approve');

      final after = await repo.month(session, month);
      expect(after.planFor(10)!.status, ApprovalStatus.draft,
          reason: 'a refused submit must leave every day as it was');
    });

    test('a complete month goes, and then locks', () async {
      final repo = MockTravelRepository();
      final total = DateTime(month.year, month.month + 1, 0).day;
      for (var d = 1; d <= total; d++) {
        await repo.saveDay(day(d, WorkType.fieldWork, areaId: 'ar-1'));
      }

      final ready = await repo.month(session, month);
      expect(ready.isComplete, isTrue);
      expect(ready.missingDays, 0);

      expect(await repo.submitMonth(session, month), total);

      final after = await repo.month(session, month);
      expect(after.isSubmitted, isTrue);
      expect(after.isEditable, isFalse,
          reason: 'an approver is looking at it now');
    });
  });

  group('leave and holidays need nothing but themselves', () {
    test('only they skip the territory questions', () {
      expect(tourDayNeedsDetail(WorkType.leave), isFalse);
      expect(tourDayNeedsDetail(WorkType.holiday), isFalse);
      for (final t in [
        WorkType.fieldWork,
        WorkType.officeWork,
        WorkType.meeting,
        WorkType.training,
      ]) {
        expect(tourDayNeedsDetail(t), isTrue, reason: t.label);
      }
    });

    test('a leave day still counts as planned', () {
      // Saying "I am not working" is an answer. If it did not count, a month
      // with leave in it could never be completed.
      final tour = TourMonth(
        month: DateTime(2031, 4),
        plans: {1: day(1, WorkType.leave)},
      );
      expect(tour.plannedDays, 1);
    });
  });

  group('Sunday is the week off, and nobody plans it', () {
    // March 2031 has five Sundays: the 2nd, 9th, 16th, 23rd and 30th.
    test('Sundays are not days the rep has to answer for', () {
      final march = TourMonth(month: _march, plans: {});
      expect(march.totalDays, 31);
      expect(march.workingDays, 26, reason: 'five Sundays are not questions');
      expect(march.isOff(2), isTrue);
      expect(march.isOff(3), isFalse);
    });

    test('a company holiday is off too, and says which one', () {
      final march = TourMonth(
        month: _march,
        plans: const {},
        holidays: const {17: 'Holi'},
      );
      expect(march.workingDays, 25);
      expect(march.isOff(17), isTrue);
      expect(march.holidayName(17), 'Holi');
    });

    test('a month is complete once every working day is answered', () {
      final plans = <int, TravelPlan>{
        for (var d = 1; d <= 31; d++)
          if (DateTime(2031, 3, d).weekday != DateTime.sunday)
            d: day(d, WorkType.fieldWork, areaId: 'ar-1'),
      };
      final tour = TourMonth(month: _march, plans: plans);

      expect(tour.missingDays, 0);
      expect(tour.isComplete, isTrue,
          reason: 'the five Sundays were never his to fill');
    });

    test('working a Sunday is allowed, and is not counted as a working day',
        () {
      // The rep took the camp on the 2nd. It is a real plan and it goes with
      // the month — but it must not make the month's denominator move, or
      // "26 of 26" would become "27 of 26".
      final tour = TourMonth(
        month: _march,
        plans: {2: day(2, WorkType.fieldWork, areaId: 'ar-1')},
      );
      expect(tour.workingDays, 26);
      expect(tour.plannedDays, 0, reason: 'it was never one of the 26');
      expect(tour.missingDays, 26);
      expect(tour.plans.length, 1, reason: 'but the plan is real and saved');
    });

    test('the repository names the company holidays in the month', () async {
      final repo = MockTravelRepository();
      final hr = MockHrRepository();
      final year = DateTime.now().year;
      final holidays = await hr.holidays(year);
      if (holidays.isEmpty) return;

      final h = holidays.first;
      final tour = await repo.month(session, DateTime(h.date.year, h.date.month));
      expect(tour.holidayName(h.date.day), h.name);
      expect(tour.isOff(h.date.day), isTrue);
    });
  });
}

final _march = DateTime(2031, 3);
