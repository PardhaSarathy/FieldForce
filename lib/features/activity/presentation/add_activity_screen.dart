import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

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
import 'activity_detail_screen.dart';
import 'widgets/call_report_form.dart';
import 'widgets/visit_photo_field.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import 'widgets/geo_verification_panel.dart';
import 'widgets/step_progress.dart';

/// Add New Activity (§20) — pick the client, then three steps.
///
/// The shape is deliberately the **same as the live visit flow**: client
/// header, numbered Location / Call report / Review, Cancel-and-Continue at
/// the foot. The two screens record the same thing — one while the rep is
/// standing at the door, one afterwards — and a rep who has learnt one should
/// not have to learn the other.
///
/// It was a single long page for a while, which was itself a reaction to an
/// older four-step wizard whose steps were Activity → Visit → Report → Attach.
/// That wizard was wrong because its steps were *screens*, not stages: it
/// asked for eight fields across four pages and none of the four meant
/// anything on its own. These three do — where you are, what happened, and
/// what is about to be saved — and the first of them has to come first, for
/// the same reason it does in the visit flow: discovering the call cannot be
/// verified *after* writing the report is discovering it too late.
///
/// The client is chosen before any of it. Until there is a client there is no
/// geo-fence to measure against and no history to show, so the step header
/// would be three inert circles.
///
/// The client's designation, type, area and category are shown but never
/// edited here — they belong to the client record, and a rep correcting them
/// mid-call would silently fork the master data.
class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key, this.presetClientId, this.existing});

  final String? presetClientId;

  /// The call being corrected, or null to record a new one.
  ///
  /// A rep who mistypes a POB figure or a feedback note had no way to fix it —
  /// `ActivityRepository.update` existed for the whole build and nothing called
  /// it. Correcting goes through `update` rather than `completeVisit`
  /// deliberately: completion also bumps the client's visit count and last-seen
  /// date, and re-running that on an edit would inflate the client's history
  /// every time someone fixed a typo.
  final Activity? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

