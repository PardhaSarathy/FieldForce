/// Expenses (§22), as a month of declared days rather than a list of receipts.
///
/// Three rules shape every screen here, and all three came from the field:
///
/// * **A claim hangs off a worked day.** No intimation, no claim — enforced at
///   the repository so there is one answer to "can this be claimed".
/// * **The allowance is flat.** ₹250 a worked day whatever the distance, so
///   the ordinary day is a confirmation rather than a calculation. Anything
///   above it needs a bill and a reason; the allowance itself needs neither.
/// * **The month goes in one piece, and never shuts.** The claim is submitted
///   once, after the month has ended and every day in it has been answered —
///   the same shape as the tour plan, because an approver looking at a month
///   in instalments is not looking at the month. And it still never shuts: a
///   day remembered in November can be claimed against September and sent on
///   its own, which is what stops a rep guessing a figure rather than losing
///   the day.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/field_ops.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/month_calendar.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';


// ===========================================================================
// The month
// ===========================================================================

/// The month a day is selected in, so the calendar and the list agree.
///
/// Null until the rep picks one. Not auto-disposed with the screen: stepping
/// into a day and coming back should return to the day you were looking at.
final claimSelectedDayProvider = StateProvider<DateTime?>((ref) => null);

/// Every day the rep declared this month, and what is claimed against each.
class ExpenseClaimScreen extends ConsumerStatefulWidget {
  const ExpenseClaimScreen({super.key});

  @override
  ConsumerState<ExpenseClaimScreen> createState() => _ExpenseClaimScreenState();
}

class _ExpenseClaimScreenState extends ConsumerState<ExpenseClaimScreen> {
  /// One key per rendered day, so the calendar can scroll the list to the date
  /// it was tapped on. This is the "coordinated" half: a calendar that only
  /// paints state is a picture, and the rep still has to hunt for the row.
  final _rowKeys = <String, GlobalKey>{};

