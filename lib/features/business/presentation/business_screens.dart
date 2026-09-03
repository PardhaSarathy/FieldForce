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
import '../../../shared/models/business.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/charts.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

final _monthProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final _salesReportProvider = FutureProvider.autoDispose<SalesReport>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  final month = ref.watch(_monthProvider);
  return ref
      .watch(reportRepositoryProvider)
      .salesReport(
        session,
        year: month.year,
        employeeId: session.isManager ? null : session.employee.id,
      );
});

final _targetReportProvider = FutureProvider.autoDispose<TargetReport>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  return ref
      .watch(reportRepositoryProvider)
      .targetReport(
        session,
        month: ref.watch(_monthProvider),
        employeeId: session.isManager ? null : session.employee.id,
      );
});

final _ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(businessRepositoryProvider)
      .orders(
        session,
        employeeId: session.isManager ? null : session.employee.id,
      );
});

/// Business dashboard (§27). Three numbers and three doors — sales, targets,
/// orders. The spec says not to overdesign this, and it is right: it is a
/// junction, not a destination.
class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_monthProvider);
    final targetAsync = ref.watch(_targetReportProvider);
    final ordersAsync = ref.watch(_ordersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Business is opened from Home's quick actions rather than a tab, so it
      // needs the back button an implied leading gives it.
      appBar: AppBar(title: const Text('Business')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_targetReportProvider);
          ref.invalidate(_ordersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xxxl * 3,
          ),
          children: [
            _MonthPicker(
              month: month,
              onChanged: (m) => ref.read(_monthProvider.notifier).state = m,
            ),
            const SizedBox(height: AppSpacing.lg),

            targetAsync.when(
              loading: () => const Skeleton(height: 200, radius: AppRadius.lg),
              error: (_, _) => const ErrorState(compact: true),
              data: (report) => AppCard(
                child: Column(
                  children: [
                    AchievementRing(percent: report.achievement),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _Figure(
                            label: 'Achieved',
                            value: Fmt.money(report.achieved),
                            color: AppColors.brand,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _Figure(
                            label: 'Target',
                            value: Fmt.money(report.target),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _Figure(
                            label: 'Gap',
                            value: Fmt.money(report.gap),
                            color: report.gap > 0
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),

            const SectionHeader(title: 'Explore'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.trending_up,
                    title: 'Sales',
                    subtitle: 'Monthly performance and product mix',
                    route: Routes.sales,
                  ),
                  const Divider(height: 1, indent: AppSpacing.cardPadding),
                  _NavRow(
                    icon: Icons.flag_outlined,
                    title: 'Targets',
                    subtitle: 'Target versus actual by month',
                    route: Routes.targets,
                  ),
                  const Divider(height: 1, indent: AppSpacing.cardPadding),
                  _NavRow(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Orders',
                    subtitle: ordersAsync.valueOrNull == null
                        ? 'Capture and track client orders'
                        : '${ordersAsync.value!.length} orders · '
                              '${ordersAsync.value!.where((o) => o.status.awaitsDecision).length} pending',
                    route: Routes.orders,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),

            SectionHeader(
              title: 'Recent orders',
              actionLabel: 'See all',
              onAction: () => context.push(Routes.orders),
            ),
            ordersAsync.when(
              loading: () => const Skeleton(height: 90, radius: AppRadius.lg),
              error: (_, _) => const SizedBox.shrink(),
              data: (orders) => orders.isEmpty
                  ? const AppCard(
                      child: EmptyState(
                        compact: true,
                        icon: Icons.shopping_bag_outlined,
                        title: 'No orders yet',
                        message: 'Orders you capture will appear here.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final order in orders.take(3))
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.cardGap,
                            ),
                            child: OrderCard(order: order),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: AppTypography.titleMd.copyWith(color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 2),
      Text(label, style: AppTypography.caption),
    ],
  );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(icon: icon),
      title: Text(title, style: AppTypography.titleMd),
      subtitle: Text(subtitle, style: AppTypography.caption),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () => context.push(route),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canForward = month.isBefore(DateTime(now.year, now.month));

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: Text(
              Fmt.monthYear(month),
              textAlign: TextAlign.center,
              style: AppTypography.titleMd,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canForward
                ? () => onChanged(DateTime(month.year, month.month + 1))
                : null,
          ),
        ],
      ),
    );
  }
}

// ================================================================== sales ==

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_monthProvider);
    final async = ref.watch(_salesReportProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Sales')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) =>
            ErrorState(onRetry: () => ref.invalidate(_salesReportProvider)),
        data: (report) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            _MonthPicker(
              month: month,
              onChanged: (m) => ref.read(_monthProvider.notifier).state = m,
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(
                  child: _SmallMetric(
                    label: 'Total sales',
                    value: Fmt.money(report.total),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SmallMetric(
                    label: 'Achievement',
                    value: '${report.achievement.round()}%',
                    color: report.achievement >= 75
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _SmallMetric(
                    label: 'Primary',
                    value: Fmt.moneyCompact(report.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SmallMetric(
                    label: 'Secondary',
                    value: Fmt.moneyCompact(report.secondary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.section),
            SectionHeader(title: 'Sales vs target · ${month.year}'),
            AppCard(
              child: TrendChart(points: report.monthly, showComparison: true),
            ),

            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'By product'),
            AppCard(
              child: CategoryBars(
                entries: [
                  for (final p in report.byProduct)
                    (label: p.productName, value: p.amount),
                ],
                valueFormatter: Fmt.moneyCompact,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.overline),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.metricSm.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ================================================================ targets ==

class TargetsScreen extends ConsumerWidget {
  const TargetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_monthProvider);
    final async = ref.watch(_targetReportProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Targets')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (report) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            _MonthPicker(
              month: month,
              onChanged: (m) => ref.read(_monthProvider.notifier).state = m,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                children: [
                  AchievementRing(percent: report.achievement),
                  const SizedBox(height: AppSpacing.lg),
                  KeyValueRow(label: 'Target', value: Fmt.money(report.target)),
                  KeyValueRow(
                    label: 'Achieved',
                    value: Fmt.money(report.achieved),
                  ),
                  KeyValueRow(label: 'Gap', value: Fmt.money(report.gap)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Six-month trend'),
            AppCard(
              child: TrendChart(
                points: report.trend,
                showComparison: true,
                valueLabel: 'Achieved',
              ),
            ),
            if (report.rows.length > 1) ...[
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'By employee'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < report.rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _TargetRow(target: report.rows[i]),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.target});

  final Target target;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(target.employeeName, style: AppTypography.titleSm),
              ),
              // The rung, not a bare number: "Ahead · 82%" says where this
              // employee stands, where "82%" leaves the reader to work it out.
              Flexible(
                child: TierBadge(
                  tier: target.tier,
                  percent: target.achievementPercent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(
            value: target.achievementPercent / 100,
            color: target.tier.ink,
            height: 5,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                Fmt.moneyCompact(target.achievedAmount),
                style: AppTypography.caption,
              ),
              Text(
                ' of ${Fmt.moneyCompact(target.targetAmount)}',
                style: AppTypography.caption,
              ),
              const Spacer(),
              if (target.areaName != null)
                Text(target.areaName!, style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================= orders ==

enum OrderFilter {
  all('All'),
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const OrderFilter(this.label);
  final String label;

  bool matches(Order o) => switch (this) {
    all => true,
    pending => o.status.awaitsDecision,
    approved => o.status == ApprovalStatus.approved,
    rejected => o.status == ApprovalStatus.rejected,
  };
}

final _orderFilterProvider = StateProvider.autoDispose<OrderFilter>(
  (ref) => OrderFilter.all,
);

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_orderFilterProvider);
    final async = ref.watch(_ordersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Orders')),
      floatingActionButton: AppFab(
        onPressed: () => context.push(Routes.newOrder),
        icon: Icons.add,
        label: 'New order',
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          FilterChipBar<OrderFilter>(
            options: OrderFilter.values,
            selected: filter,
            labelOf: (f) => f.label,
            countOf: (f) => f == OrderFilter.all
                ? null
                : async.valueOrNull?.where(f.matches).length,
            onSelected: (f) =>
                ref.read(_orderFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) => const ErrorState(),
              data: (orders) {
                final filtered = orders.where(filter.matches).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'No orders',
                    message: 'Capture orders during your client visits.',
                    actionLabel: 'Create an order',
                    onAction: () => context.push(Routes.newOrder),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    0,
                    AppSpacing.screenH,
                    AppSpacing.xxxl * 3,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) => Arrive.staggered(
                    index: i,
                    child: OrderCard(order: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.orderDetail(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber, style: AppTypography.titleMd),
                    const SizedBox(height: 2),
                    Text(
                      order.clientName,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.money(order.grandTotal),
                    style: AppTypography.numeric,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  StatusBadge.approval(order.status, dense: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${order.lineCount} products · ${order.totalUnits} units',
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(Fmt.dateShort(order.date), style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }
}
