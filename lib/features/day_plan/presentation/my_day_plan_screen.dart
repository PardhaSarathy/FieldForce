import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/location/location_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

/// My Day Plan (§16) — the morning intimation.
///
/// This is not a schedule and not an activity. It answers one question, before
/// the day starts: *where am I working today, and from where am I saying so.*
/// Work type, HQ, cluster, a free remark, and a GPS stamp the rep can refresh
/// until it is right. Visits are logged separately as they happen.
class MyDayPlanScreen extends ConsumerStatefulWidget {
  const MyDayPlanScreen({super.key});

  @override
  ConsumerState<MyDayPlanScreen> createState() => _MyDayPlanScreenState();
}

class _MyDayPlanScreenState extends ConsumerState<MyDayPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarks = TextEditingController();

  WorkType? _workType;
  Area? _hq;
  Cluster? _cluster;

  List<Area> _areas = [];
  List<Cluster> _clusters = [];

  String? _address;
  DateTime? _capturedAt;
  String? _locationError;
  bool _capturing = false;

  bool _loading = true;
  bool _submitting = false;
  DayPlan? _existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    final employee = session.employee;

    final areas = await ref
        .read(employeeRepositoryProvider)
        .areas(territoryId: employee.territoryId);
    final existing = await ref
        .read(dayPlanRepositoryProvider)
        .forDate(employee.id, DateTime.now());

    if (!mounted) return;

    // An HQ the rep does not belong to would leave the cluster list empty, so
    // default to their own area and fall back to the first in the territory.
    final hq =
        areas.where((a) => a.id == employee.areaId).firstOrNull ??
        areas.firstOrNull;

    setState(() {
      _areas = areas;
      _hq = hq;
      _workType = existing?.workType ?? WorkType.fieldWork;
      _existing = existing;
      _remarks.text = existing?.remarks ?? '';
      _loading = false;
    });

    await _loadClusters(preselect: existing?.clusterName);
    await _capture();
  }

  Future<void> _loadClusters({String? preselect}) async {
    final hq = _hq;
    if (hq == null) return;

    final clusters = await ref
        .read(employeeRepositoryProvider)
        .clusters(areaId: hq.id);
    if (!mounted) return;

    setState(() {
      _clusters = clusters;
      _cluster =
          clusters.where((c) => c.name == preselect).firstOrNull ??
          clusters.firstOrNull;
    });
  }

  /// Reads the current position and resolves it to an address. Exposed as
  /// "Refresh" because a fix taken indoors on arrival is often wrong, and a
  /// rep re-taking it is the normal case, not an error path.
  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _locationError = null;
    });

    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final point, :final capturedAt):
        final address = await ref
            .read(dayPlanRepositoryProvider)
            .addressFor(point, areaId: _hq?.id);
        if (!mounted) return;
        setState(() {
          _address = address;
          _capturedAt = capturedAt;
          _capturing = false;
        });
      case LocationError(:final message):
        setState(() {
          _locationError = message;
          _capturing = false;
        });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // The stamp is the point of the record. Submitting without one would file
    // an intimation that cannot be checked, which is worse than not filing it.
    if (_address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture your location before submitting.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final employee = ref.read(sessionProvider).employee;
    final workType = _workType ?? WorkType.fieldWork;
    final now = DateTime.now();

    await ref
        .read(dayPlanRepositoryProvider)
        .submit(
          DayPlan(
            // Client-generated so a retry on a dropped connection cannot file
            // the same day twice.
            id: _existing?.id ?? const Uuid().v4(),
            employeeId: employee.id,
            date: DateTime(now.year, now.month, now.day),
            workType: workType,
            // Cleared rather than carried: switching to Leave after picking an
            // HQ must not file a leave day that claims a headquarters.
            areaId: workType.needsHeadquarters ? _hq?.id : null,
            areaName: workType.needsHeadquarters ? _hq?.name : null,
            clusterName: workType.needsCluster ? _cluster?.name : null,
            status: ApprovalStatus.submitted,
            remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
            capturedAddress: _address,
            submittedAt: now,
          ),
        );

    if (!mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Day plan submitted for ${Fmt.date(now)}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workType = _workType ?? WorkType.fieldWork;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('My Day Plan')),
      bottomNavigationBar: _loading
          ? null
          : BottomActionBar(
              children: [
                PrimaryButton(
                  label: _existing == null ? 'Submit' : 'Update plan',
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
      body: _loading
          ? const LoadingState(message: 'Loading your day plan')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                children: [
                  if (_existing != null) ...[
                    _AlreadySubmittedNote(plan: _existing!),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  DropdownField<WorkType>(
                    label: 'Work type',
                    required: true,
                    hint: 'Select work type',
                    items: WorkType.values,
                    value: _workType,
                    itemLabel: (w) => w.label,
                    onChanged: (v) => setState(() => _workType = v),
                    validator: (_) =>
                        _workType == null ? 'Select a work type' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // A leave or holiday day has no headquarters and covers no
                  // cluster, so the fields are not shown rather than shown and
                  // excused. A form that asks a question with no answer is how
                  // somebody filing sick leave ends up unable to submit at all.
                  if (workType.needsHeadquarters) ...[
                    DropdownField<Area>(
                      label: 'HQ',
                      required: true,
                      hint: _areas.isEmpty ? 'No HQ in your territory' : 'Select HQ',
                      items: _areas,
                      value: _hq,
                      itemLabel: (a) => a.name,
                      enabled: _areas.isNotEmpty,
                      onChanged: (v) {
                        setState(() {
                          _hq = v;
                          _cluster = null;
                          _clusters = [];
                        });
                        // The clusters below belong to the HQ above, so they
                        // are reloaded rather than filtered — the same call the
                        // API will make.
                        _loadClusters();
                      },
                      validator: (_) => _hq == null ? 'Select an HQ' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (workType.needsCluster) ...[
                    DropdownField<Cluster>(
                      label: 'Cluster',
                      required: true,
                      hint: _clusters.isEmpty
                          ? 'No clusters in this HQ'
                          : 'Select cluster',
                      items: _clusters,
                      value: _cluster,
                      itemLabel: (c) => c.name,
                      enabled: _clusters.isNotEmpty,
                      onChanged: (v) => setState(() => _cluster = v),
                      validator: (_) =>
                          _cluster == null ? 'Select a cluster' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AppTextField(
                    label: 'Remarks',
                    controller: _remarks,
                    maxLines: 4,
                    hint: 'Anything your manager should know about today',
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _LocationStamp(
                    address: _address,
                    capturedAt: _capturedAt,
                    error: _locationError,
                    isCapturing: _capturing,
                    onRefresh: _capture,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
    );
  }
}

/// Today's plan already exists. Shown rather than hidden, so re-submitting is
/// an informed correction instead of a silent overwrite.
class _AlreadySubmittedNote extends StatelessWidget {
  const _AlreadySubmittedNote({required this.plan});

  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.brandSoft,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: AppSizes.iconMd,
            color: AppColors.brand,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.submittedAt == null
                      ? 'Today is already declared. Submitting again replaces it.'
                      : 'Declared at ${Fmt.time(plan.submittedAt!)}. '
                            'Submitting again replaces it.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.brandDark,
                    height: 1.35,
                  ),
                ),
                // Where they declared it from. The plan stamps a GPS address
                // at submit and it was stored and never shown — which makes it
                // impossible for the rep to notice a wrong one.
                if (plan.capturedAddress != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: AppSizes.iconSm,
                        color: AppColors.brandDark,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          plan.capturedAddress!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the rep is standing, when it was read, and a way to read it again.
class _LocationStamp extends StatelessWidget {
  const _LocationStamp({
    required this.address,
    required this.capturedAt,
    required this.error,
    required this.isCapturing,
    required this.onRefresh,
  });

  final String? address;
  final DateTime? capturedAt;
  final String? error;
  final bool isCapturing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: AppSizes.iconSm,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Location',
                  style: AppTypography.overline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Flexible, and its label ellipsises: at 320pt with the text
              // scaled to 1.3x the eyebrow and this control together are wider
              // than the card, and the label is the half that can give.
              Flexible(
                child: GestureDetector(
                  onTap: isCapturing ? null : onRefresh,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 15,
                          color: isCapturing
                              ? AppColors.textSecondary
                              : AppColors.brand,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            'Refresh',
                            style: AppTypography.titleSm.copyWith(
                              fontSize: 13,
                              color: isCapturing
                                  ? AppColors.textSecondary
                                  : AppColors.brand,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (isCapturing)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Reading your position…',
                    style: AppTypography.bodySm,
                  ),
                ),
              ],
            )
          else if (error != null)
            Text(
              error!,
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            )
          else if (address != null) ...[
            Text(address!, style: AppTypography.body.copyWith(height: 1.4)),
            if (capturedAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${Fmt.date(capturedAt!)} · ${Fmt.time(capturedAt!)}',
                style: AppTypography.caption,
              ),
            ],
          ] else
            Text(
              'Not captured yet.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
