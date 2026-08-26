import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/repositories.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/charts.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

/// Shared report filter state. Kept at module scope so moving between report
/// types preserves the period and employee a manager has already chosen —
/// re-picking filters on every screen is the fastest way to make reports
/// unusable.
final reportMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final reportEmployeeProvider = StateProvider<String?>((ref) => null);

/// Employees the current user may filter by. An MR sees only themselves, so
/// the selector hides itself rather than showing a pointless single option.
final reportEmployeesProvider =
    FutureProvider.autoDispose<List<Employee>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isManager) return const [];
  return ref.watch(employeeRepositoryProvider).teamOf(session);
});

// ============================================================ reports home ==

class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const reports = [
      (Icons.today_outlined, 'Daily Report',
          'Visits, coverage, orders and expenses by day', Routes.dailyReport),
      (Icons.event_note_outlined, 'Visit Report',
          'Completion, coverage and verification', Routes.visitReport),
      (Icons.trending_up, 'Sales Report',
          'Sales versus target, primary and secondary', Routes.salesReport),
      (Icons.flag_outlined, 'Target Report',
          'Target, actual, achievement and gap', Routes.targetReport),
      (Icons.receipt_long_outlined, 'Expense Report',
          'Category split and approval status', Routes.expenseReport),
      (Icons.insights_outlined, 'Overview Report',
          'Everything for the month in one view', Routes.overviewReport),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          const ReportFilterBar(),
          const SizedBox(height: AppSpacing.section),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < reports.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: AppSpacing.cardPadding),
                  ListTile(
                    leading: IconTile(icon: reports[i].$1),
                    title: Text(reports[i].$2, style: AppTypography.titleMd),
                    subtitle:
                        Text(reports[i].$3, style: AppTypography.caption),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push(reports[i].$4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl * 3),
        ],
      ),
    );
  }
}

