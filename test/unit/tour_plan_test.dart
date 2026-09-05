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
      expect(tour.plannedDays, 1);

      // ...the rep plans other days...
      await repo.saveDay(day(2, WorkType.fieldWork, areaId: 'ar-1'));

      // ...then comes back and changes 1 March to field work.
      await repo.saveDay(day(1, WorkType.fieldWork, areaId: 'ar-1'));

      tour = await repo.month(session, month);
      expect(tour.planFor(1)!.workType, WorkType.fieldWork,
          reason: 'the change must stick');
      expect(tour.plannedDays, 2,
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
      await repo.saveDay(day(9, WorkType.fieldWork, areaId: 'ar-1'));

      final tour = await repo.month(session, month);
      expect(tour.isComplete, isFalse);

      final sent = await repo.submitMonth(session, month);
      expect(sent, 0, reason: 'a plan with gaps is one nobody can approve');

      final after = await repo.month(session, month);
      expect(after.planFor(9)!.status, ApprovalStatus.draft,
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
      // with a holiday in it could never be completed.
      final tour = TourMonth(
        month: DateTime(2031, 4),
        plans: {1: day(1, WorkType.leave)},
      );
      expect(tour.plannedDays, 1);
    });
  });
}
