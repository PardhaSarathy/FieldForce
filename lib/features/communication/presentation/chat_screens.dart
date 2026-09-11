import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/location/location_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_glow.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/engagement.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import '../../shell/presentation/app_shell.dart';

/// Two-account QA: one Chrome profile shares Supabase auth. Use a second
/// profile or an incognito window so MR and ASM sessions stay distinct.
final _chatQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final _threadsProvider = FutureProvider.autoDispose<List<ChatThread>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref
      .watch(chatRepositoryProvider)
      .threads(query: ref.watch(_chatQueryProvider));
});

final _chatDirectoryProvider = FutureProvider.autoDispose<List<Employee>>((ref) {
  final query = ref.watch(_chatQueryProvider).trim();
  return ref.watch(chatRepositoryProvider).directory(query: query);
});

final _membersProvider =
    FutureProvider.autoDispose.family<List<Employee>, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(chatRepositoryProvider).members(id);
});

final _allDirectoryProvider = FutureProvider.autoDispose<List<Employee>>((ref) {
  return ref.watch(chatRepositoryProvider).directory();
});

final _messageMemory = <String, List<ChatMessage>>{};

final _messagesProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  final msgs = await ref.watch(chatRepositoryProvider).messages(id);
  _messageMemory[id] = msgs;
  return msgs;
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

  Future<void> _refresh() async {
    ref.invalidate(_threadsProvider);
    ref.invalidate(_chatDirectoryProvider);
    ref.invalidate(unreadChatsProvider);
    await ref.read(_threadsProvider.future);
  }

  Future<void> _openDirect(Employee person) async {
    try {
      final threadId =
          await ref.read(chatRepositoryProvider).findOrCreateDirect(person.id);
      ref.invalidate(_threadsProvider);
      ref.invalidate(unreadChatsProvider);
      if (!mounted) return;
      context.push(Routes.chatDetail(threadId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(e, fallback: 'Could not open that chat.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_threadsProvider);
    final peopleAsync = ref.watch(_chatDirectoryProvider);
    final query = ref.watch(_chatQueryProvider).trim();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Chats'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => openAppDrawer(ref),
        ),
        actions: [
          IconButton(
            tooltip: 'New group',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => context.push(Routes.chatNewGroup),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.md,
            ),
            child: SearchField(
              controller: _search,
              hint: 'Search chats or teammates',
              onChanged: (v) => ref.read(_chatQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (e, _) => ErrorState(
                message: readablePostgrestError(
                  e,
                  fallback: 'Could not load conversations.',
                ),
                onRetry: _refresh,
              ),
              data: (threads) {
                final me = ref.watch(sessionProvider).employee.id;
                final people = query.isEmpty
                    ? const <Employee>[]
                    : (peopleAsync.valueOrNull ?? const <Employee>[]);
                final existingPeerIds = <String>{};
                final directByPeer = <String, ChatThread>{};
                for (final t in threads) {
                  if (t.kind != ChatThreadKind.direct) continue;
                  final peer = t.peerId ??
                      t.participantIds.where((id) => id != me).firstOrNull;
                  if (peer == null) continue;
                  existingPeerIds.add(peer);
                  directByPeer.putIfAbsent(peer, () => t);
                }

                if (threads.isEmpty && people.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.5,
                          child: EmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: query.isEmpty
                                ? 'No conversations yet'
                                : 'No matches',
                            message: query.isEmpty
                                ? 'Message your ASM or a teammate to start.'
                                : 'Try another name, code, or designation.',
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final pinned = threads.where((t) => t.isPinned).toList();
                final rest = threads.where((t) => !t.isPinned).toList();

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.md,
                      AppSpacing.screenH,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      if (people.isNotEmpty) ...[
                        SectionHeader(title: 'People matching “$query”'),
                        for (final person in people)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.cardGap,
                            ),
                            child: AppCard(
                              onTap: () async {
                                final existing = directByPeer[person.id];
                                if (existing != null) {
                                  if (!mounted) return;
                                  context.push(Routes.chatDetail(existing.id));
                                  return;
                                }
                                await _openDirect(person);
                              },
                              child: Row(
                                children: [
                                  AppAvatar(name: person.name),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          person.name,
                                          style: AppTypography.titleMd,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          existingPeerIds.contains(person.id)
                                              ? 'Open chat · ${person.subtitle}'
                                              : person.subtitle,
                                          style: AppTypography.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (pinned.isNotEmpty) ...[
                        const SectionHeader(title: 'Pinned'),
                        for (final t in pinned)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.cardGap,
                            ),
                            child: _ThreadCard(thread: t),
                          ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (rest.isNotEmpty) ...[
                        const SectionHeader(title: 'All conversations'),
                        for (final t in rest)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.cardGap,
                            ),
                            child: _ThreadCard(thread: t),
                          ),
                      ],
                    ],
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

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final previewIcon = switch (thread.lastMessageKind) {
      ChatMessageKind.image => Icons.photo_outlined,
      ChatMessageKind.location ||
      ChatMessageKind.liveLocation => Icons.location_on_outlined,
      _ => null,
    };
    return AppCard(
      onTap: () => context.push(Routes.chatDetail(thread.id)),
      child: Row(
        children: [
          thread.kind == ChatThreadKind.direct
              ? AppAvatar(
                  name: thread.title,
                  showOnlineDot: true,
                  isOnline: thread.isOnline,
                )
              : IconTile(
                  icon: thread.kind == ChatThreadKind.announcement
                      ? Icons.campaign_outlined
                      : Icons.groups_outlined,
                  size: 40,
                ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.title,
                        style: AppTypography.titleMd,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      Fmt.timeAgo(thread.lastMessageAt),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (previewIcon != null) ...[
                      Icon(
                        previewIcon,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (thread.isMuted)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.volume_off_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        thread.lastMessage.isEmpty
                            ? 'No messages yet'
                            : thread.lastMessage,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (thread.unreadCount > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppGlow.fill(AppColors.brand),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: AppGlow.halo(AppColors.brand, 22),
                        ),
                        child: Text(
                          '${thread.unreadCount}',
                          style: AppTypography.badge.copyWith(
                            color: AppColors.wellGlyph,
                          ),
                        ),
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

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _input = TextEditingController();
  final _pending = <ChatMessage>[];
  final _pendingImages = <String, ({List<int> bytes, String mime, String fileName})>{};
  Timer? _poll;
  Timer? _liveTick;
  StreamSubscription<void>? _watch;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refreshQuiet());
    _watch = ref
        .read(chatRepositoryProvider)
        .watchThread(widget.threadId)
        .listen((_) => _refreshQuiet());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _liveTick?.cancel();
    _watch?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _refreshQuiet() {
    if (!mounted) return;
    ref.invalidate(_messagesProvider(widget.threadId));
    ref.invalidate(_threadsProvider);
  }

  Future<void> _markRead() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.markDelivered(widget.threadId);
      await repo.markRead(widget.threadId);
      ref.invalidate(_threadsProvider);
      ref.invalidate(unreadChatsProvider);
      // Reading the conversation also clears its notification, server-side.
      // Without these the Notifications screen keeps showing a row for a
      // conversation the rep is looking at.
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    final local = ChatMessage(
      id: 'local-${const Uuid().v4()}',
      threadId: widget.threadId,
      senderId: ref.read(sessionProvider).employee.id,
      senderName: ref.read(sessionProvider).employee.name,
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
      status: ChatDeliveryStatus.sending,
    );
    setState(() => _pending.add(local));
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).send(widget.threadId, text);
      if (!mounted) return;
      setState(() => _pending.removeWhere((m) => m.id == local.id));
      _refreshQuiet();
      ref.invalidate(unreadChatsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _pending.indexWhere((m) => m.id == local.id);
        if (i >= 0) {
          _pending[i] = local.copyWith(status: ChatDeliveryStatus.failed);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(e, fallback: 'Message was not sent.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _retry(ChatMessage failed) async {
    final payload = _pendingImages.remove(failed.id);
    setState(() => _pending.removeWhere((m) => m.id == failed.id));
    if (payload != null) {
      await _uploadImage(payload.bytes, payload.mime, payload.fileName);
      return;
    }
    _input.text = failed.text;
    await _send();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : source,
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
      final mime = file.mimeType ?? 'image/jpeg';
      await _uploadImage(bytes, mime, file.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(e, fallback: 'Could not send that photo.'),
          ),
        ),
      );
    }
  }

  Future<void> _uploadImage(List<int> bytes, String mime, String fileName) async {
    final local = ChatMessage(
      id: 'local-${const Uuid().v4()}',
      threadId: widget.threadId,
      senderId: ref.read(sessionProvider).employee.id,
      senderName: ref.read(sessionProvider).employee.name,
      text: 'Photo',
      sentAt: DateTime.now(),
      isMine: true,
      kind: ChatMessageKind.image,
      status: ChatDeliveryStatus.sending,
    );
    _pendingImages[local.id] = (bytes: bytes, mime: mime, fileName: fileName);
    setState(() => _pending.add(local));
    try {
      await ref.read(chatRepositoryProvider).sendImage(
            widget.threadId,
            bytes: bytes,
            mimeType: mime,
            fileName: fileName,
          );
      _pendingImages.remove(local.id);
      if (!mounted) return;
      setState(() => _pending.removeWhere((m) => m.id == local.id));
      _refreshQuiet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _pending.indexWhere((m) => m.id == local.id);
        if (i >= 0) {
          _pending[i] = local.copyWith(status: ChatDeliveryStatus.failed);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(e, fallback: 'Could not send that photo.'),
          ),
        ),
      );
    }
  }

  Future<GeoPointFix?> _fix() async {
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (result is LocationSuccess) {
      return GeoPointFix(result.point.latitude, result.point.longitude, result.accuracyMeters);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((result as LocationError).message)),
      );
    }
    return null;
  }

  Future<void> _sendLocation() async {
    final fix = await _fix();
    if (fix == null) return;
    try {
      await ref.read(chatRepositoryProvider).sendLocation(
            widget.threadId,
            latitude: fix.lat,
            longitude: fix.lng,
            accuracy: fix.accuracy,
          );
      _refreshQuiet();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(e, fallback: 'Could not share location.'),
          ),
        ),
      );
    }
  }

  Future<void> _startLive(int minutes) async {
    final fix = await _fix();
    if (fix == null) return;
    try {
      final sent = await ref.read(chatRepositoryProvider).startLiveLocation(
            widget.threadId,
            latitude: fix.lat,
            longitude: fix.lng,
            accuracy: fix.accuracy,
            minutes: minutes,
          );
      _refreshQuiet();
      _liveTick?.cancel();
      _liveTick = Timer.periodic(const Duration(seconds: 20), (_) async {
        if (!mounted || sent.liveLocationId == null) return;
        final next = await ref.read(locationServiceProvider).currentPosition();
        if (next is! LocationSuccess) return;
        try {
          await ref.read(chatRepositoryProvider).updateLiveLocation(
                sent.liveLocationId!,
                latitude: next.point.latitude,
                longitude: next.point.longitude,
                accuracy: next.accuracyMeters,
              );
          _refreshQuiet();
        } catch (_) {
          _liveTick?.cancel();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(e, fallback: 'Could not start live location.'),
          ),
        ),
      );
    }
  }

  Future<void> _attachSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Location'),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendLocation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Live location'),
                onTap: () {
                  Navigator.pop(ctx);
                  _liveDurationSheet();
                },
              ),
              const ListTile(
                leading: Icon(Icons.insert_drive_file_outlined),
                title: Text('Document'),
                subtitle: Text('Coming later'),
                enabled: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _liveDurationSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('15 minutes'),
              onTap: () {
                Navigator.pop(ctx);
                _startLive(15);
              },
            ),
            ListTile(
              title: const Text('1 hour'),
              onTap: () {
                Navigator.pop(ctx);
                _startLive(60);
              },
            ),
            ListTile(
              title: const Text('8 hours'),
              onTap: () {
                Navigator.pop(ctx);
                _startLive(480);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_messagesProvider(widget.threadId));
    final threads = ref.watch(_threadsProvider).valueOrNull ?? [];
    final thread = threads.where((t) => t.id == widget.threadId).firstOrNull;
    final liveMine = [
      ...?async.valueOrNull,
      ..._pending,
    ].where((m) => m.isMine && m.liveIsActive && m.liveLocationId != null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => context.push(Routes.chatInfo(widget.threadId)),
          child: Row(
            children: [
              thread == null || thread.kind != ChatThreadKind.direct
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
      ),
      body: Column(
        children: [
          if (liveMine.isNotEmpty)
            Material(
              color: AppColors.surface,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.my_location, color: AppColors.brand),
                title: const Text('Sharing live location'),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(chatRepositoryProvider)
                        .stopLiveLocation(liveMine.first.liveLocationId!);
                    _liveTick?.cancel();
                    _refreshQuiet();
                  },
                  child: const Text('Stop'),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_messagesProvider(widget.threadId));
                await ref.read(_messagesProvider(widget.threadId).future);
                await _markRead();
              },
              child: async.when(
                loading: () {
                  final cached = _messageMemory[widget.threadId];
                  if (cached != null) {
                    return _messageList(cached, thread);
                  }
                  return const LoadingState();
                },
                error: (e, _) => ErrorState(
                  message: readablePostgrestError(
                    e,
                    fallback: 'Could not load messages.',
                  ),
                  onRetry: () =>
                      ref.invalidate(_messagesProvider(widget.threadId)),
                ),
                data: (messages) => _messageList(messages, thread),
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
                      onPressed: _attachSheet,
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
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 18),
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

  Widget _messageList(List<ChatMessage> messages, ChatThread? thread) {
    final all = [...messages, ..._pending]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    if (all.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No messages yet',
            message: 'Say hello to start the conversation.',
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenH),
      itemCount: all.length,
      itemBuilder: (context, i) {
        final message = all[i];
        final showDate = i == 0 || !_sameDay(all[i - 1].sentAt, message.sentAt);
        return Column(
          children: [
            if (showDate)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  Fmt.date(message.sentAt),
                  style: AppTypography.caption,
                ),
              ),
            _MessageBubble(
              message: message,
              showSender: thread?.kind != ChatThreadKind.direct,
              onRetry: message.status == ChatDeliveryStatus.failed
                  ? () => _retry(message)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class GeoPointFix {
  const GeoPointFix(this.lat, this.lng, this.accuracy);
  final double lat;
  final double lng;
  final double? accuracy;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.showSender = true,
    this.onRetry,
  });

  final ChatMessage message;
  final bool showSender;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final ink = isMine ? Colors.white : AppColors.textPrimary;
    final dim = isMine ? Colors.white70 : AppColors.textSecondary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onRetry,
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
            color: isMine ? null : AppColors.surface,
            gradient: isMine ? AppGlow.fill(AppColors.brand) : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.sm),
              bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.lg),
            ),
            border: isMine ? null : Border.all(color: AppColors.border),
            boxShadow: isMine
                ? AppGlow.halo(AppColors.brand, 44, strength: 0.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine && showSender)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    message.senderName,
                    style: AppTypography.badge.copyWith(color: AppColors.brand),
                  ),
                ),
              _bubbleBody(context, ink, dim),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Fmt.time(message.sentAt),
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: dim,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      switch (message.status) {
                        ChatDeliveryStatus.sending => Icons.schedule,
                        ChatDeliveryStatus.failed => Icons.error_outline,
                        ChatDeliveryStatus.read => Icons.done_all,
                        ChatDeliveryStatus.delivered => Icons.done_all,
                        ChatDeliveryStatus.sent => Icons.done,
                      },
                      size: 14,
                      color: message.status == ChatDeliveryStatus.failed
                          ? Colors.white
                          : dim,
                    ),
                  ],
                ],
              ),
              if (onRetry != null)
                Text(
                  'Tap to retry',
                  style: AppTypography.caption.copyWith(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubbleBody(BuildContext context, Color ink, Color dim) {
    switch (message.kind) {
      case ChatMessageKind.image:
        final url = message.attachments
            .map((a) => a.signedUrl)
            .whereType<String>()
            .firstOrNull;
        if (url == null) {
          return Icon(Icons.photo, color: ink);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.network(
            url,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(Icons.broken_image, color: ink),
          ),
        );
      case ChatMessageKind.location:
      case ChatMessageKind.liveLocation:
        return _LocationCard(message: message, ink: ink, dim: dim);
      case ChatMessageKind.system:
        return Text(message.text, style: AppTypography.caption.copyWith(color: dim));
      case ChatMessageKind.text:
        return Text(message.text, style: AppTypography.body.copyWith(color: ink));
    }
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.message,
    required this.ink,
    required this.dim,
  });

  final ChatMessage message;
  final Color ink;
  final Color dim;

  @override
  Widget build(BuildContext context) {
    final lat = message.latitude;
    final lng = message.longitude;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              message.kind == ChatMessageKind.liveLocation
                  ? Icons.my_location
                  : Icons.location_on,
              color: ink,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message.kind == ChatMessageKind.liveLocation
                    ? (message.liveIsActive ? 'Live location' : 'Live location ended')
                    : 'Location',
                style: AppTypography.titleSm.copyWith(color: ink),
              ),
            ),
          ],
        ),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 4),
          Text(
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
            '${message.accuracyMeters == null ? '' : ' · ±${message.accuracyMeters!.round()}m'}',
            style: AppTypography.caption.copyWith(color: dim),
          ),
          TextButton(
            onPressed: () async {
              await launchUrl(
                Uri.parse('https://www.google.com/maps?q=$lat,$lng'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: Text('Open in maps', style: TextStyle(color: ink)),
          ),
        ],
      ],
    );
  }
}

