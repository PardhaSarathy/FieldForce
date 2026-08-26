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
import '../../../shared/models/activity.dart';
import '../../../shared/models/client.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import 'widgets/step_progress.dart';

final _clientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(clientRepositoryProvider).list(session);
});

/// Add Activity (§18) — a four-step progressive form.
///
/// Split into steps because a single 15-field form is unusable on a phone in
/// the field. Each step is independently valid, so the Continue button can tell
/// the user exactly when they may move on rather than failing at the end (§63).
class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key, this.presetClientId});

  final String? presetClientId;

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _submitting = false;
  Activity? _created;

  // Step 1 — activity
  WorkType _workType = WorkType.fieldWork;
  Client? _client;
  VisitPurpose? _purpose;

  // Step 2 — visit
  final _contactController = TextEditingController();
  final _mobileController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  DateTime? _nextVisit;

  // Step 3 — feedback
  int _rcpaScore = 0;
  final _feedbackController = TextEditingController();
  final _popController = TextEditingController();
  final _remarksController = TextEditingController();

  // Step 4 — location handled at visit time; this step captures notes/photos.
  final _locationNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.presetClientId != null) {
      _prefillClient(widget.presetClientId!);
    }
  }

  Future<void> _prefillClient(String id) async {
    final client = await ref.read(clientRepositoryProvider).byId(id);
    if (!mounted) return;
    setState(() => _selectClient(client));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contactController.dispose();
    _mobileController.dispose();
    _feedbackController.dispose();
    _popController.dispose();
    _remarksController.dispose();
    _locationNoteController.dispose();
    super.dispose();
  }

  /// Choosing a client pre-fills what we already know about them. Re-typing a
  /// contact name and mobile that are already on file is exactly the duplicate
  /// entry §1 asks us to eliminate.
  void _selectClient(Client? client) {
    _client = client;
    if (client != null) {
      _contactController.text = client.contactPerson ?? '';
      _mobileController.text = client.mobile ?? '';
    }
  }

  bool get _canContinue => switch (_step) {
        0 => _client != null && _purpose != null,
        1 => _contactController.text.trim().isNotEmpty,
        2 => true,
        _ => true,
      };

  void _next() {
    if (_step >= 3) return;
    setState(() => _step++);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    final client = _client;
    if (client == null) return;

    setState(() => _submitting = true);

    final session = ref.read(sessionProvider);
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    final isFuture = start.isAfter(DateTime.now());

    final activity = Activity(
      // Client-generated id so an offline create and its later sync cannot
      // produce two records (see the idempotency note in the data layer).
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
      status: isFuture ? ActivityStatus.planned : ActivityStatus.upcoming,
      workType: _workType,
      purpose: _purpose,
      contactPerson: _contactController.text.trim(),
      contactMobile: _mobileController.text.trim(),
      feedback: _feedbackController.text.trim().isEmpty
          ? null
          : _feedbackController.text.trim(),
      pop: _popController.text.trim().isEmpty ? null : _popController.text.trim(),
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      rcpaScore: _rcpaScore > 0 ? _rcpaScore : null,
      expectedNextVisit: _nextVisit,
      syncStatus: ref.read(isOnlineProvider)
          ? SyncStatus.synced
          : SyncStatus.savedLocally,
      createdAt: DateTime.now(),
    );

    await ref.read(activityRepositoryProvider).create(activity);

    if (!mounted) return;
    ref.bumpRevision();
    ref.invalidate(todaySummaryProvider);
    setState(() {
      _submitting = false;
      _created = activity;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_created != null) return _buildSuccess(_created!);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Activity'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: StepProgress(
              currentStep: _step,
              labels: const ['Activity', 'Visit', 'Report', 'Attach'],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildActivityStep(),
                _buildVisitStep(),
                _buildReportStep(),
                _buildAttachStep(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(
            label: _step == 0 ? 'Cancel' : 'Back',
            onPressed: _submitting ? null : _back,
          ),
          PrimaryButton(
            label: _step == 3 ? 'Submit activity' : 'Continue',
            isLoading: _submitting,
            onPressed:
                _canContinue ? (_step == 3 ? _submit : _next) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStep() {
    final clientsAsync = ref.watch(_clientsProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        DropdownField<WorkType>(
          label: 'Work type',
          required: true,
          items: WorkType.values,
          value: _workType,
          itemLabel: (w) => w.label,
          onChanged: (v) => setState(() => _workType = v ?? WorkType.fieldWork),
        ),
        const SizedBox(height: AppSpacing.lg),

        clientsAsync.when(
          loading: () => const Skeleton(height: 48),
          error: (_, _) => Text('Could not load clients',
              style: AppTypography.caption.copyWith(color: AppColors.error)),
          data: (clients) => DropdownField<Client>(
            label: 'Client',
            required: true,
            hint: 'Select a client',
            items: clients,
            value: _client,
            itemLabel: (c) => '${c.name} · ${c.areaName}',
            onChanged: (v) => setState(() => _selectClient(v)),
          ),
        ),

        if (_client != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.brandSoft,
            borderColor: Colors.transparent,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                KeyValueRow(
                    label: 'Type', value: _client!.type.label,
                    labelWidth: 96, dense: true),
                KeyValueRow(
                    label: 'Specialty', value: _client!.specialty,
                    labelWidth: 96, dense: true),
                KeyValueRow(
                    label: 'Category', value: _client!.category.label,
                    labelWidth: 96, dense: true),
                KeyValueRow(
                    label: 'Area', value: _client!.areaName,
                    labelWidth: 96, dense: true),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        DropdownField<VisitPurpose>(
          label: 'Visit purpose',
          required: true,
          hint: 'Why are you meeting?',
          items: VisitPurpose.values,
          value: _purpose,
          itemLabel: (p) => p.label,
          onChanged: (v) => setState(() => _purpose = v),
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildVisitStep() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        AppTextField(
          label: 'Contact person',
          required: true,
          controller: _contactController,
          prefixIcon: Icons.person_outline,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Mobile number',
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) => Validate.mobile(v, isRequired: false),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: DateField(
                label: 'Visit date',
                required: true,
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TimeField(
                label: 'Visit time',
                required: true,
                value: _time,
                onChanged: (t) => setState(() => _time = t),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        DateField(
          label: 'Expected next visit',
          value: _nextVisit,
          firstDate: DateTime.now(),
          onChanged: (d) => setState(() => _nextVisit = d),
          helper: 'Used to prompt you for the follow-up.',
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildReportStep() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        Text(
          'If this visit already happened, record the call report now. '
          'For a planned visit you can leave this blank and fill it in when '
          'you start the visit.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('RCPA score', style: AppTypography.bodySm),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () =>
                    setState(() => _rcpaScore = i == _rcpaScore ? 0 : i),
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                constraints: const BoxConstraints(),
                iconSize: 28,
                icon: Icon(
                  i <= _rcpaScore
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: i <= _rcpaScore ? AppColors.sand : AppColors.border,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Feedback',
          controller: _feedbackController,
          maxLines: 4,
          hint: 'Doctor response, objections, commitments…',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'POP / material shared',
          controller: _popController,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Remarks',
          controller: _remarksController,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildAttachStep() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: AppSizes.iconMd, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Location is captured when you start the visit, not now — '
                  'that is what makes the geo-fence meaningful.',
                  style: AppTypography.bodySm,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Photos & attachments', style: AppTypography.bodySm),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _AttachTile(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                onTap: () => _notYet(context),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _AttachTile(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => _notYet(context),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _AttachTile(
                icon: Icons.attach_file_outlined,
                label: 'File',
                onTap: () => _notYet(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Location note',
          controller: _locationNoteController,
          maxLines: 2,
          hint: 'e.g. Meet at the OPD block, second floor',
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  void _notYet(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File capture is wired up with the backend integration.'),
      ),
    );
  }

  Widget _buildSuccess(Activity activity) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SuccessState(
          title: 'Activity added',
          message: '${activity.clientName} has been added to your plan for '
              '${Fmt.relativeDay(activity.scheduledStart).toLowerCase()}.',
          details: AppCard(
            child: Column(
              children: [
                KeyValueRow(label: 'Client', value: activity.clientName),
                KeyValueRow(
                    label: 'When',
                    value: '${Fmt.date(activity.scheduledStart)} · '
                        '${Fmt.time(activity.scheduledStart)}'),
                KeyValueRow(
                  label: 'Status',
                  valueWidget: StatusBadge.activity(activity.status, dense: true),
                ),
                KeyValueRow(
                  label: 'Sync',
                  valueWidget: StatusBadge.sync(activity.syncStatus, dense: true),
                ),
              ],
            ),
          ),
          primaryLabel: 'Done',
          onPrimary: () => context.go(Routes.activity),
          secondaryLabel: 'Add another',
          onSecondary: () => setState(() {
            _created = null;
            _step = 0;
            _pageController.jumpToPage(0);
            _client = null;
            _purpose = null;
            _feedbackController.clear();
            _popController.clear();
            _remarksController.clear();
            _rcpaScore = 0;
          }),
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.brand),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}
