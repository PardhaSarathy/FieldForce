import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/navigate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/repositories.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import '../../authentication/presentation/widgets/brand_mark.dart';
import '../../shell/presentation/app_shell.dart';

/// Manager home (§40, §79).
///
/// Ordered by what requires action, not by what is interesting. Exceptions come
/// first — pending approvals, people behind plan, unverified visits — because a
/// manager opening the app needs to know what is wrong, not what is normal.
/// Performance figures sit below that, and detail is always one tap away.
class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final dashboardAsync = ref.watch(managerDashboardProvider);
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(managerDashboardProvider);
            ref.invalidate(pendingApprovalsProvider);
          },
          child: dashboardAsync.when(
            loading: () => const LoadingState(message: 'Loading your team'),
            error: (_, _) => ErrorState(
              onRetry: () => ref.invalidate(managerDashboardProvider),
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.xxxl * 3,
              ),
              children: [
                _ManagerHeader(
                  name: session.employee.name.split(' ').first,
                  role: session.role.label,
                  territory: session.employee.territoryName,
                  unreadCount: unread,
                ),
                const SizedBox(height: AppSpacing.xl),
                ManagerTeamSections(data: data),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// The team half of a manager's home, without a header or a scroll view of
/// its own.
///
/// Split out so it can sit **under** the manager's own day on Home. An area
/// manager is a field person who also runs a team: they file their own day
/// plan, make their own calls and claim their own allowance, and none of that
/// was on their home screen — it opened straight onto the team. Both halves
/// are here now, in the order the day runs, and nothing was dropped from
/// either.
class ManagerTeamSections extends StatelessWidget {
  const ManagerTeamSections({super.key, required this.data});

  final ManagerDashboard data;

  /// Exceptions lead, because a manager opening the app needs to know what is
  /// wrong, not what is normal.
  static bool hasExceptions(ManagerDashboard d) =>
      d.pendingApprovals > 0 ||
      d.behindPlanCount > 0 ||
      d.unverifiedVisits > 0 ||
      (d.teamSize > 0 && d.presentToday < d.teamSize);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasExceptions(data)) ...[
          const SectionHeader(title: 'Needs your attention'),
          _ExceptionList(data: data),
          const SizedBox(height: AppSpacing.section),
        ],

        const SectionHeader(title: 'Team today'),
        _TeamTodayCard(data: data),
        const SizedBox(height: AppSpacing.section),

        SectionHeader(
          title: 'This month',
          actionLabel: 'Reports',
          onAction: () => navigateTo(context, Routes.reports),
        ),
        _MonthPerformance(data: data),
        const SizedBox(height: AppSpacing.section),

        const SectionHeader(title: 'Manage'),
        const _ManagerActions(),
      ],
    );
  }
}

class _ManagerHeader extends ConsumerWidget {
  const _ManagerHeader({
    required this.name,
    required this.role,
    required this.territory,
    required this.unreadCount,
  });

  final String name;
  final String role;
  final String territory;
  final int unreadCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Same top bar as the field Home: menu, brand, notifications.
        Row(
          children: [
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => openAppDrawer(ref),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CustomPaint(painter: BrandMarkPainter()),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Mr Sales',
                      style: AppTypography.titleMd.copyWith(
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.push(Routes.notifications),
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                backgroundColor: AppColors.error,
                child: const Icon(Icons.notifications_none),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Fmt.weekday(DateTime.now())} · $territory',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('${Fmt.greeting()}, $name', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.xxs),
              Text(role, style: AppTypography.bodySm),
            ],
          ),
        ),
      ],
    );
  }
}

/// Exceptions rendered as actionable rows. Each states a number, a plain
/// description, and goes somewhere useful.
class _ExceptionList extends StatelessWidget {
  const _ExceptionList({required this.data});

  final ManagerDashboard data;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (data.pendingApprovals > 0) {
      final breakdown = data.pendingByKind.entries
          .map((e) => '${e.value} ${e.key.label.toLowerCase()}')
          .join(' · ');
      rows.add(
        _ExceptionRow(
          icon: Icons.pending_actions_outlined,
          tone: StatusTone.warning,
          count: '${data.pendingApprovals}',
          title: 'Awaiting your approval',
          subtitle: breakdown,
          onTap: () => context.push(Routes.approvals),
        ),
      );
    }

    if (data.behindPlanCount > 0) {
      rows.add(
        _ExceptionRow(
          icon: Icons.trending_down,
          tone: StatusTone.error,
          count: '${data.behindPlanCount}',
          title: 'Team members behind plan',
          subtitle:
              'Completion is below the expected pace for this time of day',
          onTap: () => navigateTo(context, Routes.team),
        ),
      );
    }