class ChatNewGroupScreen extends ConsumerStatefulWidget {
  const ChatNewGroupScreen({super.key});

  @override
  ConsumerState<ChatNewGroupScreen> createState() => _ChatNewGroupScreenState();
}

class _ChatNewGroupScreenState extends ConsumerState<ChatNewGroupScreen> {
  final _name = TextEditingController();
  final _selected = <String>{};
  ChatThreadKind _kind = ChatThreadKind.group;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final me = ref.read(sessionProvider).employee.id;
    if (_name.text.trim().isEmpty || _selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(chatRepositoryProvider).createGroup(
            subject: _name.text.trim(),
            participantIds: [..._selected, me],
            kind: _kind,
          );
      ref.invalidate(_threadsProvider);
      if (!mounted) return;
      context.push(Routes.chatDetail(id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            readablePostgrestError(e, fallback: 'Could not create the group.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(_allDirectoryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('New group')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: 'Group name'),
          ),
          const SizedBox(height: AppSpacing.md),
          FilterChipBar<ChatThreadKind>(
            options: const [
              ChatThreadKind.group,
              ChatThreadKind.community,
              ChatThreadKind.announcement,
            ],
            selected: _kind,
            padding: EdgeInsets.zero,
            labelOf: (k) => switch (k) {
              ChatThreadKind.community => 'Community',
              ChatThreadKind.announcement => 'Announce',
              _ => 'Team',
            },
            onSelected: (k) => setState(() => _kind = k),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Members'),
          people.when(
            loading: () => const Column(
              children: [
                Skeleton(height: 56),
                SizedBox(height: AppSpacing.sm),
                Skeleton(height: 56),
                SizedBox(height: AppSpacing.sm),
                Skeleton(height: 56),
              ],
            ),
            error: (e, _) => ErrorState(
              message: readablePostgrestError(e, fallback: 'Could not load people.'),
            ),
            data: (list) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final person in list)
                  CheckboxListTile(
                    value: _selected.contains(person.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(person.id);
                      } else {
                        _selected.remove(person.id);
                      }
                    }),
                    title: Text(person.name),
                    subtitle: Text(person.subtitle),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _saving ? 'Creating…' : 'Create',
            onPressed: _saving ? null : _create,
          ),
        ],
      ),
    );
  }
}

