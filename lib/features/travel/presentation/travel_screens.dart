import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/field_ops.dart';
import '../../../shared/models/organization.dart';
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

final _travelFilterProvider =
    StateProvider.autoDispose<TravelFilter>((ref) => TravelFilter.all);

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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Travel Plans')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newTravelPlan),
        icon: const Icon(Icons.add_road),
        label: const Text('New plan'),
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
                    title: 'No travel plans',
                    message: 'Plan your tours up to 30 days ahead so your '
                        'manager can approve them in time.',
                    actionLabel: 'Create a plan',
                    onAction: () => context.push(Routes.newTravelPlan),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xxxl * 3,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) => _TravelCard(plan: filtered[i]),
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
          Expanded(child: _Cell(label: 'Planned visits', value: '$visits')),
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
                    Text(Fmt.monthShort(plan.date).toUpperCase(),
                        style: AppTypography.overline.copyWith(fontSize: 9)),
                    Text('${plan.date.day}', style: AppTypography.titleMd),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.areaName ?? 'Tour',
                        style: AppTypography.titleMd,
                        overflow: TextOverflow.ellipsis),
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
              const Icon(Icons.people_outline,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text('${plan.plannedVisits} visits',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false),
              ),
              if (plan.estimatedKm != null) ...[
                const SizedBox(width: AppSpacing.lg),
                const Icon(Icons.route_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text('${plan.estimatedKm!.round()} km',
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false),
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

final _travelDetailProvider =
    FutureProvider.autoDispose.family<TravelPlan, String>((ref, id) {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Travel Plan')),
      bottomNavigationBar: async.maybeWhen(
        data: (plan) => plan.status == ApprovalStatus.draft
            ? BottomActionBar(
                children: [
                  SecondaryButton(label: 'Edit', onPressed: () {}),
                  PrimaryButton(
                    label: 'Submit for approval',
                    onPressed: () async {
                      await ref.read(travelRepositoryProvider).submit(plan.id);
                      ref.bumpRevision();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Travel plan submitted.')),
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
                  KeyValueRow(label: 'Travel mode', value: plan.travelMode.label),
                  KeyValueRow(label: 'Territory', value: plan.territoryName),
                  KeyValueRow(label: 'Destination', value: plan.destination),
                  KeyValueRow(
                      label: 'Planned visits', value: '${plan.plannedVisits}'),
                  if (plan.estimatedKm != null)
                    KeyValueRow(
                        label: 'Estimated distance',
                        value: '${plan.estimatedKm!.round()} km'),
                  KeyValueRow(label: 'Purpose', value: plan.purpose),
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

class NewTravelPlanScreen extends ConsumerStatefulWidget {
  const NewTravelPlanScreen({super.key});

  @override
  ConsumerState<NewTravelPlanScreen> createState() =>
      _NewTravelPlanScreenState();
}

class _NewTravelPlanScreenState extends ConsumerState<NewTravelPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destination = TextEditingController();
  final _purpose = TextEditingController();
  final _visits = TextEditingController(text: '6');
  final _km = TextEditingController();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  WorkType _workType = WorkType.fieldWork;
  TourType _tourType = TourType.local;
  TravelMode _mode = TravelMode.bike;
  Area? _area;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [_destination, _purpose, _visits, _km]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool submit}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final session = ref.read(sessionProvider);
    final plan = TravelPlan(
      id: const Uuid().v4(),
      employeeId: session.employee.id,
      employeeName: session.employee.name,
      date: _date,
      workType: _workType,
      status: submit ? ApprovalStatus.submitted : ApprovalStatus.draft,
      areaId: _area?.id,
      areaName: _area?.name,
      territoryName: session.employee.territoryName,
      tourType: _tourType,
      travelMode: _mode,
      destination: _destination.text.trim(),
      purpose: _purpose.text.trim(),
      plannedVisits: int.tryParse(_visits.text.trim()) ?? 0,
      estimatedKm: double.tryParse(_km.text.trim()),
      createdAt: DateTime.now(),
    );

    await ref.read(travelRepositoryProvider).create(plan);
    if (!mounted) return;

    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(submit
            ? 'Travel plan submitted for approval.'
            : 'Travel plan saved as a draft.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(_travelAreasProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Travel Plan')),
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
            DateField(
              label: 'Tour date',
              required: true,
              value: _date,
              firstDate: now,
              // 30-day forward planning window (§21).
              lastDate: now.add(const Duration(days: 30)),
              onChanged: (d) => setState(() => _date = d),
              helper: 'Plans can be created up to 30 days ahead.',
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownField<WorkType>(
              label: 'Work type',
              required: true,
              items: WorkType.values,
              value: _workType,
              itemLabel: (w) => w.label,
              onChanged: (v) => setState(() => _workType = v ?? WorkType.fieldWork),
            ),
            const SizedBox(height: AppSpacing.lg),
            areasAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const SizedBox.shrink(),
              data: (areas) => DropdownField<Area>(
                label: 'Area',
                required: true,
                items: areas,
                value: _area,
                itemLabel: (a) => a.name,
                onChanged: (v) => setState(() => _area = v),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: DropdownField<TourType>(
                    label: 'Tour type',
                    items: TourType.values,
                    value: _tourType,
                    itemLabel: (t) => t.label,
                    onChanged: (v) =>
                        setState(() => _tourType = v ?? TourType.local),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownField<TravelMode>(
                    label: 'Travel mode',
                    items: TravelMode.values,
                    value: _mode,
                    itemLabel: (m) => m.label,
                    onChanged: (v) =>
                        setState(() => _mode = v ?? TravelMode.bike),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Destination',
              required: true,
              controller: _destination,
              validator: (v) => Validate.required(v, 'Destination'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Planned visits',
                    controller: _visits,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'Estimated km',
                    controller: _km,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Purpose',
              controller: _purpose,
              maxLines: 3,
              hint: 'What will you achieve on this tour?',
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
