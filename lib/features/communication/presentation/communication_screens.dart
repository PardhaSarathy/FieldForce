import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_glow.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/remote/backend.dart';
import '../../../data/remote/storage_upload.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/client.dart';
import '../../../shared/models/engagement.dart';
import '../../../shared/models/field_ops.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import '../../shell/presentation/app_shell.dart';

export 'chat_screens.dart';

// ============================================================== resources ==

final _resourceCategoryProvider = StateProvider.autoDispose<String>(
  (ref) => 'All',
);

final _resourcesProvider = FutureProvider.autoDispose<List<Resource>>((ref) {
  return ref
      .watch(resourceRepositoryProvider)
      .list(category: ref.watch(_resourceCategoryProvider));
});

class ResourceListScreen extends ConsumerWidget {
  const ResourceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(_resourceCategoryProvider);
    final async = ref.watch(_resourcesProvider);
    const categories = [
      'All',
      'E-Detailing',
      'Product Information',
      'Price List',
      'Training',
      'Document',
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Resources'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => openAppDrawer(ref),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          FilterChipBar<String>(
            options: categories,
            selected: category,
            labelOf: (c) => c,
            onSelected: (c) =>
                ref.read(_resourceCategoryProvider.notifier).state = c,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) => const ErrorState(),
              data: (resources) => resources.isEmpty
                  ? const EmptyState(
                      icon: Icons.library_books_outlined,
                      title: 'No resources',
                      message:
                          'Marketing material shared with the field will '
                          'appear here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        0,
                        AppSpacing.screenH,
                        AppSpacing.xxxl,
                      ),
                      itemCount: resources.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.cardGap),
                      itemBuilder: (context, i) => Arrive.staggered(
                        index: i,
                        child: _ResourceCard(resource: resources[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});

  final Resource resource;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.resourceDetail(resource.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: switch (resource.fileType) {
              'VIDEO' => Icons.play_circle_outline,
              'PDF' => Icons.picture_as_pdf_outlined,
              _ => Icons.description_outlined,
            },
            size: 44,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resource.title, style: AppTypography.titleMd),
                if (resource.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    resource.description!,
                    style: AppTypography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                // Wrap rather than Row: category names vary in length and this
                // must survive a 320pt-wide phone.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: resource.category,
                      tone: StatusTone.sand,
                      dense: true,
                    ),
                    Text(
                      '${resource.sizeLabel ?? ''} · '
                      'Updated ${Fmt.dateShort(resource.updatedAt)}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResourceDetailScreen extends ConsumerWidget {
  const ResourceDetailScreen({super.key, required this.resourceId});

  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_resourceProvider(resourceId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Resource Detail')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(
            label: 'Share',
            icon: Icons.ios_share_outlined,
            onPressed: () => showComingWithBackend(context, 'Sharing'),
          ),
          PrimaryButton(
            label: 'Download',
            icon: Icons.download_outlined,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Downloads arrive with the backend.'),
              ),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (resource) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            // The file's stand-in until a real thumbnail exists. Lit, like
            // every other icon in the app that sits on a deep fill.
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppGlow.fill(AppColors.brand),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppGlow.halo(AppColors.brand, 120, strength: 0.5),
              ),
              child: Icon(
                switch (resource.fileType) {
                  'VIDEO' => Icons.play_circle_outline,
                  'PDF' => Icons.picture_as_pdf_outlined,
                  _ => Icons.description_outlined,
                },
                size: 56,
                color: AppColors.wellGlyph,
                shadows: AppGlow.bloom(AppColors.brand, 56),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(resource.title, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.sm),
            if (resource.description != null)
              Text(resource.description!, style: AppTypography.body),
            const SizedBox(height: AppSpacing.section),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(label: 'Category', value: resource.category),
                  KeyValueRow(label: 'File type', value: resource.fileType),
                  KeyValueRow(label: 'Size', value: resource.sizeLabel),
                  KeyValueRow(
                    label: 'Last updated',
                    value: Fmt.date(resource.updatedAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

final _resourceProvider = FutureProvider.autoDispose.family<Resource, String>(
  (ref, id) => ref.watch(resourceRepositoryProvider).byId(id),
);

// ================================================================ surveys ==

final _surveysProvider = FutureProvider.autoDispose<List<SurveyResponse>>((
  ref,
) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(surveyRepositoryProvider).list(session);
});

class SurveyListScreen extends ConsumerWidget {
  const SurveyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_surveysProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Surveys')),
      floatingActionButton: AppFab(
        onPressed: () => context.push(Routes.newSurvey),
        icon: Icons.add,
        label: 'New survey',
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (surveys) => surveys.isEmpty
            ? EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No surveys submitted',
                message: 'Capture structured client feedback in the field.',
                actionLabel: 'Start a survey',
                onAction: () => context.push(Routes.newSurvey),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.screenH,
                  AppSpacing.screenH,
                  AppSpacing.xxxl * 3,
                ),
                itemCount: surveys.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.cardGap),
                itemBuilder: (context, i) {
                  final s = surveys[i];
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.clientName,
                                style: AppTypography.titleMd,
                              ),
                            ),
                            if (s.rating != null)
                              Row(
                                children: [
                                  for (var star = 1; star <= 5; star++)
                                    Icon(
                                      star <= s.rating!
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 14,
                                      color: star <= s.rating!
                                          ? AppColors.sand
                                          : AppColors.border,
                                    ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${s.clientType.label} · '
                          '${Fmt.date(s.submittedAt)}',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(s.feedback, style: AppTypography.bodySm),
                        if (s.remarks != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(s.remarks!, style: AppTypography.caption),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class NewSurveyScreen extends ConsumerStatefulWidget {
  const NewSurveyScreen({super.key});

  @override
  ConsumerState<NewSurveyScreen> createState() => _NewSurveyScreenState();
}

class _NewSurveyScreenState extends ConsumerState<NewSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedback = TextEditingController();
  final _remarks = TextEditingController();
  Client? _client;
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _feedback.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _client == null) return;
    setState(() => _submitting = true);

    final session = ref.read(sessionProvider);
    try {
      await ref
          .read(surveyRepositoryProvider)
          .create(
            SurveyResponse(
              id: const Uuid().v4(),
              employeeId: session.employee.id,
              clientId: _client!.id,
              clientName: _client!.name,
              clientType: _client!.type,
              submittedAt: DateTime.now(),
              feedback: _feedback.text.trim(),
              remarks:
                  _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
              locationName: _client!.areaName,
              rating: _rating > 0 ? _rating : null,
            ),
          );

      if (!mounted) return;
      ref.bumpRevision();
      setState(() => _submitting = false);
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Survey submitted.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(
              e,
              fallback: 'Could not submit the survey. Try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(_commClientsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('New Survey')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: 'Submit',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            clientsAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const ErrorState(compact: true),
              data: (clients) => DropdownField<Client>(
                label: 'Client',
                required: true,
                hint: 'Select a client',
                items: clients,
                value: _client,
                itemLabel: (c) => '${c.name} · ${c.type.label}',
                searchable: true,
                onChanged: (v) => setState(() => _client = v),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Overall rating', style: AppTypography.bodySm),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () =>
                        setState(() => _rating = i == _rating ? 0 : i),
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    constraints: const BoxConstraints(),
                    iconSize: 30,
                    icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i <= _rating ? AppColors.sand : AppColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Feedback',
              required: true,
              controller: _feedback,
              maxLines: 4,
              hint: 'What did the client tell you?',
              validator: (v) => Validate.required(v, 'Feedback'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(label: 'Remarks', controller: _remarks, maxLines: 2),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

final _commClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(clientRepositoryProvider).list(session);
});

// ============================================================= complaints ==

final _complaintsProvider = FutureProvider.autoDispose<List<Complaint>>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(complaintRepositoryProvider).list(session);
});

/// One complaint, by id — the way every other detail screen in the app loads.
///
/// This screen used to read the whole list and filter it in the widget, which
/// fetched every complaint to show one and, worse, made a complaint outside the
/// caller's list scope render as "not found" even though the record exists.
final _complaintProvider =
    FutureProvider.autoDispose.family<Complaint, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(complaintRepositoryProvider).byId(id);
});

class ComplaintListScreen extends ConsumerWidget {
  const ComplaintListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_complaintsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Complaints')),
      floatingActionButton: AppFab(
        onPressed: () => context.push(Routes.newComplaint),
        icon: Icons.add,
        label: 'Raise',
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (complaints) => complaints.isEmpty
            ? EmptyState(
                icon: Icons.report_problem_outlined,
                title: 'No complaints',
                message:
                    'Raise product or service issues on behalf of clients.',
                actionLabel: 'Raise a complaint',
                onAction: () => context.push(Routes.newComplaint),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.screenH,
                  AppSpacing.screenH,
                  AppSpacing.xxxl * 3,
                ),
                itemCount: complaints.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.cardGap),
                itemBuilder: (context, i) {
                  final c = complaints[i];
                  return AppCard(
                    onTap: () => context.push(Routes.complaintDetail(c.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.subject,
                                style: AppTypography.titleMd,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusBadge(
                              label: c.status.label,
                              tone: c.status.tone,
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${c.reference} · ${c.clientName}',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          c.description,
                          style: AppTypography.bodySm,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ComplaintDetailScreen extends ConsumerWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_complaintProvider(complaintId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Complaint Detail')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => const EmptyState(
          icon: Icons.search_off,
          title: 'Complaint not found',
        ),
        data: (c) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.subject, style: AppTypography.h3),
                        ),
                        StatusBadge(label: c.status.label, tone: c.status.tone),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(c.reference, style: AppTypography.caption),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              AppCard(
                child: Column(
                  children: [
                    KeyValueRow(label: 'Client', value: c.clientName),
                    KeyValueRow(label: 'Product', value: c.productName),
                    KeyValueRow(label: 'Mobile', value: c.mobile),
                    KeyValueRow(label: 'Email', value: c.email),
                    KeyValueRow(
                      label: 'Raised on',
                      value: Fmt.date(c.createdAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              const SectionHeader(title: 'Description'),
              AppCard(child: Text(c.description, style: AppTypography.body)),
              if (c.resolution != null) ...[
                const SizedBox(height: AppSpacing.cardGap),
                const SectionHeader(title: 'Resolution'),
                AppCard(
                  color: AppColors.successSoft,
                  borderColor: Colors.transparent,
                  child: Text(
                    c.resolution!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),
            ],
          );
        },
      ),
    );
  }
}

class NewComplaintScreen extends ConsumerStatefulWidget {
  const NewComplaintScreen({super.key});

  @override
  ConsumerState<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends ConsumerState<NewComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();

  Client? _client;
  Product? _product;
  bool _submitting = false;
  final List<String> _attachments = [];
  bool _attaching = false;

  @override
  void dispose() {
    for (final c in [_subject, _description, _mobile, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _attachPhoto() async {
    if (_attaching) return;
    setState(() => _attaching = true);
    try {
      if (!isLive) {
        setState(
          () => _attachments.add('complaint-${_attachments.length + 1}.jpg'),
        );
        return;
      }
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photos must be under 8 MB.')),
        );
        return;
      }
      final path = await ref.read(complaintRepositoryProvider).uploadAttachment(
            bytes: bytes,
            mimeType: file.mimeType ?? 'image/jpeg',
            fileName: file.name,
          );
      if (!mounted) return;
      setState(() => _attachments.add(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(
              e,
              fallback: 'Could not attach that photo.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _client == null) return;
    setState(() => _submitting = true);

    try {
      await ref
          .read(complaintRepositoryProvider)
          .create(
            Complaint(
              id: const Uuid().v4(),
              reference:
                  'CMP-${DateTime.now().millisecondsSinceEpoch % 10000}',
              clientId: _client!.id,
              clientName: _client!.name,
              subject: _subject.text.trim(),
              description: _description.text.trim(),
              status: ComplaintStatus.open,
              createdAt: DateTime.now(),
              productId: _product?.id,
              productName: _product?.name,
              mobile:
                  _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
              attachmentPaths: List.of(_attachments),
            ),
          );

      if (!mounted) return;
      ref.bumpRevision();
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
      setState(() => _submitting = false);
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Complaint raised.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(
              e,
              fallback: 'Could not raise the complaint. Try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(_commClientsProvider);
    final productsAsync = ref.watch(_commProductsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Raise Complaint')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: 'Submit',
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            clientsAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const ErrorState(compact: true),
              data: (clients) => DropdownField<Client>(
                label: 'Client',
                required: true,
                hint: 'Select a client',
                items: clients,
                value: _client,
                itemLabel: (c) => c.name,
                searchable: true,
                onChanged: (v) => setState(() {
                  _client = v;
                  _mobile.text = v?.mobile ?? '';
                  _email.text = v?.email ?? '';
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Subject',
              required: true,
              controller: _subject,
              validator: (v) => Validate.required(v, 'Subject'),
            ),
            const SizedBox(height: AppSpacing.lg),
            productsAsync.when(
              loading: () => const Skeleton(height: 48),
              error: (_, _) => const SizedBox.shrink(),
              data: (products) => DropdownField<Product>(
                label: 'Product',
                hint: 'If product-related',
                items: products,
                value: _product,
                itemLabel: (p) => p.name,
                onChanged: (v) => setState(() => _product = v),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Mobile',
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Description',
              required: true,
              controller: _description,
              maxLines: 5,
              hint: 'Describe the issue in detail',
              validator: (v) => Validate.required(v, 'Description'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Attachment', style: AppTypography.bodySm),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: _attaching
                  ? 'Uploading…'
                  : _attachments.isEmpty
                      ? 'Attach photo'
                      : 'Attach another',
              icon: Icons.photo_camera_outlined,
              small: true,
              onPressed: _attaching || _submitting ? null : _attachPhoto,
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final path in _attachments)
                    InputChip(
                      label: Text(
                        storageDisplayName(path),
                        style: AppTypography.caption,
                      ),
                      onDeleted: _attaching
                          ? null
                          : () => setState(() => _attachments.remove(path)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

final _commProductsProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(businessRepositoryProvider).products(),
);
