import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/client.dart';
import '../../../shared/models/field_ops.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/month_calendar.dart';
import '../../../shared/widgets/approval_timeline.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

/// Tour Plan (§21) — a month, planned a day at a time.
///
/// The screen opens on **next month's calendar**, because that is the one
/// being planned: a rep files next month's tour during this one. There is no
/// list in front of it any more. The old dashboard showed counts, filters and
/// a scroll of plan cards, none of which answers the question a rep opens this
/// screen with — *which days have I not planned yet* — and all of which a
/// calendar answers at a glance.
///
/// Three rules the shape enforces:
///
/// * **The month goes in one piece.** Every day is saved on its own and
///   nothing is submitted until all of them are — a plan with gaps in it is a
///   plan the manager cannot approve, because the missing days are exactly the
///   ones they would ask about.
/// * **Leave and holidays are plans too.** Saying "I am not working" is an
///   answer, and it needs no territory, no area and no clients.
/// * **A draft month stays editable.** Tap the day again. Once it is with an
///   approver it is read-only, like every other submitted record here.
class TourPlanScreen extends ConsumerWidget {
  const TourPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(tourMonthProvider);
    final async = ref.watch(tourMonthPlanProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Tour Plan')),
      bottomNavigationBar: async.maybeWhen(
        data: (tour) {
          if (tour.isSubmitted) return null;
          return BottomActionBar(
            children: [
              PrimaryButton(
                label: 'Submit ${Fmt.monthYear(month)}',
                icon: Icons.send_rounded,
                // Disabled, not hidden. A missing button says nothing; a
                // disabled one beside "6 days still to plan" says what to do.
                onPressed: tour.isComplete
                    ? () => _submit(context, ref, month)
                    : null,
              ),
            ],
          );
        },
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading your month'),
        error: (_, _) =>
            ErrorState(onRetry: () => ref.invalidate(tourMonthPlanProvider)),
        data: (tour) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(tourMonthPlanProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.xxxl * 2,
            ),
            children: [
              Arrive(child: _TourCalendar(tour: tour)),
              const SizedBox(height: AppSpacing.section),
              Arrive(
                delay: AppMotion.staggerFor(1),
                child: SectionHeader(
                  title: tour.isSubmitted ? 'Submitted' : 'Planned days',
                ),
              ),
              if (tour.plans.isEmpty)
                Arrive(
                  delay: AppMotion.staggerFor(2),
                  child: AppCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.map_outlined,
                      title: 'Nothing planned yet',
                      message: 'Tap a date above to say where you will be. '
                          'Every day of the month needs an answer before the '
                          'plan can go for approval.',
                    ),
                  ),
                ),
              for (final entry in tour.plans.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key)))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                  child: Arrive.staggered(
                    index: entry.key,
                    child: _TourDayRow(plan: entry.value),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) async {
    final go = await showConfirmDialog(
      context,
      title: 'Submit ${Fmt.monthYear(month)}?',
      message: 'The whole month goes to your manager together. You will not '
          'be able to edit it while they are looking at it — a day that '
          'changes after this is a deviation, recorded on your day plan.',
      confirmLabel: 'Submit',
      cancelLabel: 'Not yet',
    );
    if (!go || !context.mounted) return;

    final sent = await ref
        .read(travelRepositoryProvider)
        .submitMonth(ref.read(sessionProvider), month);

    if (!context.mounted) return;
    ref.bumpRevision();

    if (sent == 0) {
      AppHaptics.failure();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every day needs a plan before the month can go.'),
        ),
      );
      return;
    }

    AppHaptics.success();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${Fmt.count(sent, 'day')} sent for approval.'),
      ),
    );
  }
}

/// The month, and how much of it is still blank.
class _TourCalendar extends ConsumerWidget {
  const _TourCalendar({required this.tour});

  final TourMonth tour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = tour.month;

