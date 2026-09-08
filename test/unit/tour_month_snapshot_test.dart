import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/field_ops.dart';

/// A submitted month keeps the denominator it was judged against.
///
/// `workingDays` used to be recomputed on every read from the week-off rule
/// and holiday list *in force right now*. That is fine while nobody ever
/// changes either — and the moment a company moves its week off, or HR adds a
/// holiday to a past date, every month already approved silently restates
/// itself. Nobody edits anything; the question changes underneath the answer.
///
/// This is the same rule the fence radius and the daily allowance already
/// follow: a record keeps the policy it was judged under.
void main() {
  // September 2026: 30 days, and the 6th, 13th, 20th and 27th are Sundays.
  final september = DateTime(2026, 9);

  TourMonth monthWith({
    int weekOff = DateTime.sunday,
    Map<int, String> holidays = const {},
    TourRule? judgedUnder,
    Map<int, TravelPlan> plans = const {},
  }) =>
      TourMonth(
        month: september,
        plans: plans,
        holidays: holidays,
        weekOff: weekOff,
        judgedUnder: judgedUnder,
      );

  /// What September looked like when it was sent: Sundays off, no holidays.
  const asSent = TourRule(weekOff: DateTime.sunday, holidayDays: {});

  group('while the month is still a draft', () {
    test('working days are counted from the rule in force', () {
      expect(monthWith().workingDays, 26); // 30 less four Sundays
    });

    test('a company holiday takes a day out', () {
      expect(monthWith(holidays: {17: 'Founder\'s Day'}).workingDays, 25);
    });

    test('a different week off gives a different count', () {
      // Five Tuesdays in September 2026 against four Sundays.
      expect(monthWith(weekOff: DateTime.tuesday).workingDays, 25);
    });
  });

  group('once the month has been sent', () {
    test('the count is the one it was judged against', () {
      final sent = monthWith(judgedUnder: asSent);
      expect(sent.workingDays, 26);
    });

    test('moving the week off afterwards does not restate it', () {
      // The company switches to Tuesday-off in March. September was approved
      // at 26 of 26; it must still read 26.
      final sent = monthWith(weekOff: DateTime.tuesday, judgedUnder: asSent);
      expect(sent.workingDays, 26,
          reason: 'a month already approved cannot change denominator');
    });

    test('a holiday added to a past date does not restate it either', () {
      final sent = monthWith(holidays: {17: 'Declared in hindsight'}, judgedUnder: asSent);
      expect(sent.workingDays, 26);
    });

    test('completeness is judged on the frozen figure', () {
      // 26 planned days against a frozen 26 is complete, and stays complete
      // however the rule moves afterwards.
      final plans = <int, TravelPlan>{
        for (var d = 1; d <= 30; d++)
          if (DateTime(2026, 9, d).weekday != DateTime.sunday)
            d: TravelPlan(
              id: 'tp-$d',
              employeeId: 'emp-1',
              employeeName: 'A rep',
              date: DateTime(2026, 9, d),
              workType: WorkType.fieldWork,
              status: ApprovalStatus.submitted,
            ),
      };
      final sent = monthWith(
        plans: plans,
        weekOff: DateTime.tuesday, // the rule moved after the fact
        judgedUnder: asSent,
      );
      // Freezing the count alone was not enough: `plannedDays` went on
      // counting against the live week off, so a frozen denominator and a
      // moving numerator reported five missing days out of nowhere. Freezing
      // the rule keeps all three in step.
      expect(sent.workingDays, 26);
      expect(sent.plannedDays, 26);
      expect(sent.missingDays, 0);
      expect(sent.isComplete, isTrue);
    });
  });
}