/// Period and employee selector shared by every report (§85).
class ReportFilterBar extends ConsumerWidget {
  const ReportFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportMonthProvider);
    final employeeId = ref.watch(reportEmployeeProvider);
    final employeesAsync = ref.watch(reportEmployeesProvider);
    final now = DateTime.now();

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => ref.read(reportMonthProvider.notifier).state =
                    DateTime(month.year, month.month - 1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('PERIOD', style: AppTypography.overline),
                    Text(Fmt.monthYear(month), style: AppTypography.titleMd),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: month.isBefore(DateTime(now.year, now.month))
                    ? () => ref.read(reportMonthProvider.notifier).state =
                        DateTime(month.year, month.month + 1)
                    : null,
              ),
            ],
          ),
          employeesAsync.maybeWhen(
            data: (employees) => employees.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      const AppDivider(),
                      DropdownField<String>(
                        label: 'Employee',
                        hint: 'Whole team',
                        items: ['__all__', ...employees.map((e) => e.id)],
                        value: employeeId ?? '__all__',
                        itemLabel: (id) => id == '__all__'
                            ? 'Whole team'
                            : employees.firstWhere((e) => e.id == id).name,
                        onChanged: (v) =>
                            ref.read(reportEmployeeProvider.notifier).state =
                                v == '__all__' ? null : v,
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Common chrome for an individual report.
class _ReportScaffold extends StatelessWidget {
  const _ReportScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          const ReportFilterBar(),
          const SizedBox(height: AppSpacing.section),
          ...children,
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

/// Grid of labelled figures — the backbone of every report screen.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.metrics, this.columns = 2});

  final List<({String label, String value, Color? color})> metrics;
  final int columns;

  @override
  Widget build(BuildContext context) {
    // Height from content and text scale, not from an aspect ratio. With
    // childAspectRatio the tile height follows the device width, so a narrow
    // phone or a large system font size overflowed the card.
    final scale = MediaQuery.textScalerOf(context);
    final extent = AppSpacing.md * 2 +
        scale.scale(AppTypography.overline.fontSize!) * 1.3 +
        AppSpacing.xs +
        scale.scale(AppTypography.metricSm.fontSize!) * 1.3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        mainAxisExtent: extent,
      ),
      itemBuilder: (context, i) {
        final m = metrics[i];
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                m.label.toUpperCase(),
                style: AppTypography.overline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                m.value,
                style: AppTypography.metricSm.copyWith(color: m.color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================== daily report ==

final _dailyProvider = FutureProvider.autoDispose<DailyReport>((ref) {
  final session = ref.watch(sessionProvider);
  final month = ref.watch(reportMonthProvider);
  return ref.watch(reportRepositoryProvider).daily(
        session,
        from: DateTime(month.year, month.month, 1),
        to: DateTime(month.year, month.month + 1, 0),
        employeeId: ref.watch(reportEmployeeProvider) ??
            (session.isManager ? null : session.employee.id),
      );
});

class DailyReportScreen extends ConsumerWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dailyProvider);

    return _ReportScaffold(
      title: 'Daily Report',
      children: [
        async.when(
          loading: () => const Skeleton(height: 220, radius: AppRadius.lg),
          error: (_, _) => const ErrorState(compact: true),
          data: (r) => Column(
            children: [
              MetricGrid(metrics: [
                (label: 'Working days', value: '${r.workingDays}', color: null),
                (label: 'Field days', value: '${r.fieldDays}', color: null),
                (label: 'Total visits', value: '${r.totalVisits}', color: null),
                (
                  label: 'Completed',
                  value: '${r.completed}',
                  color: AppColors.success
                ),
                (label: 'Missed', value: '${r.missed}', color: AppColors.error),
                (
                  label: 'Clients covered',
                  value: '${r.clientsCovered}',
                  color: null
                ),
                (label: 'Orders', value: '${r.orders}', color: null),
                (
                  label: 'Order value',
                  value: Fmt.moneyCompact(r.orderValue),
                  color: null
                ),
                (
                  label: 'Expenses',
                  value: Fmt.moneyCompact(r.expenseTotal),
                  color: null
                ),
                (
                  label: 'Distance',
                  value: '${r.distanceKm.round()} km',
                  color: null
                ),
              ]),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Completion rate'),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${r.completionRate.round()}% completed',
                              style: AppTypography.titleMd),
                        ),
                        Text('${r.completed} of ${r.totalVisits}',
                            style: AppTypography.caption),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppProgressBar(value: r.completionRate / 100),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Daily visit trend'),
              AppCard(
                child: TrendChart(points: r.trend, compactValues: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================== visit report ==

final _visitProvider = FutureProvider.autoDispose<VisitReport>((ref) {
  final session = ref.watch(sessionProvider);
  final month = ref.watch(reportMonthProvider);
  return ref.watch(reportRepositoryProvider).visits(
        session,
        from: DateTime(month.year, month.month, 1),
        to: DateTime(month.year, month.month + 1, 0),
        employeeId: ref.watch(reportEmployeeProvider) ??
            (session.isManager ? null : session.employee.id),
      );
});

class VisitReportScreen extends ConsumerWidget {
  const VisitReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_visitProvider);

    return _ReportScaffold(
      title: 'Visit Report',
      children: [
        async.when(
          loading: () => const Skeleton(height: 220, radius: AppRadius.lg),
          error: (_, _) => const ErrorState(compact: true),
          data: (r) => Column(
            children: [
              MetricGrid(metrics: [
                (label: 'Total visits', value: '${r.total}', color: null),
                (
                  label: 'Completed',
                  value: '${r.completed}',
                  color: AppColors.success
                ),
                (label: 'Missed', value: '${r.missed}', color: AppColors.error),
                (
                  label: 'Rescheduled',
                  value: '${r.rescheduled}',
                  color: AppColors.warning
                ),
                (
                  label: 'Avg duration',
                  value: Fmt.duration(r.averageDuration),
                  color: null
                ),
                (
                  label: 'Unique clients',
                  value: '${r.uniqueClients}',
                  color: null
                ),
              ]),
              const SizedBox(height: AppSpacing.section),

              const SectionHeader(title: 'Coverage & verification'),
              AppCard(
                child: Column(
                  children: [
                    _RateRow(
                      label: 'Coverage',
                      percent: r.coverage,
                      detail: '${r.completed} of ${r.total} visits completed',
                    ),
                    const AppDivider(),
                    _RateRow(
                      label: 'Geo-verified',
                      percent: r.verificationRate,
                      detail: '${r.verifiedCount} of ${r.completed} completed '
                          'visits verified within the fence',
                      color: r.verificationRate >= 85
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'By client type'),
              AppCard(
                child: CategoryBars(
                  entries: [
                    for (final entry in r.byClientType.entries)
                      (label: entry.key.label, value: entry.value.toDouble()),
                  ],
                  valueFormatter: (v) => v.round().toString(),
                ),
              ),

              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Visit trend'),
              AppCard(child: TrendChart(points: r.trend, compactValues: false)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.label,
    required this.percent,
    required this.detail,
    this.color,
  });

  final String label;
  final double percent;
  final String detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.titleSm)),
            Text('${percent.round()}%',
                style: AppTypography.titleMd.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(value: percent / 100, color: color, height: 5),
        const SizedBox(height: AppSpacing.xs),
        Text(detail, style: AppTypography.caption),
      ],
    );
  }
}

// =========================================================== sales report ==

final _salesReportProvider = FutureProvider.autoDispose<SalesReport>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(reportRepositoryProvider).salesReport(
        session,
        year: ref.watch(reportMonthProvider).year,
        employeeId: ref.watch(reportEmployeeProvider) ??
            (session.isManager ? null : session.employee.id),
      );
});

class SalesReportScreen extends ConsumerWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_salesReportProvider);

    return _ReportScaffold(
      title: 'Sales Report',
      children: [
        async.when(
          loading: () => const Skeleton(height: 220, radius: AppRadius.lg),
          error: (_, _) => const ErrorState(compact: true),
          data: (r) => Column(
            children: [
              MetricGrid(metrics: [
                (label: 'Sales', value: Fmt.moneyCompact(r.total), color: null),
                (
                  label: 'Target',
                  value: Fmt.moneyCompact(r.target),
                  color: null
                ),
                (
                  label: 'Achievement',
                  value: '${r.achievement.round()}%',
                  color: r.achievement >= 75
                      ? AppColors.success
                      : AppColors.warning
                ),
                (
                  label: 'Primary',
                  value: Fmt.moneyCompact(r.primary),
                  color: null
                ),
                (
                  label: 'Secondary',
                  value: Fmt.moneyCompact(r.secondary),
                  color: null
                ),
              ]),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Sales vs target'),
              AppCard(
                child: TrendChart(points: r.monthly, showComparison: true),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Product mix'),
              AppCard(
                child: CategoryBars(
                  entries: [
                    for (final p in r.byProduct)
                      (label: p.productName, value: p.amount),
                  ],
                  valueFormatter: Fmt.moneyCompact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ========================================================== target report ==

final _targetReportProvider = FutureProvider.autoDispose<TargetReport>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(reportRepositoryProvider).targetReport(
        session,
        month: ref.watch(reportMonthProvider),
        employeeId: ref.watch(reportEmployeeProvider) ??
            (session.isManager ? null : session.employee.id),
      );
});

class TargetReportScreen extends ConsumerWidget {
  const TargetReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_targetReportProvider);

    return _ReportScaffold(
      title: 'Target Report',
      children: [
        async.when(
          loading: () => const Skeleton(height: 220, radius: AppRadius.lg),
          error: (_, _) => const ErrorState(compact: true),
          data: (r) => Column(
            children: [
              AppCard(
                child: Column(
                  children: [
                    AchievementRing(percent: r.achievement),
                    const SizedBox(height: AppSpacing.lg),
                    KeyValueRow(label: 'Target', value: Fmt.money(r.target)),
                    KeyValueRow(label: 'Actual', value: Fmt.money(r.achieved)),
                    KeyValueRow(label: 'Gap', value: Fmt.money(r.gap)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Six-month trend'),
              AppCard(
                child: TrendChart(points: r.trend, showComparison: true,
                    valueLabel: 'Achieved'),
              ),
              if (r.rows.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Breakdown'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < r.rows.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.cardPadding),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.rows[i].employeeName,
                                        style: AppTypography.titleSm),
                                    Text(
                                      '${Fmt.moneyCompact(r.rows[i].achievedAmount)}'
                                      ' of ${Fmt.moneyCompact(r.rows[i].targetAmount)}',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                label:
                                    '${r.rows[i].achievementPercent.round()}%',
                                tone: r.rows[i].tone,
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ========================================================= expense report ==

final _expenseReportProvider = FutureProvider.autoDispose<ExpenseReport>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(reportRepositoryProvider).expenseReport(
        session,
        month: ref.watch(reportMonthProvider),
        employeeId: ref.watch(reportEmployeeProvider) ??
            (session.isManager ? null : session.employee.id),
      );
});

class ExpenseReportScreen extends ConsumerWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_expenseReportProvider);

    return _ReportScaffold(
      title: 'Expense Report',
      children: [
        async.when(
          loading: () => const Skeleton(height: 220, radius: AppRadius.lg),
          error: (_, _) => const ErrorState(compact: true),
          data: (r) => Column(
            children: [
              MetricGrid(metrics: [
                (label: 'Total', value: Fmt.money(r.total), color: null),
                (
                  label: 'Approved',
                  value: Fmt.money(r.approved),
                  color: AppColors.success
                ),
                (
                  label: 'Pending',
                  value: Fmt.money(r.pending),
                  color: AppColors.warning
                ),
                (
                  label: 'Rejected',
                  value: Fmt.money(r.rejected),
                  color: AppColors.error
                ),
              ]),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'By category'),
              AppCard(
                child: CategoryBars(
                  entries: [
                    for (final entry in r.byCategory.entries)
                      (label: entry.key.label, value: entry.value),
                  ],
                  valueFormatter: Fmt.money,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Six-month trend'),
              AppCard(child: TrendChart(points: r.trend)),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================== overview report ==

final _overviewProvider = FutureProvider.autoDispose<OverviewReport>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(reportRepositoryProvider).overview(
        session,
        month: ref.watch(reportMonthProvider),
        employeeId: ref.watch(reportEmployeeProvider) ??
            (session.isManager ? null : session.employee.id),
      );
});

class OverviewReportScreen extends ConsumerWidget {
  const OverviewReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_overviewProvider);

    return _ReportScaffold(
      title: 'Overview Report',
      children: [
        async.when(
          loading: () => const Skeleton(height: 300, radius: AppRadius.lg),
          error: (_, _) => const ErrorState(compact: true),
          data: (r) => Column(
            children: [
              const SectionHeader(title: 'Days'),
              MetricGrid(metrics: [
                (label: 'Working', value: '${r.workingDays}', color: null),
                (
                  label: 'Field',
                  value: '${r.fieldDays}',
                  color: AppColors.success
                ),
                (
                  label: 'Leave',
                  value: '${r.leaveDays}',
                  color: AppColors.warning
                ),
                (label: 'Non-field', value: '${r.nonFieldDays}', color: null),
              ]),
              const SizedBox(height: AppSpacing.section),

              const SectionHeader(title: 'Coverage'),
              MetricGrid(metrics: [
                (label: 'Visits', value: '${r.visits}', color: null),
                (label: 'Completed', value: '${r.completedVisits}', color: null),
                (
                  label: 'Hospitals covered',
                  value: '${r.hospitalCoverage}',
                  color: null
                ),
                (label: 'New clients', value: '${r.newClients}', color: null),
              ]),
              const SizedBox(height: AppSpacing.section),

              const SectionHeader(title: 'Commercial'),
              AppCard(
                child: Column(
                  children: [
                    KeyValueRow(label: 'Sales', value: Fmt.money(r.sales)),
                    KeyValueRow(label: 'Target', value: Fmt.money(r.target)),
                    KeyValueRow(
                      label: 'Achievement',
                      valueWidget: StatusBadge(
                        label: '${r.achievement.round()}%',
                        tone: r.achievement >= 75
                            ? StatusTone.success
                            : StatusTone.warning,
                        dense: true,
                      ),
                    ),
                    const AppDivider(),
                    KeyValueRow(
                        label: 'Expenses', value: Fmt.money(r.expenses)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
