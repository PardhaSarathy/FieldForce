import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/month_calendar.dart';
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
          MonthCalendar(
            month: month,
            selected: selected,
            onPreviousMonth: () =>
                ref.read(_calendarMonthProvider.notifier).state =
                    DateTime(month.year, month.month - 1),
            onNextMonth: () =>
                ref.read(_calendarMonthProvider.notifier).state =
                    DateTime(month.year, month.month + 1),
            dayOf: (day) {
              final date = DateTime(month.year, month.month, day);
              final dayActivities = (activitiesAsync.valueOrNull ?? const [])
                  .where((a) => _sameDay(a.scheduledStart, date))
                  .toList();
              // Sunday is the week off everywhere in this app, so it wears
              // the same orange a company holiday does. A day the rep worked
              // anyway outranks it — the calendar has to agree with the
              // visits it is derived from.
              final isOff = date.weekday == DateTime.sunday ||
                  (holidaysAsync.valueOrNull ?? const [])
                      .any((h) => _sameDay(h.date, date));

              // The dot carries the state; the disc only says there is
              // something here at all.
              final dot = isOff && dayActivities.isEmpty
                  ? AppColors.calendarOff
                  : dayActivities.isEmpty
                  ? null
                  : dayActivities.any((a) => a.status == ActivityStatus.missed)
                  ? AppColors.calendarProblem
                  : dayActivities
                      .every((a) => a.status == ActivityStatus.completed)
                  ? AppColors.calendarDone
                  : AppColors.calendarPlanned;

              return CalendarDay(
                fill: dot?.withValues(alpha: 0.12),
                ink: dot ?? AppColors.textSecondary,
                dot: dot,
                onTap: () =>
                    ref.read(_selectedDateProvider.notifier).state = date,
              );
            },
            legend: const [
              CalendarLegendItem(AppColors.calendarPlanned, 'Planned'),
              CalendarLegendItem(AppColors.calendarDone, 'Completed'),
              CalendarLegendItem(AppColors.calendarProblem, 'Missed'),
              CalendarLegendItem(AppColors.calendarOff, 'Sunday / holiday'),
            ],
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




bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
