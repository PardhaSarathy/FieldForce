import '../../core/utils/formatters.dart';
import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/business.dart';
import '../../shared/models/organization.dart';
import 'mock_repositories.dart';
import 'repositories.dart';

/// Aggregation over the in-memory store.
///
/// Everything here is *computed from transactional records* — activities,
/// orders, expenses — never from a parallel set of hardcoded report numbers.
/// That is the point of §66.9: if the daily report says 47 completed visits,
/// 47 completed activity records exist. It also means this logic is the real
/// aggregation spec, ready to be reimplemented as SQL server-side.
class MockReportRepository implements ReportRepository {
  final _store = MockStore.instance;

  Iterable<Activity> _activities(
    Session session, {
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) {
    final visible = _store.visibleEmployeeIds(session);
    return _store.activities.where((a) {
      if (!visible.contains(a.employeeId)) return false;
      if (employeeId != null && a.employeeId != employeeId) return false;
      final d = dateOnly(a.scheduledStart);
      return !d.isBefore(dateOnly(from)) && !d.isAfter(dateOnly(to));
    });
  }

  @override
  Future<DailyReport> daily(
    Session session, {
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));

    final items =
        _activities(session, from: from, to: to, employeeId: employeeId).toList();

    final completed =
        items.where((a) => a.status == ActivityStatus.completed).toList();
    final missed = items.where((a) => a.status == ActivityStatus.missed).length;

    final workingDays = _workingDaysBetween(from, to);
    final fieldDays = items.map((a) => dateOnly(a.scheduledStart)).toSet().length;

    final visible = _store.visibleEmployeeIds(session);
    final orders = _store.orders.where((o) =>
        visible.contains(o.employeeId) &&
        (employeeId == null || o.employeeId == employeeId) &&
        !dateOnly(o.date).isBefore(dateOnly(from)) &&
        !dateOnly(o.date).isAfter(dateOnly(to)));

    final expenses = _store.expenses.where((e) =>
        visible.contains(e.employeeId) &&
        (employeeId == null || e.employeeId == employeeId) &&
        !dateOnly(e.date).isBefore(dateOnly(from)) &&
        !dateOnly(e.date).isAfter(dateOnly(to)));

    // Distance is a placeholder until real location traces exist; derived
    // stably from the visit count so it does not flicker between reads.
    final distance = completed.length * 4.6;

    return DailyReport(
      workingDays: workingDays,
      fieldDays: fieldDays,
      totalVisits: items.length,
      completed: completed.length,
      missed: missed,
      clientsCovered: completed.map((a) => a.clientId).toSet().length,
      orders: orders.length,
      orderValue: orders.fold<double>(0, (s, o) => s + o.grandTotal),
      expenseTotal: expenses.fold<double>(0, (s, e) => s + e.amount),
      distanceKm: distance,
      trend: _dailyTrend(items, from, to),
    );
  }

  @override
  Future<VisitReport> visits(
    Session session, {
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String? areaId,
    ClientType? clientType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));

    var items =
        _activities(session, from: from, to: to, employeeId: employeeId);
    if (clientType != null) {
      items = items.where((a) => a.clientType == clientType);
    }
    if (areaId != null) {
      final areaName =
          _store.seed.areas.where((a) => a.id == areaId).firstOrNull?.name;
      items = items.where((a) => a.areaName == areaName);
    }
    final list = items.toList();

    final completed =
        list.where((a) => a.status == ActivityStatus.completed).toList();

    final durations = completed
        .map((a) => a.duration)
        .whereType<Duration>()
        .toList();
    final avgMinutes = durations.isEmpty
        ? 0
        : durations.fold<int>(0, (s, d) => s + d.inMinutes) ~/ durations.length;

    final byType = <ClientType, int>{};
    for (final a in list) {
      byType[a.clientType] = (byType[a.clientType] ?? 0) + 1;
    }