/// Loads a call, then hands it to the same form.
class EditActivityScreen extends ConsumerWidget {
  const EditActivityScreen({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(activityByIdProvider(activityId))
        .when(
          loading: () => const Scaffold(
            backgroundColor: Colors.transparent,
            body: LoadingState(message: 'Loading activity'),
          ),
          error: (_, _) => Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('Edit Activity')),
            body: ErrorState(
              onRetry: () => ref.invalidate(activityByIdProvider(activityId)),
            ),
          ),
          data: (activity) => AddActivityScreen(existing: activity),
        );
  }
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inputs = TextEditingController();
  final _pob = TextEditingController();
  final _feedback = TextEditingController();
  final _pop = TextEditingController();
  final _remarks = TextEditingController();
  int _rcpaScore = 0;
  final Set<String> _selectedProducts = {};

  final _reason = TextEditingController();
  final _pageController = PageController();

  List<Client> _clients = [];

  Client? _client;
  DateTime _nextVisit = DateTime.now().add(const Duration(days: 14));

  VisitPurpose? _purpose;

  /// Which of Location / Call report / Review is showing. Only meaningful
  /// once a client is picked — before that the screen is the picker.
  int _step = 0;

  String? _address;
  String? _locationError;
  bool _capturing = false;

  /// The fix measured against the client's registered position.
  ///
  /// Evaluated at capture rather than at submit, because the Location step has
  /// to *show* the verdict — "Verified · 26 m from client" — and ask for a
  /// reason when it is out of range. Before this the geo-fence was computed
  /// once, silently, on save: a rep could log a call from the wrong end of the
  /// city and find out only when a manager queried the flag.
  GeoFenceResult? _geoResult;

  /// Photos taken at the client, alongside the fix. Named rather than stored
  /// — the camera arrives with the device integration.
  final List<String> _photos = [];

  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    final e = widget.existing;
    if (e != null) {
      _inputs.text = e.inputsGiven ?? '';
      _pob.text = e.pobAmount?.toStringAsFixed(0) ?? '';
      _feedback.text = e.feedback ?? '';
      _pop.text = e.pop ?? '';
      _remarks.text = e.remarks ?? '';
      _rcpaScore = e.rcpaScore ?? 0;
      _selectedProducts.addAll(e.productIds);
      _nextVisit = e.expectedNextVisit ?? _nextVisit;
      _reason.text = e.outOfRangeReason ?? '';
      // The evidence from the original call, shown read-only. A correction
      // never re-measures: the rep is at a desk now, not at the clinic.
      _geoResult = e.geoResult;
    }

    _load();
  }

  @override
  void dispose() {
    _inputs.dispose();
    _pob.dispose();
    _feedback.dispose();
    _pop.dispose();
    _remarks.dispose();
    _reason.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);

    final clients = await ref.read(clientRepositoryProvider).list(session);
    if (!mounted) return;
    // Editing kept every field except the one the record is *about*. The
    // client came only from `presetClientId`, which a correction never
    // carries, so opening a saved call put an empty Client picker on screen
    // and the rep had to re-choose the doctor they had already visited —
    // with nothing stopping them choosing a different one.
    final anchorId = widget.existing?.clientId ?? widget.presetClientId;

    setState(() {
      _clients = clients;
      _client = clients.where((c) => c.id == anchorId).firstOrNull;
      _loading = false;
    });

    // A correction must not re-measure: its evidence is already on the record.
    if (!widget.isEditing) await _capture();
  }

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _locationError = null;
    });

    final service = ref.read(locationServiceProvider);
    if (service is MockLocationService) {
      // Anchor the simulated fix to the client so the distance is meaningful.
      service.anchor = _client?.location;
    }

    final result = await service.currentPosition();
    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final point):
        final address = await ref
            .read(dayPlanRepositoryProvider)
            .addressFor(point, areaId: _client?.areaId);
        if (!mounted) return;
        setState(() {
          _address = address;
          _geoResult = _evaluate(point);
          _capturing = false;
        });
      case LocationError(:final message):
        setState(() {
          _locationError = message;
          _capturing = false;
        });
    }
  }

  /// The captured fix measured against the client's registered position.
  GeoFenceResult? _evaluate(GeoPoint point) {
    final client = _client;
    if (client == null) return null;
    return GeoMath.evaluate(
      captured: point,
      registered: client.location,
      radiusMeters: ref.read(geoFenceRadiusProvider),
    );
  }

  /// Whether the Location step will let the rep move on.
  ///
  /// Mirrors the visit flow exactly, and for the same reasons: under `strict`
  /// an out-of-range call cannot proceed, and under `warn` — the default — it
  /// proceeds only once a reason has been written. A correction skips the gate
  /// because it is not measuring anything.
  bool get _canLeaveLocationStep {
    final result = _geoResult;

    // A correction is not re-measuring, so there is nothing to wait for and
    // no policy to enforce against — but it must not be a way to *delete* the
    // justification an out-of-range call already carries.
    if (widget.isEditing) {
      return !(result?.requiresReason ?? false) ||
          _reason.text.trim().isNotEmpty;
    }

    if (result == null) return false;
    if (!GeoMath.allowsVisit(result, ref.read(geoFencePolicyProvider))) {
      return false;
    }
    if (result.requiresReason && _reason.text.trim().isEmpty) return false;
    return true;
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: AppMotion.normal,
      curve: AppMotion.curve,
    );
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    _goToStep(_step - 1);
  }

  void _next() {
    // The call-report step is the only one with fields to fail, and it is
    // validated on the way out rather than on the way in — so a rep is never
    // shown an error about something they have not reached yet.
    if (_step == 1 && !_formKey.currentState!.validate()) return;
    if (_step < 2) _goToStep(_step + 1);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final client = _client;
    if (client == null) return;

    setState(() => _submitting = true);
    final session = ref.read(sessionProvider);
    final now = DateTime.now();

    // Geo policy defaults to `warn`: an out-of-range call is recorded and
    // flagged, never blocked (§9). The verdict was shown to the rep on the
    // Location step, so this saves what they were told rather than
    // re-measuring and possibly saving something else.
    final geo = _geoResult;

    final existing = widget.existing;
    final repository = ref.read(activityRepositoryProvider);
    final record = Activity(
      // Client-generated so a retry cannot duplicate the call.
      id: existing?.id ?? const Uuid().v4(),
      employeeId: session.employee.id,
      employeeName: session.employee.name,
      clientId: client.id,
      clientName: client.name,
      clientSpecialty: client.specialty,
      clientType: client.type,
      locationName: client.addressLine,
      areaName: client.areaName,
      // A correction keeps the call's real timeline. Rewriting these
      // with `now` would move a visit logged this morning to whenever
      // the typo was noticed.
      scheduledStart: existing?.scheduledStart ?? now,
      actualStart: existing?.actualStart ?? now,
      actualEnd: existing?.actualEnd ?? now,
      status: existing?.status ?? ActivityStatus.completed,
      workType: WorkType.fieldWork,
      inputsGiven: _inputs.text.trim().isEmpty ? null : _inputs.text.trim(),
      rcpaScore: _rcpaScore > 0 ? _rcpaScore : null,
      pop: _pop.text.trim().isEmpty ? null : _pop.text.trim(),
      remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
      productIds: _selectedProducts.toList(),
      pobAmount: double.tryParse(_pob.text.trim()),
      feedback: _feedback.text.trim().isEmpty ? null : _feedback.text.trim(),
      expectedNextVisit: _nextVisit,
      // The geo evidence belongs to where the rep actually stood. A
      // correction typed at the office must not overwrite it.
      geoResult: existing?.geoResult ?? geo,
      // Evidence, like the fix beside it: a correction keeps what was taken on
      // the day rather than replacing it from a desk.
      photoPaths: existing?.photoPaths ?? List.of(_photos),
      // Mandatory whenever the call was logged out of range (§9). It had
      // nowhere to be entered on this screen at all before the Location step
      // existed, so an out-of-range call recorded here carried no explanation
      // — the one thing the warn policy is for.
      //
      // Taken from the field rather than from `existing`, on both paths: the
      // field is seeded with the saved reason, so a correction that leaves it
      // alone rewrites the same words, and one that improves them keeps the
      // improvement. `geoResult` above is the half that stays frozen.
      outOfRangeReason:
          _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      createdAt: existing?.createdAt ?? now,
    );

    if (widget.isEditing) {
      await repository.update(record);
    } else {
      await repository.create(record);
    }

    if (!mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Activity updated.'
              : 'Activity recorded for ${client.name}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Activity' : 'Add New Activity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading || client == null ? () => context.pop() : _back,
        ),
      ),
      bottomNavigationBar: _loading ? null : _buildActions(),
      body: _loading
          ? const LoadingState()
          // Creating is one short form. Correcting keeps the three steps: a
          // correction has evidence attached to it — the fix, the photos, the
          // call report — and each of those needs its own screenful.
          : !widget.isEditing
          ? _buildCreateForm()
          : client == null
          ? _buildClientPicker()
          : Column(
              children: [
                StepHeader(
                  name: client.name,
                  subtitle: client.subtitle,
                  currentStep: _step,
                  labels: const ['Location', 'Call report', 'Review'],
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildLocationStep(client),
                      _buildReportStep(),
                      _buildReviewStep(client),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ------------------------------------------------------------ creating

  /// Scheduling a call: who, when, and what for.
  ///
  /// It used to walk straight into Location → Call report → Review, which is
  /// the shape of *recording* a visit rather than *planning* one — and the app
  /// already has a screen for recording it, reached from the activity itself.
  /// Adding an activity now creates the record and lands on it; the three
  /// steps begin when the rep taps **Start visit**, standing at the door.
  Widget _buildCreateForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          DropdownField<Client>(
            label: 'Client',
            required: true,
            hint: 'Select a client',
            items: _clients,
            value: _client,
            itemLabel: (c) => c.name,
            onChanged: (v) => setState(() => _client = v),
            validator: (_) => _client == null ? 'Select a client' : null,
          ),

          if (_client != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ClientFacts(client: _client!),
          ],
          const SizedBox(height: AppSpacing.lg),

          DropdownField<VisitPurpose>(
            label: 'Purpose',
            items: VisitPurpose.values,
            value: _purpose,
            itemLabel: (p) => p.label,
            onChanged: (v) => setState(() => _purpose = v),
            helper: 'What the call is for. It shows on the activity.',
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  /// Creates the activity and opens it.
  ///
  /// `pushReplacement`, not `push`: the form has done its job, and backing out
  /// of the activity should land on the list the rep came from rather than on
  /// a form that would create a second one.
  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final client = _client;
    if (client == null) return;

    setState(() => _submitting = true);
    final session = ref.read(sessionProvider);
    // Today, and now. A rep adds an activity standing outside the clinic, so
    // the date field was a required tap that answered itself — and the one
    // thing it made possible, back-dating a call, is a correction rather than
    // a new record and belongs on the activity's own edit screen.
    final now = DateTime.now();
    final start = now;

    final activity = Activity(
      // Client-generated so a retry cannot file the same call twice.
      id: const Uuid().v4(),
      employeeId: session.employee.id,
      employeeName: session.employee.name,
      clientId: client.id,
      clientName: client.name,
      clientSpecialty: client.specialty,
      clientType: client.type,
      locationName: client.addressLine,
      areaName: client.areaName,
      scheduledStart: start,
      scheduledEnd: start.add(const Duration(minutes: 15)),
      // Planned, not completed. Nothing has happened yet — the visit flow is
      // what turns it into a record of a call.
      status: ActivityStatus.upcoming,
      // Added on the day, off any plan. This screen only ever creates these —
      // the planned calls come from the day's schedule — and it is the reason
      // the form has no date on it.
      isUnplanned: true,
      workType: WorkType.fieldWork,
      purpose: _purpose,
      contactPerson: client.contactPerson,
      contactMobile: client.mobile,
      createdAt: now,
    );

    await ref.read(activityRepositoryProvider).create(activity);

    if (!mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pushReplacement(Routes.activityDetail(activity.id));
  }

  // ------------------------------------------------------------ the client

  /// Everything before the flow starts. One question, and the answer decides
  /// what the geo-fence measures against and whose history is worth showing —
  /// which is why it is not the first *step* but the thing in front of them.
  Widget _buildClientPicker() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        Text('Who did you call on?', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pick the client and the call report opens.',
          style: AppTypography.bodySm,
        ),
        const SizedBox(height: AppSpacing.xl),
        DropdownField<Client>(
          label: 'Client',
          required: true,
          hint: 'Select a client',
          items: _clients,
          value: _client,
          itemLabel: (c) => c.name,
          onChanged: (v) {
            setState(() => _client = v);
            // The fix is anchored to the client, so it is read once there is
            // a client to anchor it to.
            _capture();
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------- step one

  Widget _buildLocationStep(Client client) {
    final result = _geoResult;
    final blocked = result != null &&
        !GeoMath.allowsVisit(result, ref.watch(geoFencePolicyProvider));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        GeoVerificationPanel(
          result: result,
          isCapturing: _capturing,
          clientName: client.name,
          registeredAddress: client.fullAddress,
          errorMessage: _locationError,
          // A correction shows the original evidence and offers no way to
          // replace it: the rep is at a desk now, and a re-measure would
          // claim they were standing at the clinic.
          onRetry: widget.isEditing ? null : _capture,
        ),

        // The same field the live visit flow carries, under the same panel.
        // The fence says the rep was near the clinic; the photo says they were
        // in it with the client.
        const SizedBox(height: AppSpacing.lg),
        VisitPhotoField(
          photos: widget.isEditing
              ? widget.existing!.photoPaths
              : _photos,
          enabled: !widget.isEditing,
          note: widget.isEditing
              ? 'Taken when the call was logged. A correction keeps it.'
              : null,
          onAdd: () => setState(
            () => _photos.add('visit-${_photos.length + 1}.jpg'),
          ),
          onRemove: (p) => setState(() => _photos.remove(p)),
        ),

        if (widget.isEditing) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Where you were standing when the call was logged. A correction '
            'keeps it — you can still change what you wrote about it.',
            style: AppTypography.caption,
          ),
        ],

        // The reason, on a new call and on a correction alike.
        //
        // The two halves of this step are frozen differently on purpose. The
        // *position* is evidence and never moves: re-measuring at a desk would
        // have the record claim the rep was at the clinic. The *reason* is the
        // rep's own account of that position, and improving a hurried
        // one-liner is exactly what a correction is for — freezing that half
        // was the wrong way round, and it left the step with nothing on it a
        // rep could act on.
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
                  widget.isEditing
                      ? 'This call was logged outside the verified range. The '
                            'explanation stays on the record — correct it here '
                            'if it needs to be clearer.'
                      : 'You are outside the verified range for this client. '
                            'Explain why so your manager has the context — the '
                            'call will be recorded as unverified.',
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  hint: 'e.g. Doctor asked to meet at the OPD block',
                  controller: _reason,
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
                    'Your organisation requires calls to be logged within '
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
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  // ---------------------------------------------------------- step two

  Widget _buildReportStep() {
    // The same form the live visit flow uses. The two had drifted into
    // different questions for the same record — see the note on
    // [CallReportForm].
    return Form(
      key: _formKey,
      child: ListView(
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
            feedback: _feedback,
            pop: _pop,
            inputs: _inputs,
            pob: _pob,
            remarks: _remarks,
            nextVisit: _nextVisit,
            onNextVisitChanged: (d) => setState(() => _nextVisit = d),
            // Logging a call afterwards is often catch-up, so the report is
            // asked for rather than insisted on. The live flow insists.
            nextVisitRequired: true,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- step three

  /// What is about to be written, before it is written.
  ///
  /// The client's own record and their visit history sit here rather than
  /// beside the picker: this is the step where "did I choose the right
  /// doctor?" is worth answering, because it is the last moment it can be
  /// answered for free.
  Widget _buildReviewStep(Client client) {
    final rcpa = _rcpaScore > 0 ? _rcpaScore : null;
    final pob = double.tryParse(_pob.text.trim());
    final feedback = _feedback.text.trim();
    final inputs = _inputs.text.trim();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        AppCard(
          child: Column(
            children: [
              KeyValueRow(label: 'Client', value: client.name),
              KeyValueRow(
                label: 'Location',
                valueWidget: StatusBadge.geo(
                  _geoResult?.verification ?? GeoVerification.unavailable,
                ),
              ),
              if (_address != null)
                KeyValueRow(label: 'Captured at', value: _address),
              KeyValueRow(label: 'Input', value: inputs.isEmpty ? null : inputs),
              KeyValueRow(
                label: 'RCPA',
                value: rcpa == null ? null : '$rcpa of 5',
              ),
              KeyValueRow(
                label: 'Products',
                value: _selectedProducts.isEmpty
                    ? null
                    : Fmt.count(_selectedProducts.length, 'product'),
              ),
              KeyValueRow(
                label: 'POB value',
                value: pob == null ? null : Fmt.money(pob),
              ),
              KeyValueRow(
                label: 'Next visit',
                value: Fmt.date(_nextVisit),
              ),
              KeyValueRow(
                label: 'Feedback',
                value: feedback.isEmpty ? null : feedback,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ClientFacts(client: client),
        const SizedBox(height: AppSpacing.lg),
        _VisitHistory(client: client),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildActions() {
    // Creating is one form and one button. The Back/Continue pair belongs to
    // the three steps, which only a correction still walks through.
    if (!widget.isEditing) {
      return BottomActionBar(
        children: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: _submitting ? null : () => context.pop(),
          ),
          PrimaryButton(
            label: 'Add activity',
            isLoading: _submitting,
            onPressed: _create,
          ),
        ],
      );
    }

    if (_client == null) {
      return BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
        ],
      );
    }

    final isLast = _step == 2;
    final canProceed = _step == 0 ? _canLeaveLocationStep : true;

    return BottomActionBar(
      children: [
        SecondaryButton(
          label: _step == 0 ? 'Cancel' : 'Back',
          onPressed: _submitting ? null : _back,
        ),
        PrimaryButton(
          label: isLast
              ? (widget.isEditing ? 'Save changes' : 'Submit')
              : 'Continue',
          isLoading: _submitting,
          onPressed: canProceed ? (isLast ? _submit : _next) : null,
        ),
      ],
    );
  }
}


/// The selected client's own record. Read-only by design — see the class doc
/// on [AddActivityScreen].
class _ClientFacts extends StatelessWidget {
  const _ClientFacts({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[
      if (client.designation != null) ('Designation', client.designation!),
      ('Client type', client.type.label),
      ('Territory / Area', client.areaName),
      ('Category', client.category.label),
    ];

    return AppCard(
      color: AppColors.surfaceSecondary,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const AppDivider(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 116,
                  child: Text(facts[i].$1, style: AppTypography.caption),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(facts[i].$2, style: AppTypography.titleSm),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitHistory extends ConsumerWidget {
  const _VisitHistory({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          const Icon(
            Icons.history,
            size: AppSizes.iconSm,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Visit history', style: AppTypography.overline)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              client.lastVisitAt == null
                  ? Fmt.count(client.totalVisits, 'visit')
                  : '${Fmt.count(client.totalVisits, 'visit')} · last '
                        '${Fmt.relativeDay(client.lastVisitAt!)}',
              style: AppTypography.titleSm,
              textAlign: TextAlign.right,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
