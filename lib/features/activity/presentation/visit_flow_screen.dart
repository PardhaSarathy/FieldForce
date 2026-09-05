import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/geo_math.dart';
import '../../../core/location/location_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/models/client.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import 'widgets/call_report_form.dart';
import 'widgets/visit_photo_field.dart';
import 'widgets/geo_verification_panel.dart';
import 'widgets/step_progress.dart';

/// The live visit workflow (§84 MR daily flow).
///
///   Start visit → capture location → validate against the geo-fence →
///   record feedback and RCPA → complete → the record feeds everything else.
///
/// Location is captured *before* the feedback step deliberately: capturing it
/// afterwards would let a rep fill in a call report from home and only then
/// discover the visit cannot be verified.
class VisitFlowScreen extends ConsumerStatefulWidget {
  const VisitFlowScreen({super.key, required this.activityId});

  final String activityId;

  @override
  ConsumerState<VisitFlowScreen> createState() => _VisitFlowScreenState();
}

class _VisitFlowScreenState extends ConsumerState<VisitFlowScreen> {
  final _pageController = PageController();
  int _step = 0;

  Activity? _activity;
  Client? _client;
  bool _loading = true;
  String? _loadError;

  // Location step
  GeoFenceResult? _geoResult;
  LocationError? _locationError;
  bool _capturing = false;
  final _reasonController = TextEditingController();

  /// Photos taken at the client. Named rather than stored — the camera comes
  /// with the device integration; the record and the flow around it are what
  /// is being built here.
  final List<String> _photos = [];

  // Feedback step
  int _rcpaScore = 0;
  final _feedbackController = TextEditingController();
  final _popController = TextEditingController();
  final _inputsController = TextEditingController();
  final _pobController = TextEditingController();
  final _remarksController = TextEditingController();
  final Set<String> _selectedProducts = {};
  DateTime? _nextVisit;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reasonController.dispose();
    _feedbackController.dispose();
    _popController.dispose();
    _inputsController.dispose();
    _pobController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final activity = await ref
          .read(activityRepositoryProvider)
          .byId(widget.activityId);
      final client = await ref
          .read(clientRepositoryProvider)
          .byId(activity.clientId);

      // Mark it in progress on the way in, not on the way out.
      //
      // `startVisit` existed on the repository for the whole build and nothing
      // called it, so an activity was never in-progress while the rep was
      // inside this flow, and completion stamped `actualStart` with
      // `DateTime.now()` — the moment the visit *ended*. Every visit's start
      // time was therefore fabricated, and its duration was zero.
      final started = activity.status.isOpen &&
              activity.status != ActivityStatus.inProgress
          ? await ref
              .read(activityRepositoryProvider)
              .startVisit(activity.id)
          : activity;

      if (!mounted) return;
      setState(() {
        _activity = started;
        _client = client;
        _nextVisit = DateTime.now().add(const Duration(days: 21));
        _loading = false;
      });
      // Home shows "Visit in progress" off this. No haptic: this fires when
      // the flow *opens*, and a success buzz for arriving at a screen teaches
      // the rep to ignore the one that means the visit is actually saved.
      ref.bumpRevision();

      // Begin the fix immediately — the rep is standing at the door.
      _captureLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'This visit could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _captureLocation() async {
    setState(() {
      _capturing = true;
      _locationError = null;
    });

    final service = ref.read(locationServiceProvider);
    if (service is MockLocationService) {
      // Anchor the simulated fix to this client so distances are meaningful.
      service.anchor = _client?.location;
    }

    final result = await service.currentPosition();
    if (!mounted) return;