    if (data.teamSize > 0 && data.presentToday < data.teamSize) {
      final absent = data.teamSize - data.presentToday;
      rows.add(
        _ExceptionRow(
          icon: Icons.person_off_outlined,
          tone: StatusTone.info,
          count: '$absent',
          title: 'No field activity recorded today',
          subtitle: 'Out of ${data.teamSize} team members',
          onTap: () => context.push(Routes.teamActivity),
        ),
      );
    }

    if (data.unverifiedVisits > 0) {
      rows.add(
        _ExceptionRow(
          icon: Icons.location_off_outlined,
          tone: StatusTone.warning,
          count: '${data.unverifiedVisits}',
          title: 'Visits completed out of range',
          subtitle: 'Location could not be verified against the client address',
          onTap: () => context.push(Routes.teamActivity),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpacing.cardPadding),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ExceptionRow extends StatelessWidget {
  const _ExceptionRow({
    required this.icon,
    required this.tone,
    required this.count,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final StatusTone tone;
  final String count;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: tone.foreground),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        count,
                        style: AppTypography.titleMd.copyWith(
                          color: tone.foreground,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          title,
                          style: AppTypography.titleSm,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: AppSizes.iconMd,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamTodayCard extends StatelessWidget {
  const _TeamTodayCard({required this.data});

  final ManagerDashboard data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => navigateTo(context, Routes.team),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Team size',
                  value: '${data.teamSize}',
                ),
              ),
              _VDivider(),
              Expanded(
                child: _MiniMetric(
                  label: 'Active today',
                  value: '${data.presentToday}',
                  valueColor: AppColors.success,
                ),
              ),
              _VDivider(),
              Expanded(
                child: _MiniMetric(
                  label: 'Visits done',
                  value:
                      '${data.visitsCompleted}'
                      ' / ${data.visitsPlanned}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppProgressBar(
            value: data.visitsPlanned == 0
                ? 0
                : data.visitsCompleted / data.visitsPlanned,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  data.visitGap > 0
                      ? '${Fmt.count(data.visitGap, 'visit')} still to complete today'
                      : 'All planned visits complete',
                  style: AppTypography.caption,
                ),
              ),
              Text(
                'View team',
                style: AppTypography.caption.copyWith(color: AppColors.brand),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthPerformance extends StatelessWidget {
  const _MonthPerformance({required this.data});

  final ManagerDashboard data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Sales',
                value: Fmt.moneyCompact(data.sales),
                footnote: 'vs ${Fmt.moneyCompact(data.target)} target',
                accent: '${data.achievement.round()}%',
                accentTone: data.achievement >= 75
                    ? StatusTone.success
                    : StatusTone.warning,
                onTap: () => context.push(Routes.salesReport),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MetricCard(
                label: 'Orders',
                value: '${data.orderCount}',
                footnote: 'placed this month',
                onTap: () => context.push(Routes.orders),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _MetricCard(
          label: 'Team expenses',
          value: Fmt.money(data.expenseTotal),
          footnote: 'submitted this month',
          wide: true,
          onTap: () => context.push(Routes.expenseReport),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.footnote,
    this.accent,
    this.accentTone = StatusTone.brand,
    this.onTap,
    this.wide = false,
  });

  final String label;
  final String value;
  final String? footnote;
  final String? accent;
  final StatusTone accentTone;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(), style: AppTypography.overline),
              ),
              if (accent != null)
                StatusBadge(label: accent!, tone: accentTone, dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.metricSm),
          if (footnote != null) ...[
            const SizedBox(height: 2),
            Text(footnote!, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.metricSm.copyWith(color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption, textAlign: TextAlign.center),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: AppColors.border);
}

class _ManagerActions extends StatelessWidget {
  const _ManagerActions();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.checklist_outlined, 'Approvals', Routes.approvals),
      (Icons.flag_outlined, 'Targets', Routes.targetAssignment),
      // The list, not the form. It opened the assignment form, so a manager
      // could give work out and had nowhere to see what they had given.
      (Icons.assignment_outlined, 'Tasks', Routes.assignedTasks),
      (Icons.map_outlined, 'Team map', Routes.teamMap),
      (Icons.payments_outlined, 'Rates', Routes.rateAssignment),
      (Icons.insights_outlined, 'Performance', Routes.teamPerformance),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      // Row height from the text, not from an aspect ratio.
      //
      // `childAspectRatio: 1.15` derives the tile's height from its *width*,
      // so the label has whatever room the column happens to leave — and at a
      // large text size "Performance" wraps to two lines and overflows the
      // tile. This is the same mistake the calendars made before they were
      // merged, and it has the same fix: measure the content.
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisExtent:
            22 +
            AppSpacing.sm +
            MediaQuery.textScalerOf(context).scale(
                  AppTypography.caption.fontSize ?? 12,
                ) *
                2.6 +
            AppSpacing.md,
        children: [
          for (final (icon, label, route) in items)
            InkWell(
              onTap: () => context.push(route),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: AppColors.brand),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