    return VisitReport(
      total: list.length,
      completed: completed.length,
      missed: list.where((a) => a.status == ActivityStatus.missed).length,
      rescheduled:
          list.where((a) => a.status == ActivityStatus.rescheduled).length,
      averageDuration: Duration(minutes: avgMinutes),
      uniqueClients: list.map((a) => a.clientId).toSet().length,
      byClientType: byType,
      verifiedCount: completed.where((a) => a.isVerified).length,
      trend: _dailyTrend(list, from, to),
    );
  }

  @override
  Future<SalesReport> salesReport(
    Session session, {
    required int year,
    String? employeeId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));

    final visible = _store.visibleEmployeeIds(session);
    final records = _store.seed.salesRecords.where((s) =>
        visible.contains(s.employeeId) &&
        (employeeId == null || s.employeeId == employeeId) &&
        s.month.year == year);

    final targets = _store.targets.where((t) =>
        visible.contains(t.employeeId) &&
        (employeeId == null || t.employeeId == employeeId) &&
        t.month.year == year);

    final monthly = <int, double>{};
    final monthlyTarget = <int, double>{};
    for (final r in records) {
      monthly[r.month.month] = (monthly[r.month.month] ?? 0) + r.amount;
    }
    for (final t in targets) {
      monthlyTarget[t.month.month] =
          (monthlyTarget[t.month.month] ?? 0) + t.targetAmount;
    }

    // Product split aggregated across every employee in scope.
    final productTotals = <String, ProductSales>{};
    for (final r in records) {
      for (final p in r.productBreakup) {
        final existing = productTotals[p.productId];
        productTotals[p.productId] = ProductSales(
          productId: p.productId,
          productName: p.productName,
          amount: (existing?.amount ?? 0) + p.amount,
          units: (existing?.units ?? 0) + p.units,
          sharePercent: p.sharePercent,
        );
      }
    }

    final total = records.fold<double>(0, (s, r) => s + r.amount);

    return SalesReport(
      total: total,
      target: targets.fold<double>(0, (s, t) => s + t.targetAmount),
      primary: records.fold<double>(0, (s, r) => s + r.primaryAmount),
      secondary: records.fold<double>(0, (s, r) => s + r.secondaryAmount),
      monthly: [
        for (var m = 1; m <= 12; m++)
          ChartPoint(
            label: Fmt.monthShort(DateTime(year, m)),
            value: monthly[m] ?? 0,
            secondary: monthlyTarget[m] ?? 0,
          ),
      ],
      byProduct: productTotals.values.toList()
        ..sort((a, b) => b.amount.compareTo(a.amount)),
    );
  }

  @override
  Future<TargetReport> targetReport(
    Session session, {
    required DateTime month,
    String? employeeId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final visible = _store.visibleEmployeeIds(session);
    final all = _store.targets.where((t) =>
        visible.contains(t.employeeId) &&
        (employeeId == null || t.employeeId == employeeId));

    final rows = all
        .where((t) => t.month.year == month.year && t.month.month == month.month)
        .toList()
      ..sort((a, b) => b.achievementPercent.compareTo(a.achievementPercent));

    // Trailing six months of achievement for the trend line.
    final trend = <ChartPoint>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(month.year, month.month - i, 1);
      final slice =
          all.where((t) => t.month.year == m.year && t.month.month == m.month);
      final target = slice.fold<double>(0, (s, t) => s + t.targetAmount);
      final achieved = slice.fold<double>(0, (s, t) => s + t.achievedAmount);
      trend.add(ChartPoint(
        label: Fmt.monthShort(m),
        value: achieved,
        secondary: target,
      ));
    }

    return TargetReport(
      target: rows.fold<double>(0, (s, t) => s + t.targetAmount),
      achieved: rows.fold<double>(0, (s, t) => s + t.achievedAmount),
      rows: rows,
      trend: trend,
    );
  }

  @override
  Future<ExpenseReport> expenseReport(
    Session session, {
    required DateTime month,
    String? employeeId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final visible = _store.visibleEmployeeIds(session);
    final all = _store.expenses.where((e) =>
        visible.contains(e.employeeId) &&
        (employeeId == null || e.employeeId == employeeId));

    final inMonth = all
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList();

    final byCategory = <ExpenseCategory, double>{};
    for (final e in inMonth) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    final trend = <ChartPoint>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(month.year, month.month - i, 1);
      final total = all
          .where((e) => e.date.year == m.year && e.date.month == m.month)
          .fold<double>(0, (s, e) => s + e.amount);
      trend.add(ChartPoint(label: Fmt.monthShort(m), value: total));
    }

    double sumWhere(bool Function(ApprovalStatus) test) => inMonth
        .where((e) => test(e.status))
        .fold<double>(0, (s, e) => s + e.amount);

    return ExpenseReport(
      byCategory: byCategory,
      total: inMonth.fold<double>(0, (s, e) => s + e.amount),
      approved: sumWhere((s) => s == ApprovalStatus.approved),
      pending: sumWhere((s) => s.awaitsDecision),
      rejected: sumWhere((s) => s == ApprovalStatus.rejected),
      trend: trend,
    );
  }

  @override
  Future<OverviewReport> overview(
    Session session, {
    required DateTime month,
    String? employeeId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 340));

    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);

    final items =
        _activities(session, from: from, to: to, employeeId: employeeId).toList();
    final completed =
        items.where((a) => a.status == ActivityStatus.completed).toList();

    final visible = _store.visibleEmployeeIds(session);

    final leaveDays = _store.leaves
        .where((l) =>
            visible.contains(l.employeeId) &&
            (employeeId == null || l.employeeId == employeeId) &&
            l.status == ApprovalStatus.approved &&
            l.fromDate.year == month.year &&
            l.fromDate.month == month.month)
        .fold<int>(0, (s, l) => s + l.days);

    final fieldDays = items.map((a) => dateOnly(a.scheduledStart)).toSet().length;
    final workingDays = _workingDaysBetween(from, to);

    final newClients = _store.clients
        .where((c) =>
            c.createdAt != null &&
            c.createdAt!.year == month.year &&
            c.createdAt!.month == month.month &&
            (employeeId == null || c.ownerEmployeeId == employeeId) &&
            (c.ownerEmployeeId == null || visible.contains(c.ownerEmployeeId)))
        .length;

    final targets = _store.targets.where((t) =>
        visible.contains(t.employeeId) &&
        (employeeId == null || t.employeeId == employeeId) &&
        t.month.year == month.year &&
        t.month.month == month.month);

    final expenses = _store.expenses.where((e) =>
        visible.contains(e.employeeId) &&
        (employeeId == null || e.employeeId == employeeId) &&
        e.date.year == month.year &&
        e.date.month == month.month);

    return OverviewReport(
      workingDays: workingDays,
      fieldDays: fieldDays,
      leaveDays: leaveDays,
      nonFieldDays: (workingDays - fieldDays - leaveDays).clamp(0, workingDays),
      visits: items.length,
      completedVisits: completed.length,
      newClients: newClients,
      hospitalCoverage: completed
          .where((a) => a.clientType == ClientType.hospital)
          .map((a) => a.clientId)
          .toSet()
          .length,
      sales: targets.fold<double>(0, (s, t) => s + t.achievedAmount),
      target: targets.fold<double>(0, (s, t) => s + t.targetAmount),
      expenses: expenses.fold<double>(0, (s, e) => s + e.amount),
    );
  }

  @override
  Future<ManagerDashboard> managerDashboard(Session session) async {
    await Future<void>.delayed(const Duration(milliseconds: 340));

    final today = _store.seed.today;
    final team = _store.seed
        .subtreeOf(session.employee.id)
        .where((e) => e.id != session.employee.id)
        .toList();
    final teamIds = team.map((e) => e.id).toSet();

    final todaysActivities = _store.activities
        .where((a) => teamIds.contains(a.employeeId) && sameDay(a.scheduledStart, today))
        .toList();

    final completed = todaysActivities
        .where((a) => a.status == ActivityStatus.completed)
        .toList();

    // Someone is "behind plan" when they have completed materially less than
    // the elapsed portion of the working day would predict.
    var behind = 0;
    final hour = DateTime.now().hour + DateTime.now().minute / 60;
    final elapsed = ((hour - 9) / 9).clamp(0.0, 1.0);

    for (final member in team) {
      final theirs =
          todaysActivities.where((a) => a.employeeId == member.id).toList();
      if (theirs.isEmpty) continue;
      final done =
          theirs.where((a) => a.status == ActivityStatus.completed).length;
      if (done < (theirs.length * elapsed) - 1) behind++;
    }

    final pending = await MockApprovalRepository().pending(session);
    final pendingByKind = <ApprovalKind, int>{};
    for (final item in pending) {
      pendingByKind[item.kind] = (pendingByKind[item.kind] ?? 0) + 1;
    }

    final monthTargets = _store.targets.where((t) =>
        teamIds.contains(t.employeeId) &&
        t.month.year == today.year &&
        t.month.month == today.month);

    final monthOrders = _store.orders.where((o) =>
        teamIds.contains(o.employeeId) &&
        o.date.year == today.year &&
        o.date.month == today.month);

    final monthExpenses = _store.expenses.where((e) =>
        teamIds.contains(e.employeeId) &&
        e.date.year == today.year &&
        e.date.month == today.month);

    // Present today = has at least one completed visit today.
    final presentIds = completed.map((a) => a.employeeId).toSet();

    return ManagerDashboard(
      teamSize: team.length,
      presentToday: presentIds.length,
      visitsPlanned: todaysActivities.length,
      visitsCompleted: completed.length,
      pendingApprovals: pending.length,
      pendingByKind: pendingByKind,
      sales: monthTargets.fold<double>(0, (s, t) => s + t.achievedAmount),
      target: monthTargets.fold<double>(0, (s, t) => s + t.targetAmount),
      orderCount: monthOrders.length,
      expenseTotal: monthExpenses.fold<double>(0, (s, e) => s + e.amount),
      behindPlanCount: behind,
      unverifiedVisits: completed.where((a) => !a.isVerified).length,
    );
  }

  // ------------------------------------------------------------- helpers

  /// Mon–Sat, excluding declared holidays. Six-day weeks are the norm for
  /// Indian pharma field teams.
  int _workingDaysBetween(DateTime from, DateTime to) {
    var count = 0;
    var cursor = dateOnly(from);
    final end = dateOnly(to);
    final holidays = _store.seed.holidays.map((h) => dateOnly(h.date)).toSet();

    while (!cursor.isAfter(end)) {
      if (cursor.weekday != DateTime.sunday && !holidays.contains(cursor)) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  /// Completed-visit counts per day, capped to the last 14 points so a
  /// year-long range still renders a readable chart.
  List<ChartPoint> _dailyTrend(List<Activity> items, DateTime from, DateTime to) {
    final byDay = <DateTime, int>{};
    for (final a in items.where((a) => a.status == ActivityStatus.completed)) {
      final d = dateOnly(a.scheduledStart);
      byDay[d] = (byDay[d] ?? 0) + 1;
    }

    final days = byDay.keys.toList()..sort();
    final tail = days.length > 14 ? days.sublist(days.length - 14) : days;

    return [
      for (final d in tail)
        ChartPoint(label: Fmt.dateShort(d), value: (byDay[d] ?? 0).toDouble()),
    ];
  }
}