    switch (result) {
      case LocationSuccess(
        :final point,
        :final accuracyMeters,
        :final isMocked,
        :final capturedAt,
      ):
        setState(() {
          _capturing = false;
          _geoResult = GeoMath.evaluate(
            captured: point,
            registered: _client?.location,
            radiusMeters: ref.read(geoFenceRadiusProvider),
            accuracyMeters: accuracyMeters,
            isMocked: isMocked,
            capturedAt: capturedAt,
          );
        });
      case LocationError():
        setState(() {
          _capturing = false;
          _locationError = result;
          _geoResult = GeoFenceResult(
            verification: GeoVerification.unavailable,
            radiusMeters: ref.read(geoFenceRadiusProvider),
          );
        });
    }
  }

  /// Whether the geo step permits moving on, per the configured policy (§9).
  bool get _canLeaveLocationStep {
    final result = _geoResult;
    if (result == null) return false;

    final policy = ref.read(geoFencePolicyProvider);
    if (!GeoMath.allowsVisit(result, policy)) return false;

    // Under `warn`, an out-of-range visit needs a written justification.
    if (result.requiresReason && _reasonController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  void _next() {
    if (_step >= 2) return;
    setState(() => _step++);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _complete() async {
    final activity = _activity;
    if (activity == null) return;

    setState(() => _submitting = true);

    final completed = activity.copyWith(
      status: ActivityStatus.completed,
      // Stamped when the flow opened. The fallback is for an activity that
      // somehow reached completion without passing through `_load`.
      actualStart: activity.actualStart ?? DateTime.now(),
      actualEnd: DateTime.now(),
      geoResult: _geoResult,
      outOfRangeReason: _geoResult?.requiresReason == true
          ? _reasonController.text.trim()
          : null,
      rcpaScore: _rcpaScore > 0 ? _rcpaScore : null,
      feedback: _feedbackController.text.trim(),
      pop: _popController.text.trim(),
      inputsGiven: _inputsController.text.trim().isEmpty
          ? null
          : _inputsController.text.trim(),
      pobAmount: double.tryParse(_pobController.text.trim()),
      remarks: _remarksController.text.trim(),
      productIds: _selectedProducts.toList(),
      photoPaths: List.of(_photos),
      expectedNextVisit: _nextVisit,
      syncStatus: ref.read(isOnlineProvider)
          ? SyncStatus.synced
          : SyncStatus.savedLocally,
    );

    await ref.read(activityRepositoryProvider).completeVisit(completed);

    if (!mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    ref.invalidate(todaySummaryProvider);
    setState(() {
      _submitting = false;
      _activity = completed;
      _step = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingState(message: 'Preparing visit'));
    }

    if (_loadError != null || _activity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visit')),
        body: ErrorState(message: _loadError, onRetry: _load),
      );
    }

    // Completion confirmation replaces the whole flow.
    if (_step == 3) return _buildSuccess();

    final activity = _activity!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showConfirmDialog(
          context,
          title: 'Leave this visit?',
          message: 'Your notes for this visit will not be saved.',
          confirmLabel: 'Leave',
          cancelLabel: 'Stay',
          isDestructive: true,
        );
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Visit'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
        ),
        body: Column(
          children: [
            StepHeader(
              name: activity.clientName,
              subtitle:
                  activity.clientSpecialty ?? activity.clientType.label,
              currentStep: _step,
              labels: const ['Location', 'Call report', 'Review'],
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildLocationStep(),
                  _buildFeedbackStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildActions(),
      ),
    );
  }

  // ------------------------------------------------------------- step one

  Widget _buildLocationStep() {
    final policy = ref.watch(geoFencePolicyProvider);
    final result = _geoResult;
    final blocked = result != null && !GeoMath.allowsVisit(result, policy);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        GeoVerificationPanel(
          result: result,
          isCapturing: _capturing,
          clientName: _client?.name ?? '',
          registeredAddress: _client?.fullAddress,
          errorMessage: _locationError?.message,
          onRetry: _captureLocation,
          onOpenSettings:
              _locationError?.failure ==
                  LocationFailure.permissionPermanentlyDenied
              ? () => ref.read(locationServiceProvider).openSettings()
              : null,
        ),

        // Under the fence panel, because the two are one piece of evidence:
        // the fence says the rep was near the clinic, the photo says they were
        // in it.
        const SizedBox(height: AppSpacing.lg),
        VisitPhotoField(
          photos: _photos,
          onAdd: () => setState(
            () => _photos.add('visit-${_photos.length + 1}.jpg'),
          ),
          onRemove: (p) => setState(() => _photos.remove(p)),
        ),

        if (result != null && result.requiresReason) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            borderColor: AppColors.warning.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.edit_note_outlined,
                      size: AppSizes.iconMd,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Reason required', style: AppTypography.titleSm),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'You are outside the verified range for this client. '
                  'Explain why so your manager has the context — the visit '
                  'will be recorded as unverified.',
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  hint: 'e.g. Doctor asked to meet at the OPD block',
                  controller: _reasonController,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],

        if (blocked) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            borderColor: AppColors.error.withValues(alpha: 0.4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.block,
                  size: AppSizes.iconMd,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your organisation requires visits to be started within '
                    '${result.radiusMeters.round()} m of the client. Move '
                    'closer and refresh your location.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------- step two

  Widget _buildFeedbackStep() {
    // The shared form. This step and Add New Activity's had drifted into two
    // different sets of questions for the same record — see the note on
    // [CallReportForm].
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        CallReportForm(
          rcpaScore: _rcpaScore,
          onRcpaChanged: (v) => setState(() => _rcpaScore = v),
          selectedProducts: _selectedProducts,
          onProductsChanged: (v) => setState(() {
            _selectedProducts
              ..clear()
              ..addAll(v);
          }),
          feedback: _feedbackController,
          pop: _popController,
          inputs: _inputsController,
          pob: _pobController,
          remarks: _remarksController,
          nextVisit: _nextVisit,
          onNextVisitChanged: (d) => setState(() => _nextVisit = d),
          // A live visit is being written as it happens; a call report with
          // nothing in it is a visit nobody can report on.
          feedbackRequired: true,
        ),
      ],
    );
  }

  // ----------------------------------------------------------- step three

  Widget _buildReviewStep() {
    final activity = _activity!;
    final result = _geoResult;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VISIT SUMMARY', style: AppTypography.overline),
              const SizedBox(height: AppSpacing.md),
              KeyValueRow(label: 'Client', value: activity.clientName),
              KeyValueRow(label: 'Specialty', value: activity.clientSpecialty),
              KeyValueRow(
                label: 'Scheduled',
                value: Fmt.timeRange(
                  activity.scheduledStart,
                  activity.scheduledEnd ??
                      activity.scheduledStart.add(const Duration(minutes: 15)),
                ),
              ),
              KeyValueRow(label: 'Purpose', value: activity.purpose?.label),
              const AppDivider(),
              KeyValueRow(
                label: 'Location',
                valueWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge.geo(
                      result?.verification ?? GeoVerification.unavailable,
                      dense: true,
                    ),
                    if (result?.distanceLabel != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${result!.distanceLabel} from registered address',
                        style: AppTypography.caption,
                      ),
                    ],
                  ],
                ),
              ),
              if (_reasonController.text.trim().isNotEmpty)
                KeyValueRow(
                  label: 'Reason',
                  value: _reasonController.text.trim(),
                ),
              const AppDivider(),
              KeyValueRow(
                label: 'RCPA score',
                value: _rcpaScore > 0 ? '$_rcpaScore of 5' : null,
              ),
              KeyValueRow(
                label: 'Feedback',
                value: _feedbackController.text.trim(),
              ),
              KeyValueRow(
                label: 'Products',
                value: _selectedProducts.isEmpty
                    ? null
                    : '${_selectedProducts.length} selected',
              ),
              KeyValueRow(label: 'POP', value: _popController.text.trim()),
              KeyValueRow(
                label: 'Remarks',
                value: _remarksController.text.trim(),
              ),
              KeyValueRow(
                label: 'Next visit',
                value: _nextVisit == null ? null : Fmt.date(_nextVisit!),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!ref.watch(isOnlineProvider))
          AppCard(
            color: AppColors.warningSoft,
            borderColor: AppColors.warning.withValues(alpha: 0.35),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: AppSizes.iconMd,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "You're offline. This visit will be saved on your device "
                    'and synced automatically when you reconnect.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  // ----------------------------------------------------------------- misc

  Widget _buildActions() {
    final isLast = _step == 2;
    final canProceed = switch (_step) {
      0 => _canLeaveLocationStep,
      1 => _feedbackController.text.trim().isNotEmpty,
      _ => true,
    };

    return BottomActionBar(
      children: [
        SecondaryButton(
          label: _step == 0 ? 'Cancel' : 'Back',
          onPressed: _submitting ? null : _back,
        ),
        PrimaryButton(
          label: isLast ? 'Complete visit' : 'Continue',
          isLoading: _submitting,
          onPressed: canProceed
              ? (isLast
                    ? _complete
                    : () {
                        // Re-validate the feedback field on tap so the requirement
                        // surfaces even if the user never blurred the field.
                        if (_step == 1 &&
                            _feedbackController.text.trim().isEmpty) {
                          setState(() {});
                          return;
                        }
                        _next();
                      })
              : null,
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final activity = _activity!;
    final synced = activity.syncStatus == SyncStatus.synced;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SuccessState(
          title: 'Visit completed',
          message: synced
              ? 'The call report for ${activity.clientName} has been recorded.'
              : 'Saved on this device. It will sync automatically when '
                    "you're back online.",
          details: AppCard(
            child: Column(
              children: [
                KeyValueRow(label: 'Client', value: activity.clientName),
                KeyValueRow(
                  label: 'Completed at',
                  value: Fmt.time(activity.actualEnd ?? DateTime.now()),
                ),
                KeyValueRow(
                  label: 'Verification',
                  valueWidget: StatusBadge.geo(
                    activity.geoResult?.verification ??
                        GeoVerification.unavailable,
                    dense: true,
                  ),
                ),
                KeyValueRow(
                  label: 'Sync',
                  valueWidget: StatusBadge.sync(
                    activity.syncStatus,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
          primaryLabel: 'Back to my day',
          onPrimary: () => context.go(Routes.home),
          secondaryLabel: 'View activity',
          onSecondary: () =>
              context.pushReplacement(Routes.activityDetail(activity.id)),
        ),
      ),
    );
  }
}