class ChatInfoScreen extends ConsumerWidget {
  const ChatInfoScreen({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(_threadsProvider).valueOrNull ?? [];
    final thread = threads.where((t) => t.id == threadId).firstOrNull;
    final members = ref.watch(_membersProvider(threadId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(thread?.title ?? 'Chat info')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          Text(thread?.subtitle ?? '', style: AppTypography.bodySm),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Members'),
          members.when(
            loading: () => const Column(
              children: [
                Skeleton(height: 56),
                SizedBox(height: AppSpacing.sm),
                Skeleton(height: 56),
                SizedBox(height: AppSpacing.sm),
                Skeleton(height: 56),
              ],
            ),
            error: (e, _) => ErrorState(
              message: readablePostgrestError(e, fallback: 'Could not load members.'),
            ),
            data: (list) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final person in list)
                  ListTile(
                    leading: AppAvatar(name: person.name),
                    title: Text(person.name),
                    subtitle: Text(person.subtitle),
                  ),
              ],
            ),
          ),
          if (thread != null && thread.kind != ChatThreadKind.direct) ...[
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(
              label: 'Leave group',
              onPressed: () async {
                try {
                  await ref.read(chatRepositoryProvider).leave(threadId);
                  ref.invalidate(_threadsProvider);
                  if (!context.mounted) return;
                  context.go(Routes.chat);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        readablePostgrestError(
                          e,
                          fallback: 'Could not leave this group.',
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
