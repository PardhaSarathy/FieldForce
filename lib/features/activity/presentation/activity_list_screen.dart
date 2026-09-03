import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../features/shell/presentation/app_shell.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_glow.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/states.dart';
import 'widgets/activity_card.dart';

/// Filters offered above the activity list (§17).
enum ActivityFilter {
  all('All'),
  upcoming('Upcoming'),
  planned('Planned'),
  completed('Completed'),
  missed('Missed');

  const ActivityFilter(this.label);
  final String label;

  bool matches(Activity a) => switch (this) {
    all => true,
    upcoming =>
      a.status == ActivityStatus.upcoming ||
          a.status == ActivityStatus.inProgress,
    planned => a.status == ActivityStatus.planned,
    completed => a.status == ActivityStatus.completed,
    missed => a.status == ActivityStatus.missed,
  };
}

final _activityFilterProvider = StateProvider.autoDispose<ActivityFilter>(
  (ref) => ActivityFilter.all,
);

final _activityDateProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime.now(),
);

final _activityListProvider = FutureProvider.autoDispose<List<Activity>>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  final date = ref.watch(_activityDateProvider);
  ref.watch(dataRevisionProvider);

  return ref
      .watch(activityRepositoryProvider)
      .list(
        session,
        date: date,
        employeeId: session.isManager ? null : session.employee.id,
      );
});

class ActivityListScreen extends ConsumerWidget {
  const ActivityListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_activityFilterProvider);
    final date = ref.watch(_activityDateProvider);
    final listAsync = ref.watch(_activityListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My Activity'),
        leading: const DrawerMenuButton(),
        actions: [
          IconButton(
            tooltip: 'Calendar',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push(Routes.calendar),
          ),
        ],
      ),
      // Recording a call is the reason a rep opens this screen, so the action
      // is on it rather than only in the shell's "+" sheet.
      floatingActionButton: AppFab(
        onPressed: () => context.push(Routes.addActivity),
        icon: Icons.add,
        label: 'Add New Activity',
      ),
      body: Column(
        children: [
          _DateStrip(
            selected: date,
            onSelected: (d) =>
                ref.read(_activityDateProvider.notifier).state = d,
          ),
          const SizedBox(height: AppSpacing.md),
          listAsync.maybeWhen(
            data: (items) => FilterChipBar<ActivityFilter>(
              options: ActivityFilter.values,
              selected: filter,
              labelOf: (f) => f.label,
              countOf: (f) => f == ActivityFilter.all
                  ? null
                  : items.where(f.matches).length,
              onSelected: (f) =>
                  ref.read(_activityFilterProvider.notifier).state = f,
            ),
            orElse: () => FilterChipBar<ActivityFilter>(
              options: ActivityFilter.values,
              selected: filter,
              labelOf: (f) => f.label,
              onSelected: (f) =>
                  ref.read(_activityFilterProvider.notifier).state = f,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: listAsync.when(
              loading: () => const SkeletonList(),
              error: (_, _) => ErrorState(
                onRetry: () => ref.invalidate(_activityListProvider),
              ),
              data: (items) {
                final filtered = items.where(filter.matches).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_activityListProvider),
                    child: ListView(
                      children: [
                        EmptyState(
                          icon: Icons.event_note_outlined,
                          title: items.isEmpty
                              ? 'Nothing planned for this day'
                              : 'No ${filter.label.toLowerCase()} activities',
                          message: items.isEmpty
                              ? 'Add an activity to build your plan for '
                                    '${Fmt.relativeDay(date).toLowerCase()}.'
                              : 'Try a different filter to see other visits.',
                          actionLabel: items.isEmpty ? 'Add activity' : null,
                          onAction: () => context.push(Routes.addActivity),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_activityListProvider),
                  child: ListView.separated(
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
                      child: ActivityCard(
                        activity: filtered[i],
                        showEmployee: ref.watch(sessionProvider).isManager,
                      ),
                    ),
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

/// Horizontal week strip. Faster than opening a picker for the near-term
/// navigation that dominates day-to-day use; the calendar handles the rest.
class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelected});

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = [
      for (var i = -3; i <= 6; i++)
        DateTime(today.year, today.month, today.day + i),
    ];

    // On the wash: the day cells are white cards and read as cards against
    // it, where on a white strip they needed their own borders to exist.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    Fmt.relativeDay(selected),
                    style: AppTypography.titleMd,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    Fmt.date(selected),
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => onSelected(DateTime.now()),
                  child: const Text('Today'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final day = days[i];
                final isSelected = _sameDay(day, selected);
                final isToday = _sameDay(day, today);

                return GestureDetector(
                  onTap: () => onSelected(day),
                  child: Container(
                    width: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? null : AppColors.surface,
                      gradient: isSelected
                          ? AppGlow.fill(AppColors.brand)
                          : null,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : isToday
                            ? AppColors.brand.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                      boxShadow: isSelected
                          ? AppGlow.halo(AppColors.brand, 50, strength: 0.6)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          Fmt.weekdayShort(day).toUpperCase(),
                          style: AppTypography.overline.copyWith(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white70
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${day.day}',
                          style: AppTypography.titleMd.copyWith(
                            color: isSelected
                                ? AppColors.textOnBrand
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