  Future<void> _revealDay(DateTime date) async {
    ref.read(claimSelectedDayProvider.notifier).state = date;
    AppHaptics.selection();

    // Let the selection paint before scrolling, or `ensureVisible` measures
    // the row at its old position and stops short of it.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // The row's own context, not this State's — it is fetched fresh after the
    // frame, and the row may have been rebuilt away in the meantime.
    final rowContext = _rowKeys[isoDay(date)]?.currentContext;
    if (rowContext == null || !rowContext.mounted) return;
    await Scrollable.ensureVisible(
      rowContext,
      alignment: 0.25,
      duration: AppMotion.slow,
      curve: AppMotion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(claimMonthProvider);
    final async = ref.watch(claimMonthDaysProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Expenses')),
      bottomNavigationBar: async.maybeWhen(
        data: (days) {
          final gate = claimGate(
            days: days,
            month: month,
            now: DateTime.now(),
          );
          if (gate == ClaimGate.nothingToSend) return null;

          final open = days.where((d) => d.isOpen).length;
          // Disabled, not hidden — and it always says why. A month-level
          // control that vanishes for most of the month reads as a bug; one
          // that sits there greyed with "September is still running" under it
          // teaches the rule in the only place the rule matters.
          final blocker = switch (gate) {
            ClaimGate.monthRunning =>
              '${Fmt.monthName(month)} is still running. The claim goes as one '
                  'month, on the 1st.',
            ClaimGate.daysOpen =>
              '${Fmt.count(open, 'day')} still to confirm.',
            _ => null,
          };

          return BottomActionBar(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    label: 'Submit ${Fmt.monthYear(month)}',
                    icon: Icons.send_rounded,
                    onPressed: blocker == null
                        ? () => _submitMonth(context, ref, month)
                        : null,
                  ),
                  if (blocker != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      blocker,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(height: 1.35),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading your month'),
        error: (_, _) => ErrorState(
          onRetry: () => ref.invalidate(claimMonthDaysProvider),
        ),
        data: (days) {
          final open = days.where((d) => d.isOpen).toList();
          final allowance = ref.watch(dailyAllowanceProvider).valueOrNull;
          _rowKeys.removeWhere(
            (k, _) => !days.any((d) => isoDay(d.date) == k),
          );

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(claimMonthDaysProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                0,
                AppSpacing.screenH,
                AppSpacing.xxxl * 2,
              ),
              children: [
                // The month at a glance, where a summary card used to sit.
                //
                // The card said what the calendar shows — a total, a count of
                // open days — but said it in prose, so finding *which* days
                // were open meant scrolling the list and reading every row.
                // A month has thirty cells; it fits in the space the sentence
                // took.
                Arrive(
                  child: _ClaimCalendar(
                    month: month,
                    days: days,
                    onPick: _revealDay,
                  ),
                ),

                if (open.isNotEmpty && allowance != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Arrive(
                    delay: AppMotion.staggerFor(1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PrimaryButton(
                          label:
                              'Confirm all ${Fmt.count(open.length, 'standard day')}',
                          icon: Icons.done_all_rounded,
                          small: true,
                          onPressed: () =>
                              _confirmAll(context, ref, open, allowance),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Adds ${Fmt.money(allowance)} for each. Days where '
                          'you spent more stay open for you to fill in.',
                          style: AppTypography.caption.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.section),

                if (days.isEmpty)
                  Arrive(
                    delay: AppMotion.staggerFor(2),
                    child: AppCard(
                      child: EmptyState(
                        compact: true,
                        icon: Icons.event_busy_outlined,
                        title: 'No days declared',
                        message: 'You can only claim for a day you filed a '
                            'day plan for. Nothing was filed this month.',
                      ),
                    ),
                  ),

                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.cardGap),
                  Arrive.staggered(
                    index: i + 2,
                    child: _DayRow(
                      key: _rowKeys.putIfAbsent(
                        isoDay(days[i].date),
                        GlobalKey.new,
                      ),
                      day: days[i],
                    ),
                  ),
                ],

                // The footnote it always was. It sat at the top inside the
                // summary card, above everything, which is a strange place
                // for a reassurance nobody needs until they have scrolled to
                // the end and found a day missing.
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_open_outlined,
                      size: AppSizes.iconSm,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'No cut-off. A day you missed can be claimed later, '
                        'even after this month is paid.',
                        style: AppTypography.caption.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) async {
    final go = await showConfirmDialog(
      context,
      title: 'Submit ${Fmt.monthYear(month)}?',
      message: 'The whole month goes to your manager together. If you '
          'remember a day afterwards you can still claim it — it goes on its '
          'own, after this one.',
      confirmLabel: 'Submit',
      cancelLabel: 'Not yet',
    );
    if (!go || !context.mounted) return;

    final session = ref.read(sessionProvider);
    final sent = await ref
        .read(expenseRepositoryProvider)
        .submitMonth(session, month);

    if (!context.mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${Fmt.count(sent, 'claim')} sent for approval. You can still add '
          'days you missed.',
        ),
      ),
    );
  }

  Future<void> _confirmAll(
    BuildContext context,
    WidgetRef ref,
    List<ClaimDay> open,
    double allowance,
  ) async {
    final go = await showConfirmDialog(
      context,
      title: 'Confirm ${Fmt.count(open.length, 'day')}?',
      message: '${Fmt.money(allowance * open.length)} will be added to this '
          "month's claim — ${Fmt.money(allowance)} for each day.",
      confirmLabel: 'Confirm all',
      cancelLabel: 'Not yet',
    );
    if (!go || !context.mounted) return;

    final session = ref.read(sessionProvider);
    final added = await ref
        .read(expenseRepositoryProvider)
        .confirmStandardDays(session, open);

    if (!context.mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${Fmt.count(added, 'day')} claimed.')),
    );
  }
}

/// The month, as a calendar.
///
/// Two jobs, and it has to do both or it is decoration. It **shows** where
/// every day of the month stands — declared or not, claimed or open, approved
/// or rejected — and it **drives** the list below: tapping a date selects that
/// day and scrolls its row into view. A calendar that only paints state leaves
/// the rep scrolling to find the day they just looked at.
class _ClaimCalendar extends ConsumerWidget {
  const _ClaimCalendar({
    required this.month,
    required this.days,
    required this.onPick,
  });

  final DateTime month;
  final List<ClaimDay> days;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byDay = {for (final d in days) d.date.day: d};
    final claimed = days.fold<double>(0, (sum, d) => sum + d.claimed);
    final open = days.where((d) => d.isOpen).length;
    final now = DateTime.now();

    void step(int delta) {
      // The selection belongs to the month it was made in, so it clears when
      // the month does — otherwise stepping to August leaves 3 September
      // highlighted on a grid that no longer contains it.
      ref.read(claimSelectedDayProvider.notifier).state = null;
      ref.read(claimMonthProvider.notifier).state =
          DateTime(month.year, month.month + delta);
    }

    return MonthCalendar(
      month: month,
      selected: ref.watch(claimSelectedDayProvider),
      onPreviousMonth: () => step(-1),
      // Forward stops at the current month: there is nothing to claim against
      // a day that has not happened.
      onNextMonth: month.isBefore(DateTime(now.year, now.month))
          ? () => step(1)
          : null,
      dayOf: (day) {
        final d = byDay[day];
        if (d == null) return const CalendarDay();

        // Four colours, one meaning each. An excess used to have its own
        // amber here, which collided with the amber a leave day wears — the
        // row already flags "above allowance" in words, and the calendar's job
        // is where a day *stands*, not how much it cost.
        //
        // A day with no intimation is red, the same red attendance paints an
        // absence: it is not a quiet blank, it is a day that can never be
        // claimed, and the rep has to be able to find it.
        final ink = d.kind == DayKind.notDeclared
            ? AppColors.calendarProblem
            : !d.claimable
            ? AppColors.calendarOff
            : d.isOpen
            ? AppColors.calendarPlanned
            : switch (d.status) {
                ApprovalStatus.approved => AppColors.calendarDone,
                ApprovalStatus.rejected => AppColors.calendarProblem,
                _ => AppColors.calendarPlanned,
              };

        return CalendarDay(
          fill: ink.withValues(alpha: 0.12),
          ink: ink,
          dot: ink,
          onTap: () => onPick(d.date),
        );
      },
      legend: [
        if (days.any((d) => d.claimable && d.status != ApprovalStatus.approved))
          const CalendarLegendItem(AppColors.calendarPlanned, 'To claim'),
        if (days.any((d) => d.status == ApprovalStatus.approved))
          const CalendarLegendItem(AppColors.calendarDone, 'Approved'),
        if (days.any((d) =>
            d.status == ApprovalStatus.rejected ||
            d.kind == DayKind.notDeclared))
          const CalendarLegendItem(
              AppColors.calendarProblem, 'Missed or rejected'),
        if (days.any((d) => !d.claimable && d.kind != DayKind.notDeclared))
          const CalendarLegendItem(AppColors.calendarOff, 'Not working'),
      ],
      footer: Row(
        children: [
          Expanded(
            child: Text(
              '${Fmt.money(claimed)} claimed this month',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (open > 0)
            StatusBadge(
              label: '${Fmt.count(open, 'day')} open',
              tone: StatusTone.warning,
              dense: true,
            )
          else if (days.isNotEmpty)
            const StatusBadge(
              label: 'All claimed',
              tone: StatusTone.success,
              dense: true,
            ),
        ],
      ),
    );
  }
}

/// One declared day.
///
/// Every state reads without the badge: a claimed day shows its amount in
/// green with a tick, an open one shows what it is worth beside a Confirm, an
/// excess one carries the rail and the bill count. A day nobody worked stays
/// on the list, inert — seeing the holiday is what tells the rep this is his
/// whole month and not a filtered view of it.
class _DayRow extends ConsumerWidget {
  const _DayRow({super.key, required this.day});

  final ClaimDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worked = day.claimable;

    return AppCard(
      color: worked ? null : AppColors.surfaceSecondary,
      borderColor: worked ? null : Colors.transparent,
      accentColor: day.status == ApprovalStatus.rejected
          ? AppColors.error
          : day.isExcess
          ? AppColors.warning
          : null,
      onTap: worked
          ? () => context.push(Routes.claimDay(day.date))
          : null,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The date block. A month of days is the one place in this app
              // where the date is the point, so it keeps the stacked pill
              // that Home's visit rows gave up.
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: worked
                      ? AppColors.brandSoft
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${day.date.day}',
                      style: AppTypography.titleMd.copyWith(
                        height: 1.05,
                        color: worked
                            ? AppColors.brand
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      Fmt.weekdayShort(day.date).toUpperCase(),
                      style: AppTypography.overline.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worked ? day.place : day.kind.label,
                      style: AppTypography.titleSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    // A day nobody owes for still has to say *why*. "No
                    // claim" was true of a Sunday, of a week of approved
                    // leave and of a day the rep simply never intimated —
                    // and only the last of those is money he has lost.
                    Text(
                      worked
                          ? [
                              day.workType.label,
                              if (day.calls > 0) Fmt.count(day.calls, 'call'),
                            ].join(' · ')
                          : day.note ??
                              switch (day.kind) {
                                DayKind.notDeclared =>
                                  'No intimation filed — nothing can be '
                                      'claimed',
                                _ => 'Nothing to claim',
                              },
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (worked) ...[
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Green means *approved* here, so a draft must not wear
                    // it. Every claimed day was green while the badge beside
                    // it said "Draft" — the colour and the word contradicting
                    // each other on the same row, which is worse than either
                    // alone. The badge carries the state; the ink only marks
                    // the two ends of it.
                    Text(
                      Fmt.money(day.hasClaim ? day.claimed : day.allowance),
                      style: AppTypography.titleSm.copyWith(
                        color: switch (day.status) {
                          ApprovalStatus.approved => AppColors.success,
                          ApprovalStatus.rejected => AppColors.error,
                          _ => day.isExcess
                              ? AppColors.warning
                              : AppColors.textPrimary,
                        },
                      ),
                    ),
                    if (day.isExcess)
                      Text(
                        'of ${Fmt.money(day.allowance)}',
                        style: AppTypography.caption.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ],
              // The state, in a word.
              //
              // It was a green tick for anything claimed, which made a draft,
              // a claim waiting on a manager, an approved one and a *rejected*
              // one look identical. When money moves once a month, "has it
              // been approved" is the question the screen exists to answer,
              // and a tick answered it wrong three times out of four.
              if (day.status != null) ...[
                const SizedBox(width: AppSpacing.sm),
                StatusBadge.approval(day.status!, dense: true),
              ],
              // The chevron every other list in this app uses to say "there is
              // a screen behind this". A claimed row had none, so the only
              // rows that looked openable were the ones with a button on them.
              if (worked && !day.isOpen) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconMd,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),

          if (day.isExcess && day.receiptCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.attach_file,
                  size: AppSizes.iconSm,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Above allowance · '
                    '${Fmt.count(day.receiptCount, 'bill')} attached',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Two buttons, not one.
          //
          // Confirm alone told the rep what the *app* wanted and nothing about
          // what else was possible — the row is tappable, but a card that
          // looks like a card is not obviously a door, and someone opening
          // this for the first time has no reason to try. Details is the way
          // in for a day that needs more than the flat allowance; Confirm
          // stays the loud one because it is right for most days.
          if (day.isOpen) ...[
            const SizedBox(height: AppSpacing.md),
            // Full width, not indented to the date pill. Indented, the pair
            // shared what was left of a 375pt row and "Details" truncated to
            // "Deta…" — and a button that cannot say its own name is the one
            // thing worse than no button at all.
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Details',
                    small: true,
                    onPressed: () => context.push(Routes.claimDay(day.date)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'Confirm',
                    icon: Icons.check_rounded,
                    small: true,
                    onPressed: () => _confirm(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider);
    await ref
        .read(expenseRepositoryProvider)
        .confirmStandardDays(session, [day]);

    if (!context.mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
  }
}

// ===========================================================================
// One day
// ===========================================================================

/// The chosen day, loaded by its date.
///
/// By date rather than handed down the navigation stack: a detail screen that
/// only works when pushed from one particular list is a screen that breaks the
/// moment anything else links to it — the complaint screen learned that the
/// hard way.
final claimDayProvider =
    FutureProvider.autoDispose.family<ClaimDay?, DateTime>((ref, date) async {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);

  final days = await ref
      .watch(expenseRepositoryProvider)
      .claimMonth(session, DateTime(date.year, date.month));

  return days
      .where((d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day)
      .firstOrNull;
});

/// A single day: what it is worth, what has been claimed, and the form for
/// claiming more than the allowance.
class ClaimDayScreen extends ConsumerStatefulWidget {
  const ClaimDayScreen({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<ClaimDayScreen> createState() => _ClaimDayScreenState();
}

class _ClaimDayScreenState extends ConsumerState<ClaimDayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _remarks = TextEditingController();
  final _place = TextEditingController();

  ClaimScope _scope = ClaimScope.local;
  // Daily allowance, ticked. It is what most days are and nothing else, so
  // the form opens on the answer rather than on a blank.
  final Set<ExpenseCategory> _categories = {ExpenseCategory.dailyAllowance};
  final List<String> _receipts = [];
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _amount.dispose();
    _remarks.dispose();
    _place.dispose();
    super.dispose();
  }

  double get _entered => double.tryParse(_amount.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(claimDayProvider(widget.date));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('Claim for ${Fmt.date(widget.date)}')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => ErrorState(
          onRetry: () => ref.invalidate(claimDayProvider(widget.date)),
        ),
        data: (day) {
          if (day == null || !day.claimable) {
            return EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Nothing to claim',
              message: day == null
                  ? 'You did not file a day plan for this date, so there is '
                        'nothing to claim against.'
                  : 'This day was ${day.workType.label.toLowerCase()}. Leave '
                        'and holidays are not claimable.',
            );
          }

          // Seeded once, from the day itself. Doing it in the builder rather
          // than initState is what lets it wait for the record to arrive.
          if (!_seeded) {
            _seeded = true;
            _amount.text = day.remainingAllowance.toStringAsFixed(0);
          }

          return _buildForm(day);
        },
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (day) => (day == null || !day.claimable)
            ? null
            : BottomActionBar(
                children: [
                  SecondaryButton(
                    label: 'Cancel',
                    onPressed: _saving ? null : () => context.pop(),
                  ),
                  PrimaryButton(
                    label: 'Add to claim',
                    isLoading: _saving,
                    onPressed: () => _save(day),
                  ),
                ],
              ),
        orElse: () => null,
      ),
    );
  }

  Widget _buildForm(ClaimDay day) {
    // Against what the day has LEFT. Measured against the full allowance a
    // rep could file ₹250 twice on the same day — each line at the allowance,
    // each needing no bill — and take ₹500 for a ₹250 day. The rule is per
    // day, so the check is too.
    final remaining = day.remainingAllowance;
    final excess = _entered - remaining;
    final isExcess = excess > 0;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          // Straight from the day plan, and not editable here. If any of it is
          // wrong then the day plan is what is wrong, and letting a claim
          // disagree with the intimation it hangs off is how the two come to
          // mean different things.
          AppCard(
            color: AppColors.surfaceSecondary,
            borderColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                KeyValueRow(label: 'Date', value: Fmt.date(day.date)),
                const AppDivider(height: AppSpacing.md),
                KeyValueRow(label: 'Work type', value: day.workType.label),
                const AppDivider(height: AppSpacing.md),
                KeyValueRow(label: 'Worked at', value: day.place),
              ],
            ),
          ),

          if (day.hasClaim) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Already claimed'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < day.expenses.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: AppSpacing.cardPadding,
                      ),
                    _FiledRow(expense: day.expenses[i]),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          SegmentedField<ClaimScope>(
            label: 'Territory',
            options: ClaimScope.values,
            itemLabel: (s) => s.label,
            value: _scope,
            onChanged: (v) => setState(() => _scope = v),
            helper: _scope == ClaimScope.local
                ? 'Worked within your headquarters.'
                : 'Travelling out is the usual reason a day goes above '
                      '${Fmt.money(day.allowance)}.',
          ),

          if (_scope == ClaimScope.outOfTerritory) ...[
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Place travelled to',
              required: true,
              hint: 'Nalgonda',
              controller: _place,
              validator: (v) => Validate.required(v, 'Place'),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          MultiSelectField<ExpenseCategory>(
            label: 'Category',
            required: true,
            options: ExpenseCategory.values,
            selected: _categories,
            itemLabel: (c) => c.label,
            iconOf: (c) => c.icon,
            onChanged: (v) => setState(() {
              _categories
                ..clear()
                ..addAll(v);
            }),
            helper: 'Tick everything the day covers.',
          ),
          const SizedBox(height: AppSpacing.lg),

          CurrencyField(
            label: 'Amount',
            required: true,
            controller: _amount,
            onChanged: (_) => setState(() {}),
            validator: (v) => Validate.amount(v),
            helper: day.hasClaim
                ? '${Fmt.money(remaining)} of this day\'s allowance is left. '
                      'Anything above it needs a bill.'
                : '${Fmt.money(day.allowance)} a day is paid without a bill. '
                      'Anything above it needs one.',
          ),

          // Proofs and remarks are not part of an ordinary claim, so they are
          // not on screen for one. They arrive with the excess that makes them
          // necessary, which is also what makes them feel reasonable rather
          // than bureaucratic.
          if (isExcess) ...[
            const SizedBox(height: AppSpacing.lg),
            _ExcessPanel(
              excess: excess,
              allowance: remaining,
              remarks: _remarks,
              receipts: _receipts,
              onAttach: () => setState(
                () => _receipts.add('bill-${_receipts.length + 1}.jpg'),
              ),
              onRemove: (name) => setState(() => _receipts.remove(name)),
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Future<void> _save(ClaimDay day) async {
    if (!_formKey.currentState!.validate()) return;

    final excess = _entered - day.remainingAllowance;

    // The bill is the rule the whole excess path exists for, so it is enforced
    // rather than hinted. A hint is what the old form had, and a hint is not a
    // rule.
    if (excess > 0 && _receipts.isEmpty) {
      AppHaptics.failure();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attach the bill for the amount above the allowance.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);

    await ref.read(expenseRepositoryProvider).create(
          Expense(
            // Client-generated so a retry on a dropped connection cannot file
            // the same claim twice.
            id: const Uuid().v4(),
            employeeId: session.employee.id,
            employeeName: session.employee.name,
            date: day.date,
            categories: _categories.toList(),
            amount: _entered,
            status: ApprovalStatus.draft,
            description: excess > 0
                ? _remarks.text.trim()
                : 'Daily allowance',
            receiptPaths: List.of(_receipts),
            dayPlanId: day.dayPlanId,
            allowance: day.allowance,
            scope: _scope,
            place: _scope == ClaimScope.outOfTerritory
                ? _place.text.trim()
                : null,
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    setState(() => _saving = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${Fmt.money(_entered)} added for ${Fmt.date(day.date)}.'),
      ),
    );
  }
}

/// A claim already filed for this day.
class _FiledRow extends StatelessWidget {
  const _FiledRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(Routes.expenseDetail(expense.id)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.categories.map((c) => c.label).join(' · '),
                    style: AppTypography.titleSm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    expense.description ?? '—',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(Fmt.money(expense.amount), style: AppTypography.titleSm),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge.approval(expense.status, dense: true),
          ],
        ),
      ),
    );
  }
}

/// Everything the excess drags in with it.
class _ExcessPanel extends StatelessWidget {
  const _ExcessPanel({
    required this.excess,
    required this.allowance,
    required this.remarks,
    required this.receipts,
    required this.onAttach,
    required this.onRemove,
  });

  final double excess;
  final double allowance;
  final TextEditingController remarks;
  final List<String> receipts;
  final VoidCallback onAttach;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.warning.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: AppSizes.iconMd,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${Fmt.money(excess)} above the allowance',
                  style: AppTypography.titleSm,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Attach the bill for the extra amount and say what it was for. '
            'The ${Fmt.money(allowance)} a day needs neither.',
            style: AppTypography.bodySm,
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Photograph bill',
                  icon: Icons.photo_camera_outlined,
                  small: true,
                  onPressed: onAttach,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SecondaryButton(
                  label: 'Attach file',
                  icon: Icons.attach_file,
                  small: true,
                  onPressed: onAttach,
                ),
              ),
            ],
          ),

          if (receipts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in receipts)
                  InputChip(
                    label: Text(name, style: AppTypography.caption),
                    avatar: const Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    backgroundColor: AppColors.surfaceSecondary,
                    side: BorderSide.none,
                    onDeleted: () => onRemove(name),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          AppTextField(
            label: 'Why the extra',
            required: true,
            controller: remarks,
            maxLines: 3,
            hint: 'Stayed overnight — last bus to Hyderabad was missed',
            validator: (v) => Validate.required(v, 'Reason'),
          ),
        ],
      ),
    );
  }
}
