import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_glow.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

// =============================================================== calendar ==

final _calendarMonthProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final _selectedDateProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime.now(),
);

final _monthActivitiesProvider = FutureProvider.autoDispose<List<Activity>>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  final month = ref.watch(_calendarMonthProvider);
  ref.watch(dataRevisionProvider);

  return ref
      .watch(activityRepositoryProvider)
      .list(
        session,
        from: DateTime(month.year, month.month, 1),
        to: DateTime(month.year, month.month + 1, 0),
        employeeId: session.isManager ? null : session.employee.id,
      );
});

/// Calendar (§24). Aggregates visits, travel, leave and holidays into one
/// month view, with the selected day's agenda beneath it.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_calendarMonthProvider);
    final selected = ref.watch(_selectedDateProvider);
    final activitiesAsync = ref.watch(_monthActivitiesProvider);
    final holidaysAsync = ref.watch(_calendarHolidaysProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () =>
                          ref.read(_calendarMonthProvider.notifier).state =
                              DateTime(month.year, month.month - 1),
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
                      onPressed: () =>
                          ref.read(_calendarMonthProvider.notifier).state =
                              DateTime(month.year, month.month + 1),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _CalendarGrid(
                  month: month,
                  selected: selected,
                  activities: activitiesAsync.valueOrNull ?? const [],
                  holidays: (holidaysAsync.valueOrNull ?? const [])
                      .map((h) => h.date)
                      .toList(),
                  onSelect: (d) =>
                      ref.read(_selectedDateProvider.notifier).state = d,
                ),
                const AppDivider(),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: const [
                    _Legend(color: AppColors.brand, label: 'Visits'),
                    _Legend(color: AppColors.success, label: 'Completed'),
                    _Legend(color: AppColors.error, label: 'Missed'),
                    _Legend(color: AppColors.info, label: 'Holiday'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          SectionHeader(title: Fmt.relativeDay(selected)),
          activitiesAsync.when(
            loading: () => const Skeleton(height: 80, radius: AppRadius.lg),
            error: (_, _) => const ErrorState(compact: true),
            data: (all) {
              final day = all
                  .where((a) => _sameDay(a.scheduledStart, selected))
                  .toList();

              if (day.isEmpty) {
                return const AppCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.event_available_outlined,
                    title: 'Nothing scheduled',
                    message: 'No visits or events on this day.',
                  ),
                );
              }

              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < day.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: SizedBox(
                          width: 52,
                          child: Text(
                            Fmt.time(day[i].scheduledStart),
                            style: AppTypography.caption,
                          ),
                        ),
                        title: Text(
                          day[i].clientName,
                          style: AppTypography.titleSm,
                        ),
                        subtitle: Text(
                          day[i].clientSpecialty ?? day[i].clientType.label,
                          style: AppTypography.caption,
                        ),
                        trailing: StatusBadge.activity(
                          day[i].status,
                          dense: true,
                        ),
                        onTap: () =>
                            context.push(Routes.activityDetail(day[i].id)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

final _calendarHolidaysProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(hrRepositoryProvider).holidays(DateTime.now().year),
);

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.selected,
    required this.activities,
    required this.holidays,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final List<Activity> activities;
  final List<DateTime> holidays;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: [
            for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(label, style: AppTypography.overline),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // See the note on the attendance calendar: a seven-column grid cannot
        // take its height from an aspect ratio without clipping at large text
        // sizes.
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio:
              1 /
              ((MediaQuery.textScalerOf(
                            context,
                          ).scale(AppTypography.bodySm.fontSize!) *
                          1.35 +
                      14) /
                  ((MediaQuery.sizeOf(context).width -
                          AppSpacing.screenH * 2 -
                          AppSpacing.cardPadding * 2 -
                          AppSpacing.xs * 6) /
                      7)),
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              () {
                final date = DateTime(month.year, month.month, day);
                final dayActivities = activities
                    .where((a) => _sameDay(a.scheduledStart, date))
                    .toList();

                return _CalendarCell(
                  date: date,
                  isSelected: _sameDay(date, selected),
                  isToday: _sameDay(date, today),
                  isHoliday: holidays.any((h) => _sameDay(h, date)),
                  activityCount: dayActivities.length,
                  hasMissed: dayActivities.any(
                    (a) => a.status == ActivityStatus.missed,
                  ),
                  allComplete:
                      dayActivities.isNotEmpty &&
                      dayActivities.every(
                        (a) => a.status == ActivityStatus.completed,
                      ),
                  onTap: () => onSelect(date),
                );
              }(),
          ],
        ),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.isHoliday,
    required this.activityCount,
    required this.hasMissed,
    required this.allComplete,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isHoliday;
  final int activityCount;
  final bool hasMissed;
  final bool allComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = isHoliday
        ? AppColors.info
        : hasMissed
        ? AppColors.error
        : allComplete
        ? AppColors.success
        : AppColors.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected ? AppGlow.fill(AppColors.brand) : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.brand, width: 1.2)
              : null,
          boxShadow: isSelected
              ? AppGlow.halo(AppColors.brand, 40, strength: 0.6)
              : null,
        ),
        // Same reasoning as the attendance calendar: a seven-column cell has a
        // fixed width, so its content scales down rather than overflowing.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${date.day}',
                style: AppTypography.bodySm.copyWith(
                  color: isSelected
                      ? AppColors.textOnBrand
                      : AppColors.textPrimary,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 3),
              if (activityCount > 0 || isHoliday)
                StatusDot(color: isSelected ? Colors.white : dotColor, size: 5)
              else
                const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      StatusDot(color: color, size: 7),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: AppTypography.caption),
    ],
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