    void step(int delta) => ref.read(tourMonthProvider.notifier).state =
        DateTime(month.year, month.month + delta);

    return MonthCalendar(
      month: month,
      onPreviousMonth: () => step(-1),
      onNextMonth: () => step(1),
      dayOf: (day) {
        final plan = tour.planFor(day);
        final date = DateTime(month.year, month.month, day);

        // A Sunday or a company holiday is already answered. It is drawn —
        // orange, like every other non-working day in this app — rather than
        // left blank, because a blank on a plan reads as *you have not done
        // this yet*, and a rep counting four blanks against "22 of 26" would
        // go looking for four days that were never his to fill. It stays
        // tappable: working a Sunday is unusual, not forbidden.
        if (plan == null) {
          if (!tour.isOff(day)) return const CalendarDay();
          return CalendarDay(
            fill: AppColors.calendarOff.withValues(alpha: 0.12),
            ink: AppColors.calendarOff,
            onTap: () => context.push(Routes.tourPlanDay(date)),
          );
        }

        final ink = !tourDayNeedsDetail(plan.workType)
            ? AppColors.calendarOff
            : switch (plan.status) {
                ApprovalStatus.approved => AppColors.calendarDone,
                ApprovalStatus.rejected => AppColors.calendarProblem,
                _ => AppColors.calendarPlanned,
              };

        return CalendarDay(
          fill: ink.withValues(alpha: 0.12),
          ink: ink,
          dot: ink,
          onTap: () => context.push(Routes.tourPlanDay(date)),
        );
      },
      legend: [
        const CalendarLegendItem(AppColors.calendarPlanned, 'Working'),
        const CalendarLegendItem(AppColors.calendarOff, 'Not working'),
        if (tour.plans.values.any((p) => p.status == ApprovalStatus.approved))
          const CalendarLegendItem(AppColors.calendarDone, 'Approved'),
        if (tour.plans.values.any((p) => p.status == ApprovalStatus.rejected))
          const CalendarLegendItem(AppColors.calendarProblem, 'Rejected'),
      ],
      footer: Row(
        children: [
          Expanded(
            child: Text(
              '${tour.plannedDays} of ${tour.workingDays} working days planned',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (tour.isSubmitted)
            const StatusBadge(
              label: 'Submitted',
              tone: StatusTone.success,
              dense: true,
            )
          else if (tour.isComplete)
            const StatusBadge(
              label: 'Ready to send',
              tone: StatusTone.success,
              dense: true,
            )
          else
            StatusBadge(
              label: '${Fmt.count(tour.missingDays, 'day')} left',
              tone: StatusTone.warning,
              dense: true,
            ),
        ],
      ),
    );
  }
}

/// One planned day, listed under the calendar so the month can be read before
/// it is sent.
class _TourDayRow extends StatelessWidget {
  const _TourDayRow({required this.plan});

  final TravelPlan plan;

