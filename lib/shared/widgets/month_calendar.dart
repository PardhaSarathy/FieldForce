import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import 'primitives.dart';

/// How one day should look.
///
/// The screen decides what a day *means*; the calendar only knows how to paint
/// it. That split is what lets four screens share one grid — attendance, the
/// day plan, the expense claim and the tour plan all answer different
/// questions about a date and none of them needs its own calendar.
class CalendarDay {
  const CalendarDay({
    this.fill,
    this.ink,
    this.dot,
    this.onTap,
  });

  /// The disc behind the number. Null leaves the cell bare, which is what an
  /// ordinary day with nothing recorded against it should be.
  final Color? fill;

  /// The number's colour. Defaults to the ordinary body ink.
  final Color? ink;

  /// The small mark under the number.
  ///
  /// This is where the state actually lives. A tinted disc alone runs out of
  /// distinguishable values at about three — the dot carries the rest, and the
  /// legend under the grid names every colour, so the calendar never says
  /// anything by hue alone.
  final Color? dot;

  final VoidCallback? onTap;
}

/// A month, as seven columns of days.
///
/// **One calendar for the whole app.** There were four, each with its own
/// grid, its own cell, its own idea of how tall a row should be and its own
/// header. They drifted in every one of those respects — one used an aspect
/// ratio and clipped the dates at large text sizes, one drew rounded squares
/// while the rest drew circles, one put the month on the left with both arrows
/// bunched at the right. A calendar is the same object wherever it appears.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.dayOf,
    this.onPreviousMonth,
    this.onNextMonth,
    this.selected,
    this.legend = const [],
    this.footer,
  });

  final DateTime month;

  /// Called for every day of the month, 1-based.
  final CalendarDay Function(int day) dayOf;

  /// Month stepping. Omit either to hide that arrow — the tour plan cannot go
  /// forward past the month being planned, for instance.
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  final DateTime? selected;
  final List<CalendarLegendItem> legend;

  /// A line under the grid — a total, a count of what is still to do.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first, so `weekday` 1 needs no blanks in front of it.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final now = DateTime.now();

    // The row height comes from the text scale, never from an aspect ratio: a
    // seven-column grid has its width dictated by the screen, so an aspect
    // ratio decides the height for it and clips the date at large font sizes.
    final scale = MediaQuery.textScalerOf(context);
    final extent = scale.scale(AppTypography.bodySm.fontSize!) * 1.35 + 22;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: onPreviousMonth == null
                    ? null
                    : () {
                        AppHaptics.selection();
                        onPreviousMonth!();
                      },
              ),
              Expanded(
                child: Text(
                  Fmt.monthYear(month),
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextMonth == null
                    ? null
                    : () {
                        AppHaptics.selection();
                        onNextMonth!();
                      },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(label, style: AppTypography.overline),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              mainAxisExtent: extent,
            ),
            itemBuilder: (context, i) {
              if (i < leadingBlanks) return const SizedBox.shrink();
              final day = i - leadingBlanks + 1;
              final date = DateTime(month.year, month.month, day);

              return _DayCell(
                day: day,
                spec: dayOf(day),
                isToday: date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day,
                isSelected: selected != null &&
                    selected!.year == date.year &&
                    selected!.month == date.month &&
                    selected!.day == date.day,
              );
            },
          ),

          if (legend.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            CalendarLegend(items: legend),
          ],

          if (footer != null) ...[
            const AppDivider(height: AppSpacing.md),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// One day: a disc, a number, and a dot for what happened on it.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.spec,
    required this.isToday,
    required this.isSelected,
  });

  final int day;
  final CalendarDay spec;
  final bool isToday;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final ink = spec.ink ?? AppColors.textSecondary;

    return InkWell(
      onTap: spec.onTap,
      customBorder: const CircleBorder(),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? ink : spec.fill,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: AppColors.brand, width: 1.5)
              : null,
        ),
        // Scaled down rather than sized by arithmetic: the cell's width comes
        // from the screen and cannot grow, so this is the only behaviour that
        // survives a narrow phone at a large system font.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$day',
                style: AppTypography.bodySm.copyWith(
                  color: isSelected ? AppColors.textOnBrand : ink,
                  fontWeight:
                      isToday || isSelected || spec.dot != null
                          ? FontWeight.w700
                          : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              // Always laid out, drawn only when there is something to say —
              // otherwise the numbers on days with a dot sit higher than the
              // ones without, and the grid reads as misaligned.
              SizedBox(
                height: 5,
                child: spec.dot == null
                    ? null
                    : StatusDot(
                        color: isSelected ? Colors.white : spec.dot!,
                        size: 5,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One entry in a calendar's key.
class CalendarLegendItem {
  const CalendarLegendItem(this.color, this.label);

  final Color color;
  final String label;
}

/// The key under a calendar. Colour never carries meaning on its own here, so
/// wherever a grid uses dots this names every one of them.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key, required this.items});

  final List<CalendarLegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(color: item.color, size: 8),
              const SizedBox(width: AppSpacing.xs),
              Text(item.label, style: AppTypography.caption),
            ],
          ),
      ],
    );
  }
}
