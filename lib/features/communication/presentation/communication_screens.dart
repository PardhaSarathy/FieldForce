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
import '../../../shared/models/client.dart';
import '../../../shared/models/engagement.dart';
import '../../../shared/models/field_ops.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

// =================================================================== chat ==

final _chatQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final _threadsProvider = FutureProvider.autoDispose<List<ChatThread>>((ref) {
  return ref
      .watch(chatRepositoryProvider)
      .threads(query: ref.watch(_chatQueryProvider));
});

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_threadsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chats')),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md,
            ),
            child: SearchField(
              controller: _search,
              onChanged: (v) => ref.read(_chatQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) => const ErrorState(),
              data: (threads) {
                if (threads.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No conversations',
                    message: 'Messages from your team appear here.',
                  );
                }

                final pinned = threads.where((t) => t.isPinned).toList();
                final rest = threads.where((t) => !t.isPinned).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.md,
                    AppSpacing.screenH, AppSpacing.xxxl,
                  ),
                  children: [
                    if (pinned.isNotEmpty) ...[
                      const SectionHeader(title: 'Pinned'),
                      for (final t in pinned)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.cardGap),
                          child: _ThreadCard(thread: t),
                        ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (rest.isNotEmpty) ...[
                      const SectionHeader(title: 'All conversations'),
                      for (final t in rest)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.cardGap),
                          child: _ThreadCard(thread: t),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.chatDetail(thread.id)),
      child: Row(
        children: [
          thread.isGroup
              ? const IconTile(icon: Icons.groups_outlined, size: 40)
              : AppAvatar(
                  name: thread.title,
                  showOnlineDot: true,
                  isOnline: thread.isOnline,
                ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(thread.title,
                          style: AppTypography.titleMd,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(Fmt.timeAgo(thread.lastMessageAt),
                        style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.lastMessage,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (thread.unreadCount > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('${thread.unreadCount}',
                            style: AppTypography.badge
                                .copyWith(color: Colors.white)),
                      ),
                    ],
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

final _messagesProvider =
    FutureProvider.autoDispose.family<List<ChatMessage>, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(chatRepositoryProvider).messages(id);
});

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(chatRepositoryProvider).send(widget.threadId, text);
    ref.invalidate(_messagesProvider(widget.threadId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_messagesProvider(widget.threadId));
    final threads = ref.watch(_threadsProvider).valueOrNull ?? [];
    final thread = threads.where((t) => t.id == widget.threadId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            thread == null || thread.isGroup
                ? const IconTile(icon: Icons.groups_outlined, size: 34)
                : AppAvatar(name: thread.title, size: AppSizes.avatarSm),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(thread?.title ?? 'Chat', style: AppTypography.titleMd),
                  if (thread?.subtitle != null)
                    Text(
                      thread!.isOnline ? 'Online' : thread.subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: thread.isOnline
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const LoadingState(),
              error: (_, _) => const ErrorState(),
              data: (messages) => messages.isEmpty
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No messages yet',
                      message: 'Say hello to start the conversation.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.screenH),
                      itemCount: messages.length,
                      itemBuilder: (context, i) =>
                          _MessageBubble(message: messages[i]),
                    ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: AppColors.textSecondary,
                      onPressed: () {},
                    ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        style: AppTypography.body,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      onPressed: _send,
                      icon: const Icon(Icons.send, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.sm),
            bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.lg),
          ),
          border: isMine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(message.senderName,
                    style: AppTypography.badge
                        .copyWith(color: AppColors.brand)),
              ),
            Text(
              message.text,
              style: AppTypography.body.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              Fmt.time(message.sentAt),
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: isMine ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================== resources ==

final _resourceCategoryProvider =
    StateProvider.autoDispose<String>((ref) => 'All');

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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Resources')),
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
                      message: 'Marketing material shared with the field will '
                          'appear here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, 0,
                        AppSpacing.screenH, AppSpacing.xxxl,
                      ),
                      itemCount: resources.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.cardGap),
                      itemBuilder: (context, i) =>
                          _ResourceCard(resource: resources[i]),
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
                  Text(resource.description!,
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Resource')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(
            label: 'Share',
            icon: Icons.ios_share_outlined,
            onPressed: () {},
          ),
          PrimaryButton(
            label: 'Download',
            icon: Icons.download_outlined,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Downloads arrive with the backend.')),
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
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(
                switch (resource.fileType) {
                  'VIDEO' => Icons.play_circle_outline,
                  'PDF' => Icons.picture_as_pdf_outlined,
                  _ => Icons.description_outlined,
                },
                size: 56,
                color: AppColors.brand,
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
                      label: 'Last updated', value: Fmt.date(resource.updatedAt)),
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

final _resourceProvider =
    FutureProvider.autoDispose.family<Resource, String>(
  (ref, id) => ref.watch(resourceRepositoryProvider).byId(id),
);

// ================================================================ surveys ==

final _surveysProvider = FutureProvider.autoDispose<List<SurveyResponse>>((ref) {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Surveys')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newSurvey),
        icon: const Icon(Icons.add),
        label: const Text('New survey'),
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
                  AppSpacing.screenH, AppSpacing.screenH,
                  AppSpacing.screenH, AppSpacing.xxxl * 3,
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
                              child: Text(s.clientName,
                                  style: AppTypography.titleMd),
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
                        Text('${s.clientType.label} · '
                            '${Fmt.date(s.submittedAt)}',
                            style: AppTypography.caption),
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
    await ref.read(surveyRepositoryProvider).create(
          SurveyResponse(
            id: const Uuid().v4(),
            employeeId: session.employee.id,
            clientId: _client!.id,
            clientName: _client!.name,
            clientType: _client!.type,
            submittedAt: DateTime.now(),
            feedback: _feedback.text.trim(),
            remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
            locationName: _client!.areaName,
            rating: _rating > 0 ? _rating : null,
          ),
        );

    if (!mounted) return;
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Survey submitted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(_commClientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    onPressed: () => setState(() => _rating = i == _rating ? 0 : i),
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
            AppTextField(
              label: 'Remarks',
              controller: _remarks,
              maxLines: 2,
            ),
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

class ComplaintListScreen extends ConsumerWidget {
  const ComplaintListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_complaintsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Complaints')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newComplaint),
        icon: const Icon(Icons.add),
        label: const Text('Raise'),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (complaints) => complaints.isEmpty
            ? EmptyState(
                icon: Icons.report_problem_outlined,
                title: 'No complaints',
                message: 'Raise product or service issues on behalf of clients.',
                actionLabel: 'Raise a complaint',
                onAction: () => context.push(Routes.newComplaint),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.screenH,
                  AppSpacing.screenH, AppSpacing.xxxl * 3,
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
                              child: Text(c.subject,
                                  style: AppTypography.titleMd,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            StatusBadge(
                                label: c.status.label,
                                tone: c.status.tone,
                                dense: true),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('${c.reference} · ${c.clientName}',
                            style: AppTypography.caption),
                        const SizedBox(height: AppSpacing.sm),
                        Text(c.description,
                            style: AppTypography.bodySm,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
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
    final async = ref.watch(_complaintsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Complaint')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (complaints) {
          final c = complaints.where((x) => x.id == complaintId).firstOrNull;
          if (c == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Complaint not found',
            );
          }

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
                    KeyValueRow(label: 'Raised on', value: Fmt.date(c.createdAt)),
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
                  child: Text(c.resolution!,
                      style: AppTypography.body
                          .copyWith(color: AppColors.success)),
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

  @override
  void dispose() {
    for (final c in [_subject, _description, _mobile, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _client == null) return;
    setState(() => _submitting = true);

    await ref.read(complaintRepositoryProvider).create(
          Complaint(
            id: const Uuid().v4(),
            reference: 'CMP-${DateTime.now().millisecondsSinceEpoch % 10000}',
            clientId: _client!.id,
            clientName: _client!.name,
            subject: _subject.text.trim(),
            description: _description.text.trim(),
            status: ComplaintStatus.open,
            createdAt: DateTime.now(),
            productId: _product?.id,
            productName: _product?.name,
            mobile: _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          ),
        );

    if (!mounted) return;
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Complaint raised.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(_commClientsProvider);
    final productsAsync = ref.watch(_commProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
              label: 'Attach photo',
              icon: Icons.photo_camera_outlined,
              small: true,
              onPressed: () {},
            ),
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