  @override
  Widget build(BuildContext context) {
    final working = tourDayNeedsDetail(plan.workType);

    return AppCard(
      onTap: () => context.push(Routes.tourPlanDay(plan.date)),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: working
                  ? AppColors.brandSoft
                  : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${plan.date.day}',
                  style: AppTypography.titleMd.copyWith(
                    height: 1.05,
                    color: working
                        ? AppColors.calendarPlanned
                        : AppColors.calendarOff,
                  ),
                ),
                Text(
                  Fmt.weekdayShort(plan.date).toUpperCase(),
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
                  working
                      ? (plan.areaName ?? plan.territoryName ?? 'Field work')
                      : plan.workType.label,
                  style: AppTypography.titleSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  working
                      ? [
                          plan.workType.label,
                          if (plan.clientNames.isNotEmpty)
                            Fmt.count(plan.clientNames.length, 'client'),
                        ].join(' · ')
                      : 'No work planned',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge.approval(plan.status, dense: true),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.chevron_right,
            size: AppSizes.iconMd,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

final _travelDetailProvider = FutureProvider.autoDispose
    .family<TravelPlan, String>((ref, id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(travelRepositoryProvider).byId(id);
    });

class TravelDetailScreen extends ConsumerWidget {
  const TravelDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_travelDetailProvider(planId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Tour Plan Detail')),
      // No actions here any more. A tour plan is edited a day at a time from
      // the calendar and submitted a *month* at a time from it — a per-plan
      // Edit and Submit on this screen would let a rep send one day of a month
      // on its own, which is the half-plan the month rule exists to prevent.
      bottomNavigationBar: async.maybeWhen(
        data: (plan) => plan.status != ApprovalStatus.draft
            ? null
            : BottomActionBar(
                children: [
                  PrimaryButton(
                    label: 'Edit this day',
                    icon: Icons.edit_outlined,
                    onPressed: () =>
                        context.push(Routes.tourPlanDay(plan.date)),
                  ),
                ],
              ),
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (plan) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.areaName ?? 'Tour',
                          style: AppTypography.h3,
                        ),
                      ),
                      StatusBadge.approval(plan.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(Fmt.date(plan.date), style: AppTypography.bodySm),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(label: 'Work type', value: plan.workType.label),
                  KeyValueRow(label: 'Tour type', value: plan.tourType.label),
                  KeyValueRow(
                    label: 'Travel mode',
                    value: plan.travelMode.label,
                  ),
                  KeyValueRow(label: 'Territory', value: plan.territoryName),
                  KeyValueRow(label: 'Destination', value: plan.destination),
                  KeyValueRow(
                    label: 'Planned visits',
                    value: '${plan.plannedVisits}',
                  ),
                  if (plan.estimatedKm != null)
                    KeyValueRow(
                      label: 'Estimated distance',
                      value: '${plan.estimatedKm!.round()} km',
                    ),
                  KeyValueRow(label: 'Purpose', value: plan.purpose),
                  // The thing the rep actually filled in on the form and could
                  // not see afterwards: who they are going to see.
                  KeyValueRow(
                    label: 'Clients planned',
                    value: plan.clientNames.isEmpty
                        ? null
                        : plan.clientNames.join(', '),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            const SectionHeader(title: 'Approval history'),
            ApprovalTimeline(events: plan.approvalHistory),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ==================================================================== new ==

/// The tour-plan form, for both creating and editing a draft.
///
/// One screen, as with the client form: the date picker, the territory→area
/// cascade and the two add-pickers are the whole screen, and a second copy of
/// them would drift.
/// The day this screen is planning, loaded by its date.
///
/// By date, not by record id: the screen exists before the record does — the
/// whole point is planning a day nothing has been saved against yet.
/// The day's month, not just the day's plan.
///
/// The screen needs both: what was saved for this date, and whether the date
/// is one the company works at all. Fetching the month twice — once for the
/// plan, once to ask about Sundays — would be two answers to one question.
final tourPlanDayProvider =
    FutureProvider.autoDispose.family<TourMonth, DateTime>((ref, date) async {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);

  return ref
      .watch(travelRepositoryProvider)
      .month(session, DateTime(date.year, date.month));
});

/// One day of the tour plan.
///
/// There is no Submit here. A day is **saved**; the month is submitted, once,
/// from the calendar. Splitting it any other way lets a rep send half a plan,
/// and half a plan is the one thing a manager cannot approve.
class TourPlanDayScreen extends ConsumerStatefulWidget {
  const TourPlanDayScreen({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<TourPlanDayScreen> createState() => _TourPlanDayScreenState();
}

class _TourPlanDayScreenState extends ConsumerState<TourPlanDayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarks = TextEditingController();

  WorkType _workType = WorkType.fieldWork;
  Territory? _territory;
  Area? _area;

  Client? _pendingClient;
  final List<Client> _clients = [];
  List<String> _restoredClients = const [];

  bool _saving = false;
  bool _seeded = false;
  bool _scopeSeeded = false;

  List<String> get _clientNames =>
      [..._restoredClients, for (final c in _clients) c.name];

  /// Leave and holidays need nothing but themselves. There is no territory to
  /// name, no area to work and nobody to call on, and asking anyway is asking
  /// a rep to describe the geography of a day they are not working.
  bool get _needsDetail => tourDayNeedsDetail(_workType);

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  void _seed(TravelPlan? plan, TourMonth tour) {
    if (_seeded) return;
    _seeded = true;

    if (plan == null) {
      // A Sunday or a company holiday opens already answered. The rep can
      // still change it — someone does work the odd Sunday — but the default
      // is the truth, and a form that opens on "Field Work" for 15 August is
      // a form asking a question it knows the answer to.
      if (tour.isOff(widget.date.day)) _workType = WorkType.holiday;
      return;
    }

    _workType = plan.workType;
    _remarks.text = plan.remarks ?? '';
    // Client chips are stored as names, so they come back as names — resolving
    // them to records would need ids the plan does not carry.
    _restoredClients = plan.clientNames;
  }

  /// Puts the saved territory and area back into the pickers.
  ///
  /// Separate from [_seed] because it cannot run until the reference lists
  /// have loaded — the dropdowns hold *records*, and the plan stores an area
  /// id. Without this, reopening a day you had already planned showed
  /// "Select" in both, and the validator then refused to save until you
  /// re-picked what you had picked yesterday. Editing a saved day is the whole
  /// point of a month you fill in over several sittings.
  ///
  /// The territory comes from the area rather than from `territoryName`: the
  /// area knows which territory owns it, and matching a name against a list is
  /// a lookup that breaks the first time anyone renames one.
  void _seedScope(TravelPlan? plan, List<Area> areas, List<Territory> terrs) {
    if (_scopeSeeded || plan == null) return;
    _scopeSeeded = true;

    final area = areas.where((a) => a.id == plan.areaId).firstOrNull;
    if (area == null) return;
    final territory =
        terrs.where((t) => t.id == area.territoryId).firstOrNull;

    // After the frame: this runs from inside `build`, and setting state
    // during a build is illegal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _area = area;
        _territory = territory;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tourPlanDayProvider(widget.date));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(Fmt.date(widget.date))),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => ErrorState(
          onRetry: () => ref.invalidate(tourPlanDayProvider(widget.date)),
        ),
        data: (tour) {
          final plan = tour.planFor(widget.date.day);
          _seed(plan, tour);
          final locked = plan != null && plan.status != ApprovalStatus.draft;
          return _buildForm(plan, tour, locked: locked);
        },
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (tour) {
          final plan = tour.planFor(widget.date.day);
          if (plan != null && plan.status != ApprovalStatus.draft) {
            return null;
          }
          return BottomActionBar(
            children: [
              SecondaryButton(
                label: 'Cancel',
                onPressed: _saving ? null : () => context.pop(),
              ),
              PrimaryButton(
                label: 'Save day',
                isLoading: _saving,
                onPressed: () => _save(plan),
              ),
            ],
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildForm(TravelPlan? plan, TourMonth tour, {required bool locked}) {
    final areasAsync = ref.watch(_travelAreasProvider);
    final territoriesAsync = ref.watch(_travelTerritoriesProvider);
    final clientsAsync = ref.watch(_travelClientsProvider);

    final areas = areasAsync.valueOrNull;
    final territories = territoriesAsync.valueOrNull;
    if (areas != null && territories != null) {
      _seedScope(plan, areas, territories);
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          if (locked)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: AppCard(
                color: AppColors.surfaceSecondary,
                borderColor: Colors.transparent,
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: AppSizes.iconMd,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This month is with your manager. A change from here '
                        'is a deviation — record it on the day plan.',
                        style: AppTypography.bodySm,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!locked && plan == null && tour.isOff(widget.date.day))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: AppCard(
                color: AppColors.surfaceSecondary,
                borderColor: Colors.transparent,
                child: Row(
                  children: [
                    const Icon(
                      Icons.beach_access_outlined,
                      size: AppSizes.iconMd,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        tour.holidayName(widget.date.day) != null
                            ? '${tour.holidayName(widget.date.day)} — a '
                                'company holiday. Nothing to plan unless you '
                                'are working it.'
                            : 'Sunday. Nothing to plan unless you are '
                                'working it.',
                        style: AppTypography.bodySm,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          DropdownField<WorkType>(
            label: 'Work type',
            required: true,
            enabled: !locked,
            items: WorkType.values,
            value: _workType,
            itemLabel: (w) => w.label,
            onChanged: (v) =>
                setState(() => _workType = v ?? WorkType.fieldWork),
          ),

          // Everything below belongs to a day that is actually worked. On
          // leave or a holiday the form ends here.
          if (_needsDetail) ...[
            const SizedBox(height: AppSpacing.lg),
            territoriesAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const ErrorState(compact: true),
              data: (territories) => DropdownField<Territory>(
                label: 'Territory',
                required: true,
                enabled: !locked,
                items: territories,
                value: _territory,
                itemLabel: (t) => t.name,
                onChanged: (v) => setState(() {
                  _territory = v;
                  // The area belongs to the territory above it; keeping a
                  // stale one is how a plan ends up naming an area in a
                  // territory the rep does not cover.
                  _area = null;
                }),
                validator: (_) =>
                    _territory == null ? 'Select a territory' : null,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            areasAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const ErrorState(compact: true),
              data: (areas) {
                final scoped = _territory == null
                    ? <Area>[]
                    : areas
                        .where((a) => a.territoryId == _territory!.id)
                        .toList();
                return DropdownField<Area>(
                  label: 'Area',
                  required: true,
                  enabled: !locked && scoped.isNotEmpty,
                  hint: _territory == null
                      ? 'Select a territory first'
                      : 'Select',
                  items: scoped,
                  value: _area,
                  itemLabel: (a) => a.name,
                  onChanged: (v) => setState(() => _area = v),
                  validator: (_) => _area == null ? 'Select an area' : null,
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            clientsAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const SizedBox.shrink(),
              data: (clients) {
                final scoped = _area == null
                    ? <Client>[]
                    : clients
                        .where((c) =>
                            c.areaId == _area!.id && !_clients.contains(c))
                        .toList();
                return _AddPicker<Client>(
                  label: 'Clients',
                  hint: _area == null ? 'Select an area first' : 'Select',
                  items: scoped,
                  value: _pendingClient,
                  itemLabel: (c) => c.name,
                  added: _clients,
                  restored: _restoredClients,
                  onRemoveRestored: (name) => setState(
                    () => _restoredClients =
                        _restoredClients.where((n) => n != name).toList(),
                  ),
                  addedLabel: (c) => c.name,
                  onChanged: (v) => setState(() => _pendingClient = v),
                  onAdd: () => setState(() {
                    if (_pendingClient != null) {
                      _clients.add(_pendingClient!);
                      _pendingClient = null;
                    }
                  }),
                  onRemove: (c) => setState(() => _clients.remove(c)),
                  emptyNote: 'Add the clients you plan to call on.',
                );
              },
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Remarks',
            controller: _remarks,
            enabled: !locked,
            maxLines: 3,
            hint: _needsDetail
                ? 'Anything your manager should know'
                : 'Optional',
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Future<void> _save(TravelPlan? existing) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final session = ref.read(sessionProvider);
    final detail = _needsDetail;

    await ref.read(travelRepositoryProvider).saveDay(
          TravelPlan(
            // Client-generated, and kept across an edit so the approval trail
            // already attached to this day survives it.
            id: existing?.id ?? const Uuid().v4(),
            employeeId: session.employee.id,
            employeeName: session.employee.name,
            date: widget.date,
            workType: _workType,
            status: ApprovalStatus.draft,
            // Cleared on a leave or holiday rather than carried over: a day
            // switched from field work to leave must not keep the area and
            // the client list it had a moment ago.
            areaId: detail ? _area?.id : null,
            areaName: detail ? _area?.name : null,
            territoryName: detail
                ? (_territory?.name ?? session.employee.territoryName)
                : null,
            destination: detail ? _area?.name : null,
            plannedVisits: detail ? _clientNames.length : 0,
            clientNames: detail ? _clientNames : const [],
            remarks:
                _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
            createdAt: existing?.createdAt ?? DateTime.now(),
            approvalHistory: existing?.approvalHistory ?? const [],
          ),
        );

    if (!mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    setState(() => _saving = false);
    context.pop();
  }
}

final _travelAreasProvider = FutureProvider.autoDispose<List<Area>>(
  (ref) => ref.watch(employeeRepositoryProvider).areas(),
);

final _travelTerritoriesProvider = FutureProvider.autoDispose<List<Territory>>(
  (ref) => ref.watch(employeeRepositoryProvider).territories(),
);

final _travelClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(clientRepositoryProvider).list(session);
});

/// A dropdown with an Add button, and the chips it has produced.
///
/// Used for the two fields a tour plan holds several of. The picker empties
/// itself on Add so the control always reads "choose the next one" rather
/// than showing a stale selection that is already in the list below.
class _AddPicker<T> extends StatelessWidget {
  const _AddPicker({
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.itemLabel,
    required this.added,
    required this.addedLabel,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.emptyNote,
    this.required = false,
    this.restored = const [],
    this.onRemoveRestored,
  });

  final String label;
  final String hint;
  final List<T> items;
  final T? value;
  final String Function(T) itemLabel;
  final List<T> added;
  final String Function(T) addedLabel;
  final ValueChanged<T?> onChanged;
  final VoidCallback onAdd;
  final ValueChanged<T> onRemove;
  final String emptyNote;
  final bool required;

  /// Entries already on a saved plan. They arrive as names — the plan stores
  /// names, not ids — so they cannot be matched back to the [items] records
  /// and get their own chips alongside anything added in this session.
  final List<String> restored;
  final ValueChanged<String>? onRemoveRestored;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DropdownField<T>(
                label: label,
                required: required,
                hint: hint,
                items: items,
                value: value,
                itemLabel: itemLabel,
                enabled: items.isNotEmpty,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Sizes to its content. A SecondaryButton stretches to the width
            // it is given, and in an unbounded Row that is infinity.
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Material(
                color: value == null
                    ? AppColors.surfaceSecondary
                    : AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: value == null ? null : onAdd,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 16,
                          color: value == null
                              ? AppColors.textSecondary
                              : AppColors.brand,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Add',
                          style: AppTypography.titleSm.copyWith(
                            color: value == null
                                ? AppColors.textSecondary
                                : AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (added.isEmpty && restored.isEmpty)
          Text(emptyNote, style: AppTypography.caption)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final name in restored)
                InputChip(
                  label: Text(name),
                  onDeleted: () => onRemoveRestored?.call(name),
                  deleteIcon: const Icon(Icons.close, size: 15),
                  backgroundColor: AppColors.brandSoft,
                  side: BorderSide.none,
                  labelStyle: AppTypography.bodySm.copyWith(
                    color: AppColors.brandDark,
                  ),
                ),
              for (final item in added)
                InputChip(
                  label: Text(addedLabel(item)),
                  onDeleted: () => onRemove(item),
                  deleteIcon: const Icon(Icons.close, size: 15),
                  backgroundColor: AppColors.brandSoft,
                  side: BorderSide.none,
                  labelStyle: AppTypography.bodySm.copyWith(
                    color: AppColors.brandDark,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
