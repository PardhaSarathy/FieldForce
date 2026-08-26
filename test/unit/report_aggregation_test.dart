import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_report_repository.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/activity.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// Report aggregation (§33–§39, §66.9).
///
/// The property that matters is *reconciliation*: a report figure must equal
/// what you get by counting the underlying transactional records. If these
/// drift, managers make decisions on numbers that do not exist anywhere else.
void main() {
  final store = MockStore.instance;
  final reports = MockReportRepository();

  Session sessionFor(String code) {
    final employee =
        store.seed.employees.firstWhere((e) => e.employeeCode == code);
    return Session(employee: employee, loginAt: DateTime(2026, 8, 26));
  }

  final month = DateTime(store.seed.today.year, store.seed.today.month);
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);

  group('DailyReport', () {
    test('visit counts reconcile with the activity records', () async {
      final session = sessionFor('MR1001');
      final report = await reports.daily(
        session,
        from: monthStart,
        to: monthEnd,
        employeeId: session.employee.id,
      );

      final actual = store.activities.where((a) =>
          a.employeeId == session.employee.id &&
          !a.scheduledStart.isBefore(monthStart) &&
          a.scheduledStart.isBefore(monthEnd.add(const Duration(days: 1))));

      expect(report.totalVisits, actual.length);
      expect(
        report.completed,
        actual.where((a) => a.status == ActivityStatus.completed).length,
      );
      expect(
        report.missed,
        actual.where((a) => a.status == ActivityStatus.missed).length,
      );
    });

    test('completion rate is consistent with its own counts', () async {
      final session = sessionFor('MR1001');
      final report = await reports.daily(
        session,
        from: monthStart,
        to: monthEnd,
        employeeId: session.employee.id,
      );

      expect(
        report.completionRate,
        closeTo((report.completed / report.totalVisits) * 100, 0.001),
      );
    });

    test('clients covered never exceeds completed visits', () async {
      final session = sessionFor('MR1001');
      final report = await reports.daily(
        session,
        from: monthStart,
        to: monthEnd,
        employeeId: session.employee.id,
      );

      expect(report.clientsCovered, lessThanOrEqualTo(report.completed));
    });

    test('an empty date range yields zeroes, not a crash', () async {
      final session = sessionFor('MR1001');
      final future = DateTime(2035, 1, 1);
      final report = await reports.daily(
        session,
        from: future,
        to: future.add(const Duration(days: 1)),
      );

      expect(report.totalVisits, 0);
      expect(report.completed, 0);
      expect(report.completionRate, 0);
      expect(report.trend, isEmpty);
    });
  });

  group('VisitReport', () {
    test('status counts sum to no more than the total', () async {
      final session = sessionFor('MR1001');
      final report = await reports.visits(
        session,
        from: monthStart,
        to: monthEnd,
        employeeId: session.employee.id,
      );

      expect(
        report.completed + report.missed + report.rescheduled,
        lessThanOrEqualTo(report.total),
      );
    });

    test('verified visits never exceed completed visits', () async {
      final session = sessionFor('MR1001');
      final report = await reports.visits(
        session,
        from: monthStart,
        to: monthEnd,
        employeeId: session.employee.id,
      );

      expect(report.verifiedCount, lessThanOrEqualTo(report.completed));
      expect(report.verificationRate, lessThanOrEqualTo(100));
      expect(report.verificationRate, greaterThanOrEqualTo(0));
    });

    test('client-type breakdown sums to the total', () async {
      final session = sessionFor('MR1001');
      final report = await reports.visits(
        session,
        from: monthStart,
        to: monthEnd,
        employeeId: session.employee.id,
      );

      final sum =
          report.byClientType.values.fold<int>(0, (s, v) => s + v);
      expect(sum, report.total);
    });

    test('a manager\'s totals are at least the sum of one report\'s', () async {
      final manager = sessionFor('ASM201');
      final rep = sessionFor('MR1001');

      final teamReport = await reports.visits(
        manager,
        from: monthStart,
        to: monthEnd,
      );
      final repReport = await reports.visits(
        rep,
        from: monthStart,
        to: monthEnd,
        employeeId: rep.employee.id,
      );

      expect(teamReport.total, greaterThanOrEqualTo(repReport.total));
    });
  });

  group('ExpenseReport', () {
    test('category totals sum to the overall total', () async {
      final session = sessionFor('MR1001');
      final report = await reports.expenseReport(
        session,
        month: month,
        employeeId: session.employee.id,
      );

      final sum = report.byCategory.values.fold<double>(0, (s, v) => s + v);
      expect(sum, closeTo(report.total, 0.01));
    });

    test('approved, pending and rejected partition the total', () async {
      final session = sessionFor('MR1001');
      final report = await reports.expenseReport(
        session,
        month: month,
        employeeId: session.employee.id,
      );

      // Drafts are excluded from all three buckets, so the parts can be less
      // than the total but never more.
      expect(
        report.approved + report.pending + report.rejected,
        lessThanOrEqualTo(report.total + 0.01),
      );
    });

    test('trend covers six months', () async {
      final session = sessionFor('MR1001');
      final report = await reports.expenseReport(
        session,
        month: month,
        employeeId: session.employee.id,
      );

      expect(report.trend, hasLength(6));
    });
  });

  group('TargetReport', () {
    test('totals equal the sum of the rows', () async {
      final session = sessionFor('ASM201');
      final report = await reports.targetReport(session, month: month);

      final targetSum =
          report.rows.fold<double>(0, (s, t) => s + t.targetAmount);
      final achievedSum =
          report.rows.fold<double>(0, (s, t) => s + t.achievedAmount);

      expect(report.target, closeTo(targetSum, 0.01));
      expect(report.achieved, closeTo(achievedSum, 0.01));
    });

    test('gap is never negative', () async {
      final session = sessionFor('ASM201');
      final report = await reports.targetReport(session, month: month);

      expect(report.gap, greaterThanOrEqualTo(0));
    });
  });

  group('OverviewReport', () {
    test('day categories stay within the calendar month', () async {
      final session = sessionFor('MR1001');
      final report = await reports.overview(
        session,
        month: month,
        employeeId: session.employee.id,
      );

      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

      // Field days are NOT bounded by working days: a rep who covers a chemist
      // on a declared holiday genuinely worked a field day that the working-day
      // count excludes. Both figures are correct; they answer different
      // questions. The real invariants are that neither exceeds the calendar
      // and that the derived non-field figure never goes negative.
      expect(report.workingDays, lessThanOrEqualTo(daysInMonth));
      expect(report.fieldDays, lessThanOrEqualTo(daysInMonth));
      expect(report.nonFieldDays, greaterThanOrEqualTo(0));
      expect(report.nonFieldDays, lessThanOrEqualTo(report.workingDays));
    });

    test('completed visits never exceed total visits', () async {
      final session = sessionFor('MR1001');
      final report = await reports.overview(
        session,
        month: month,
        employeeId: session.employee.id,
      );

      expect(report.completedVisits, lessThanOrEqualTo(report.visits));
    });
  });

  group('ManagerDashboard', () {
    test('present today never exceeds team size', () async {
      final session = sessionFor('ASM201');
      final dashboard = await reports.managerDashboard(session);

      expect(dashboard.presentToday, lessThanOrEqualTo(dashboard.teamSize));
      expect(dashboard.teamSize, greaterThan(0));
    });

    test('completed visits never exceed planned', () async {
      final session = sessionFor('ASM201');
      final dashboard = await reports.managerDashboard(session);

      expect(
        dashboard.visitsCompleted,
        lessThanOrEqualTo(dashboard.visitsPlanned),
      );
      expect(dashboard.visitGap, greaterThanOrEqualTo(0));
    });

    test('pending-by-kind counts sum to the total pending', () async {
      final session = sessionFor('ASM201');
      final dashboard = await reports.managerDashboard(session);

      final sum =
          dashboard.pendingByKind.values.fold<int>(0, (s, v) => s + v);
      expect(sum, dashboard.pendingApprovals);
    });

    test('unverified visits never exceed completed visits', () async {
      final session = sessionFor('ASM201');
      final dashboard = await reports.managerDashboard(session);

      expect(
        dashboard.unverifiedVisits,
        lessThanOrEqualTo(dashboard.visitsCompleted),
      );
    });
  });

  group('DaySummary derivation', () {
    test('progress and counts agree', () async {
      final session = sessionFor('MR1001');
      final summary = await MockActivityRepository()
          .daySummary(session.employee.id, store.seed.today);

      expect(summary.planned, summary.activities.length);
      expect(
        summary.completed,
        summary.activities
            .where((a) => a.status == ActivityStatus.completed)
            .length,
      );
      expect(summary.progress, closeTo(summary.completed / summary.planned, 0.001));
      expect(summary.progressPercent, (summary.progress * 100).round());
    });

    test('next action is the earliest open activity', () async {
      final session = sessionFor('MR1001');
      final summary = await MockActivityRepository()
          .daySummary(session.employee.id, store.seed.today);

      final next = summary.nextAction;
      final open = summary.activities.where((a) => a.status.isOpen).toList();

      // Late in the working day every visit may legitimately be complete, in
      // which case there is no next action — Home shows "all visits complete".
      if (open.isEmpty) {
        expect(next, isNull);
        expect(summary.completed, summary.planned);
        return;
      }

      expect(next, isNotNull);
      expect(next!.status.isOpen, isTrue);

      for (final other in open) {
        expect(
          next.scheduledStart.isAfter(other.scheduledStart),
          isFalse,
          reason: 'nextAction must be the earliest open activity',
        );
      }
    });

    test('an empty day reports no next action rather than throwing', () {
      final summary = DaySummary(date: DateTime(2035, 1, 1), activities: const []);

      expect(summary.planned, 0);
      expect(summary.progress, 0);
      expect(summary.nextAction, isNull);
      expect(summary.paceLabel(), 'No visits planned');
    });

    test('pace label reports completion when the day is done', () {
      final activities = store.activities
          .where((a) => a.status == ActivityStatus.completed)
          .take(3)
          .toList();
      final summary =
          DaySummary(date: store.seed.today, activities: activities);

      expect(summary.completed, summary.planned);
      expect(summary.paceLabel(), 'All visits complete');
    });
  });
}
