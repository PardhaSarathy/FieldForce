import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_glow.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/client.dart';
import '../../../shared/models/field_ops.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/approval_timeline.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

enum TravelFilter {
  all('All'),
  draft('Draft'),
  submitted('Submitted'),
  approved('Approved'),
  rejected('Rejected');

  const TravelFilter(this.label);
  final String label;

  bool matches(TravelPlan p) => switch (this) {
    all => true,
    draft => p.status == ApprovalStatus.draft,
    submitted => p.status.awaitsDecision,
    approved => p.status == ApprovalStatus.approved,
    rejected => p.status == ApprovalStatus.rejected,
  };
}

final _travelFilterProvider = StateProvider.autoDispose<TravelFilter>(
  (ref) => TravelFilter.all,
);

final _travelProvider = FutureProvider.autoDispose<List<TravelPlan>>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(travelRepositoryProvider)
      .list(session, employeeId: session.employee.id);
});

/// Travel dashboard (§21). Tour planning runs up to 30 days ahead, so the
/// screen leads with what is coming rather than what has passed.
class TravelDashboardScreen extends ConsumerWidget {
  const TravelDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_travelFilterProvider);
    final async = ref.watch(_travelProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Tour Plan')),
      floatingActionButton: AppFab(
        onPressed: () => context.push(Routes.newTravelPlan),
        icon: Icons.add_road,
        label: 'New plan',
      ),
      body: Column(
        children: [
          async.maybeWhen(
            data: (plans) => Padding(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: _TravelSummary(plans: plans),
            ),
            orElse: () => const SizedBox(height: AppSpacing.md),
          ),
          FilterChipBar<TravelFilter>(
            options: TravelFilter.values,
            selected: filter,
            labelOf: (f) => f.label,
            countOf: (f) => f == TravelFilter.all
                ? null
                : async.valueOrNull?.where(f.matches).length,
            onSelected: (f) =>
                ref.read(_travelFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) =>
                  ErrorState(onRetry: () => ref.invalidate(_travelProvider)),
              data: (plans) {
                final filtered = plans.where(filter.matches).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.map_outlined,
                    title: 'No tour plans yet',
                    message:
                        'Plan your tours up to 30 days ahead so your '
                        'manager can approve them in time.',
                    actionLabel: 'Create a plan',
                    onAction: () => context.push(Routes.newTravelPlan),
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
                    child: _TravelCard(plan: filtered[i]),
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

class _TravelSummary extends StatelessWidget {
  const _TravelSummary({required this.plans});

  final List<TravelPlan> plans;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = plans.where((p) => p.date.isAfter(now)).toList();
    final pending = plans.where((p) => p.status.awaitsDecision).length;
    final visits = upcoming.fold<int>(0, (s, p) => s + p.plannedVisits);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _Cell(label: 'Upcoming tours', value: '${upcoming.length}'),
          ),
          Container(width: 1, height: 34, color: AppColors.border),
          Expanded(
            child: _Cell(label: 'Planned visits', value: '$visits'),
          ),
          Container(width: 1, height: 34, color: AppColors.border),
          Expanded(
            child: _Cell(
              label: 'Awaiting approval',
              value: '$pending',
              color: pending > 0 ? AppColors.warning : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: AppTypography.metricSm.copyWith(color: color)),
      const SizedBox(height: 2),
      Text(label, style: AppTypography.caption, textAlign: TextAlign.center),
    ],
  );
}

class _TravelCard extends StatelessWidget {
  const _TravelCard({required this.plan});

  final TravelPlan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.travelDetail(plan.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.sandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  children: [
                    Text(
                      Fmt.monthShort(plan.date).toUpperCase(),
                      style: AppTypography.overline.copyWith(fontSize: 9),
                    ),
                    Text('${plan.date.day}', style: AppTypography.titleMd),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.areaName ?? 'Tour',
                      style: AppTypography.titleMd,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${plan.tourType.label} · ${plan.travelMode.label}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              StatusBadge.approval(plan.status, dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  Fmt.count(plan.plannedVisits, 'visit'),
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              if (plan.estimatedKm != null) ...[
                const SizedBox(width: AppSpacing.lg),
                const Icon(
                  Icons.route_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    '${plan.estimatedKm!.round()} km',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================= detail ==

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
      bottomNavigationBar: async.maybeWhen(
        data: (plan) => plan.status == ApprovalStatus.draft
            ? BottomActionBar(
                children: [
                  SecondaryButton(
                    label: 'Edit',
                    onPressed: () => context.push(Routes.editTravelPlan(plan.id)),
                  ),
                  PrimaryButton(
                    label: 'Submit for approval',
                    onPressed: () async {
                      await ref.read(travelRepositoryProvider).submit(plan.id);
                      AppHaptics.success();
                      ref.bumpRevision();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tour plan submitted.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              )
            : null,
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
class NewTravelPlanScreen extends ConsumerStatefulWidget {
  const NewTravelPlanScreen({super.key, this.existing});

  /// Null to create. Only ever a **draft** — the detail screen offers Edit on
  /// nothing else, because a submitted plan is already in front of an approver.
  final TravelPlan? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<NewTravelPlanScreen> createState() =>
      _NewTravelPlanScreenState();
}

/// Loads a plan, then hands it to the form.
class EditTravelPlanScreen extends ConsumerWidget {
  const EditTravelPlanScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_travelDetailProvider(planId)).when(
          loading: () => const Scaffold(
            backgroundColor: Colors.transparent,
            body: LoadingState(message: 'Loading plan'),
          ),
          error: (_, _) => Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('Edit Tour Plan')),
            body: ErrorState(
              onRetry: () => ref.invalidate(_travelDetailProvider(planId)),
            ),
          ),
          data: (plan) => NewTravelPlanScreen(existing: plan),
        );
  }
}

class _NewTravelPlanScreenState extends ConsumerState<NewTravelPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarks = TextEditingController();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  WorkType _workType = WorkType.fieldWork;
  Territory? _territory;
  Area? _area;

  // Pending selection in the client picker, and what has been added from it.
  Client? _pendingClient;
  final List<Client> _clients = [];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.existing;
    if (plan == null) return;

    _date = plan.date;
    _workType = plan.workType;
    _remarks.text = plan.remarks ?? '';
    // The client chips are stored as names, so they are restored as names too
    // — resolving them back to records would need a lookup the plan does not
    // carry ids for.
    _restoredClients = plan.clientNames;
  }

  /// Names carried over from a saved plan, shown as chips alongside anything
  /// added in this session.
  List<String> _restoredClients = const [];

  List<String> get _clientNames =>
      [..._restoredClients, for (final c in _clients) c.name];

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _save({required bool submit}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final session = ref.read(sessionProvider);
    final existing = widget.existing;
    final plan = TravelPlan(
      // An edit keeps the id, and with it the approval history already
      // attached to this plan.
      id: existing?.id ?? const Uuid().v4(),
      employeeId: session.employee.id,
      employeeName: session.employee.name,
      date: _date,
      workType: _workType,
      status: submit ? ApprovalStatus.submitted : ApprovalStatus.draft,
      areaId: _area?.id,
      areaName: _area?.name,
      territoryName: _territory?.name ?? session.employee.territoryName,
      destination: _area?.name,
      // The plan's size is the list the rep actually built, not a number they
      // typed beside it — two figures for one fact always drift apart.
      plannedVisits: _clientNames.length,
      clientNames: _clientNames,
      remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      approvalHistory: existing?.approvalHistory ?? const [],
    );

    final repository = ref.read(travelRepositoryProvider);
    if (widget.isEditing) {
      await repository.update(plan);
    } else {
      await repository.create(plan);
    }
    if (!mounted) return;

    AppHaptics.success();
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submit
              ? 'Tour plan submitted for approval.'
              : 'Tour plan saved as a draft.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(_travelAreasProvider);
    final territoriesAsync = ref.watch(_travelTerritoriesProvider);
    final clientsAsync = ref.watch(_travelClientsProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('New Tour Plan')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(
            label: 'Save draft',
            onPressed: _submitting ? null : () => _save(submit: false),
          ),
          PrimaryButton(
            label: 'Submit',
            isLoading: _submitting,
            onPressed: () => _save(submit: true),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            // A month grid, not a date field: a tour plan is built day by
            // day across the coming month, so the rep needs to see the shape
            // of the month while choosing, not one date at a time.
            _TourDatePicker(
              selected: _date,
              firstDate: now,
              // 30-day forward planning window (§21).
              lastDate: now.add(const Duration(days: 30)),
              onSelected: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: AppSpacing.lg),

            DropdownField<WorkType>(
              label: 'Work type',
              required: true,
              items: WorkType.values,
              value: _workType,
              itemLabel: (w) => w.label,
              onChanged: (v) =>
                  setState(() => _workType = v ?? WorkType.fieldWork),
            ),
            const SizedBox(height: AppSpacing.lg),

            territoriesAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const SizedBox.shrink(),
              data: (territories) => DropdownField<Territory>(
                label: 'Territory',
                required: true,
                items: territories,
                value: _territory,
                itemLabel: (t) => t.name,
                onChanged: (v) => setState(() {
                  _territory = v;
                  _area = null;
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            areasAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const SizedBox.shrink(),
              data: (areas) {
                final scoped = _territory == null
                    ? areas
                    : areas
                          .where((a) => a.territoryId == _territory!.id)
                          .toList();
                return DropdownField<Area>(
                  label: 'Area',
                  required: true,
                  items: scoped,
                  value: _area,
                  itemLabel: (a) => a.name,
                  onChanged: (v) => setState(() => _area = v),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Pick-then-Add: a list, because a tour day holds several clients
            // and a plan naming one is not a plan.
            clientsAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const SizedBox.shrink(),
              data: (clients) {
                final scoped = _area == null
                    ? clients
                    : clients.where((c) => c.areaId == _area?.id).toList();
                return _AddPicker<Client>(
                  label: 'Clients',
                  required: true,
                  hint: _area == null
                      ? 'Select an area first'
                      : 'Select a client',
                  items: scoped.where((c) => !_clients.contains(c)).toList(),
                  value: _pendingClient,
                  itemLabel: (c) => '${c.name} · ${c.areaName}',
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
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: 'Remarks',
              controller: _remarks,
              maxLines: 4,
              hint: 'Anything your manager should know about this tour',
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
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

/// A month grid for choosing the tour date.
///
/// A plain date field hides the shape of the month, which is exactly what a
/// rep is reasoning about when building a tour: which days are already spoken
/// for, where the weekends fall, how far ahead the window reaches.
class _TourDatePicker extends StatefulWidget {
  const _TourDatePicker({
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
  });

  final DateTime selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_TourDatePicker> createState() => _TourDatePickerState();
}

class _TourDatePickerState extends State<_TourDatePicker> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  bool _isSelectable(DateTime day) {
    final first = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final last = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    return !day.isBefore(first) && !day.isAfter(last);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday is 1=Mon; the grid starts on Monday, so the offset is
    // one less than the first day's weekday.
    final leading = DateTime(_month.year, _month.month, 1).weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tour date', style: AppTypography.overline),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      Fmt.monthYear(_month),
                      textAlign: TextAlign.center,
                      style: AppTypography.titleSm,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leading + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 38,
                ),
                itemBuilder: (context, i) {
                  if (i < leading) return const SizedBox.shrink();

                  final day = DateTime(
                    _month.year,
                    _month.month,
                    i - leading + 1,
                  );
                  final selectable = _isSelectable(day);
                  final isSelected =
                      day.year == widget.selected.year &&
                      day.month == widget.selected.month &&
                      day.day == widget.selected.day;

                  return GestureDetector(
                    onTap: selectable ? () => widget.onSelected(day) : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? AppGlow.fill(AppColors.brand)
                            : null,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: isSelected
                            ? AppGlow.halo(AppColors.brand, 40, strength: 0.6)
                            : null,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          style: AppTypography.bodySm.copyWith(
                            color: isSelected
                                ? AppColors.textOnBrand
                                : selectable
                                ? AppColors.textPrimary
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
