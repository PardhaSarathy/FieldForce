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
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import '../../activity/presentation/widgets/activity_card.dart';

// ============================================================ client list ==

enum ClientFilter {
  all('All', null),
  doctors('Doctors', ClientType.doctor),
  hospitals('Hospitals', ClientType.hospital),
  chemists('Chemists', ClientType.chemist),
  other('Other', ClientType.stockist);

  const ClientFilter(this.label, this.type);
  final String label;
  final ClientType? type;
}

final _clientQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final _clientFilterProvider = StateProvider.autoDispose<ClientFilter>(
  (ref) => ClientFilter.all,
);

final _clientListProvider = FutureProvider.autoDispose<List<Client>>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(clientRepositoryProvider)
      .list(
        session,
        query: ref.watch(_clientQueryProvider),
        type: ref.watch(_clientFilterProvider).type,
      );
});

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_clientFilterProvider);
    final listAsync = ref.watch(_clientListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: AppFab(
        onPressed: () => context.push(Routes.newClient),
        icon: Icons.person_add_alt,
        label: 'Add New Client',
      ),
      body: Column(
        children: [
          // On the wash, not on a white slab. The field is white and the
          // ground is not, which is all the separation a search box needs —
          // the slab only added a second edge under the app bar's.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.md,
            ),
            child: SearchField(
              hint: 'Search by name, specialty or area',
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(_clientQueryProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilterChipBar<ClientFilter>(
            options: ClientFilter.values,
            selected: filter,
            labelOf: (f) => f.label,
            onSelected: (f) =>
                ref.read(_clientFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: listAsync.when(
              loading: () => const SkeletonList(),
              error: (_, _) => ErrorState(
                onRetry: () => ref.invalidate(_clientListProvider),
              ),
              data: (clients) {
                if (clients.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: _searchController.text.isEmpty
                        ? 'No clients yet'
                        : 'No matching clients',
                    message: _searchController.text.isEmpty
                        ? 'Register the doctors, hospitals and chemists in '
                              'your territory to start planning visits.'
                        : 'Try a different name, specialty or area.',
                    actionLabel: _searchController.text.isEmpty
                        ? 'Add your first client'
                        : null,
                    onAction: () => context.push(Routes.newClient),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    0,
                    AppSpacing.screenH,
                    AppSpacing.xxxl * 3,
                  ),
                  itemCount: clients.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) => Arrive.staggered(
                    index: i,
                    child: _ClientCard(client: clients[i]),
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

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.clientDetail(client.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(name: client.name, heroTag: 'client-${client.id}'),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: AppTypography.titleMd,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  client.subtitle,
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.areaName,
                        style: AppTypography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (client.lastVisitAt != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      // Also flexible: on a narrow card the category badge can
                      // squeeze this column hard enough that even the date
                      // needs to give way.
                      Flexible(
                        child: Text(
                          'Last: ${Fmt.dateShort(client.lastVisitAt!)}',
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
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(
            label: client.category.label,
            tone: client.category.tone,
            dense: true,
          ),
        ],
      ),
    );
  }
}

// ========================================================== client detail ==

final _clientProvider = FutureProvider.autoDispose.family<Client, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(clientRepositoryProvider).byId(id);
});

final _clientHistoryProvider = FutureProvider.autoDispose
    .family<List<Activity>, String>((ref, id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(clientRepositoryProvider).historyOf(id);
    });

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(_clientProvider(clientId));
    final historyAsync = ref.watch(_clientHistoryProvider(clientId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Client Detail'),
        actions: [
          // A doctor moves clinic, changes number, retires. Without this the
          // record could only ever be created, never corrected.
          IconButton(
            tooltip: 'Edit client',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.editClient(clientId)),
          ),
        ],
      ),
      bottomNavigationBar: clientAsync.maybeWhen(
        data: (client) => BottomActionBar(
          children: [
            SecondaryButton(
              label: 'Add activity',
              icon: Icons.event_available_outlined,
              onPressed: () =>
                  context.push('${Routes.addActivity}?clientId=${client.id}'),
            ),
            PrimaryButton(
              label: 'Navigate',
              icon: Icons.directions_outlined,
              onPressed: () =>
                  showComingWithBackend(context, 'Turn-by-turn navigation'),
            ),
          ],
        ),
        orElse: () => null,
      ),
      body: clientAsync.when(
        loading: () => const LoadingState(),
        error: (_, _) => ErrorState(
          onRetry: () => ref.invalidate(_clientProvider(clientId)),
        ),
        data: (client) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAvatar(
                        name: client.name,
                        size: AppSizes.avatarLg,
                        heroTag: 'client-${client.id}',
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(client.name, style: AppTypography.h3),
                            const SizedBox(height: 2),
                            Text(client.subtitle, style: AppTypography.bodySm),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      StatusBadge(
                        label: client.category.label,
                        tone: client.category.tone,
                        dense: true,
                      ),
                      if (client.statusLabel != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(
                          label: client.statusLabel!,
                          tone: client.isActive
                              ? StatusTone.success
                              : StatusTone.neutral,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Total visits',
                    value: '${client.totalVisits}',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatTile(
                    label: 'Last visit',
                    value: client.lastVisitAt == null
                        ? '—'
                        : Fmt.dateShort(client.lastVisitAt!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.cardGap),

            // The date was being captured and shown nowhere at all, which made
            // it impossible to act on — the one thing it exists for.
            if (client.specialDate != null) ...[
              const SectionHeader(title: 'Remember'),
              _OccasionCard(client: client),
              const SizedBox(height: AppSpacing.cardGap),
            ],

            const SectionHeader(title: 'Contact'),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(label: 'Designation', value: client.designation),
                  KeyValueRow(
                    label: 'Contact person',
                    value: client.contactPerson,
                  ),
                  KeyValueRow(label: 'Mobile', value: client.mobile),
                  KeyValueRow(label: 'Email', value: client.email),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            const SectionHeader(title: 'Location'),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(label: 'Address', value: client.fullAddress),
                  KeyValueRow(label: 'Area', value: client.areaName),
                  KeyValueRow(label: 'Cluster', value: client.clusterName),
                  KeyValueRow(
                    label: 'Registered GPS',
                    value: client.location?.toString(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            SectionHeader(
              title: 'Visit history',
              actionLabel: 'See all',
              onAction: () => context.push(Routes.clientHistory(client.id)),
            ),
            historyAsync.when(
              loading: () => const Skeleton(height: 90, radius: AppRadius.lg),
              error: (_, _) => const SizedBox.shrink(),
              data: (history) {
                if (history.isEmpty) {
                  return const AppCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.history,
                      title: 'No visits recorded yet',
                      message:
                          'Completed visits to this client will appear here.',
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final a in history.take(3))
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.cardGap,
                        ),
                        child: ActivityCard(activity: a, showDate: true),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class ClientHistoryScreen extends ConsumerWidget {
  const ClientHistoryScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_clientHistoryProvider(clientId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Visit History')),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (history) => history.isEmpty
            ? const EmptyState(
                icon: Icons.history,
                title: 'No visits recorded',
                message: 'Completed visits to this client will appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                itemCount: history.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.cardGap),
                itemBuilder: (context, i) => Arrive.staggered(
                  index: i,
                  child: ActivityCard(activity: history[i], showDate: true),
                ),
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.overline),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.metricSm),
        ],
      ),
    );
  }
}

// ============================================================= new client ==

/// Registering a client captures its GPS position, because that point becomes
/// the reference for every future visit's geo-fence (§20). Getting it wrong
/// here silently breaks verification for months, so the step is prominent and
/// the captured coordinates are shown rather than hidden.
/// The client's special date, as something a rep can act on.
///
/// A date on its own is a fact; "Birthday · in 6 days" is a prompt. The
/// countdown is the whole reason the field exists, so it leads, and the date
/// itself sits underneath for anyone who wants it.
class _OccasionCard extends StatelessWidget {
  const _OccasionCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final days = client.daysUntilOccasion();
    final soon = days != null && days <= 7;

    final when = switch (days) {
      null => '',
      0 => 'Today',
      1 => 'Tomorrow',
      _ => 'In $days days',
    };

    return AppCard(
      child: Row(
        children: [
          IconWell(
            icon: days == 0 ? Icons.celebration_outlined : Icons.cake_outlined,
            size: AppSizes.avatarMd,
            color: soon ? AppColors.brand : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.occasionLabel ?? 'Special date',
                  style: AppTypography.titleMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.dateShort(client.specialDate!),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // A word, never the colour alone.
          StatusBadge(
            label: when,
            tone: soon ? StatusTone.brand : StatusTone.neutral,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Loads a client, then hands it to the shared form.
///
/// A thin wrapper rather than a `Client` route parameter: arriving by deep
/// link or after a process death there is no object to pass, only an id, and a
/// form that takes an id would have to handle its own loading state anyway.
class EditClientScreen extends ConsumerWidget {
  const EditClientScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_clientProvider(clientId))
        .when(
          loading: () => const Scaffold(
            backgroundColor: Colors.transparent,
            body: LoadingState(message: 'Loading client'),
          ),
          error: (_, _) => Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('Edit Client')),
            body: ErrorState(
              onRetry: () => ref.invalidate(_clientProvider(clientId)),
            ),
          ),
          data: (client) => NewClientScreen(existing: client),
        );
  }
}

/// The client form, for both registering and editing.
///
/// One screen rather than two: the fields, the validation and the cascading
/// territory→area pair are identical, and a second copy would drift from this
/// one the first time either changed. [existing] is what switches the mode.
class NewClientScreen extends ConsumerStatefulWidget {
  const NewClientScreen({super.key, this.existing});

  /// Null to register a new client, otherwise the one being edited.
  final Client? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends ConsumerState<NewClientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _designation = TextEditingController();
  final _contact = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _pincode = TextEditingController();

  /// The name as typed, so the duplicate check can watch it.
  ///
  /// Held in state rather than read off the controller in `build`: a
  /// `TextEditingController` does not rebuild the form when its text changes,
  /// so a warning driven straight off `_name.text` would only appear the next
  /// time something *else* rebuilt the screen.
  String _typedName = '';

  /// Chosen from master data, so this is a value rather than typed text.
  String? _specialty;

  SpecialOccasion _occasion = SpecialOccasion.birthday;
  final _occasionNote = TextEditingController();

  ClientType _type = ClientType.doctor;
  ClientListing _listing = ClientListing.unlisted;
  Territory? _territory;
  Area? _area;
  bool _isActive = true;
  DateTime? _specialDate;

  GeoPoint? _captured;
  bool _capturing = false;
  String? _locationError;

  bool _submitting = false;
  Client? _created;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c == null) return;

    _name.text = c.name;
    _designation.text = c.designation ?? '';
    _contact.text = c.contactPerson ?? '';
    _mobile.text = c.mobile ?? '';
    _email.text = c.email ?? '';
    _address.text = c.addressLine ?? '';
    _pincode.text = c.pincode ?? '';
    _occasionNote.text = c.specialOccasionNote ?? '';

    _type = c.type;
    _listing = c.listing;
    _specialty = c.specialty;
    _isActive = c.isActive;
    _specialDate = c.specialDate;
    _occasion = c.specialOccasion ?? SpecialOccasion.birthday;
    _captured = c.location;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _designation,
      _contact,
      _mobile,
      _email,
      _address,
      _pincode,
      _occasionNote,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _locationError = null;
    });

    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;

    switch (result) {
      case LocationSuccess(:final point):
        setState(() {
          _capturing = false;
          _captured = point;
        });
      case LocationError(:final message):
        setState(() {
          _capturing = false;
          _locationError = message;
        });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_area == null) return;

    setState(() => _submitting = true);
    final session = ref.read(sessionProvider);
    final existing = widget.existing;

    final client = Client(
      // An edit keeps the id, and with it every activity, order and expense
      // already pointing at this client.
      id: existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      type: _type,
      areaId: _area!.id,
      areaName: _area!.name,
      territoryId: _area!.territoryId,
      // A chemist has no specialty, and switching type after picking one
      // would otherwise carry it along.
      specialty: _type == ClientType.doctor ? _specialty : null,
      designation: _designation.text.trim().isEmpty
          ? null
          : _designation.text.trim(),
      contactPerson: _contact.text.trim(),
      mobile: _mobile.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      addressLine: _address.text.trim(),
      pincode: _pincode.text.trim().isEmpty ? null : _pincode.text.trim(),
      latitude: _captured?.latitude,
      longitude: _captured?.longitude,
      isActive: _isActive,
      specialDate: _specialDate,
      // Both only mean anything with a date behind them.
      specialOccasion: _specialDate == null ? null : _occasion,
      specialOccasionNote:
          _specialDate != null && _occasion == SpecialOccasion.other
          ? _occasionNote.text.trim()
          : null,
      listing: _listing,
      // Planning priority is head office's call, not something asked for at
      // the roadside. New clients start Regular and are re-graded centrally.
      category: existing?.category ?? ClientCategory.regular,
      ownerEmployeeId: existing?.ownerEmployeeId ?? session.employee.id,
      createdAt: existing?.createdAt ?? DateTime.now(),
      lastVisitAt: existing?.lastVisitAt,
      nextPlannedVisitAt: existing?.nextPlannedVisitAt,
      totalVisits: existing?.totalVisits ?? 0,
      clusterId: existing?.clusterId,
      clusterName: existing?.clusterName,
      syncStatus: ref.read(isOnlineProvider)
          ? SyncStatus.synced
          : SyncStatus.savedLocally,
    );

    final repository = ref.read(clientRepositoryProvider);
    if (widget.isEditing) {
      await repository.update(client);
    } else {
      await repository.create(client);
    }
    if (!mounted) return;

    AppHaptics.success();
    ref.bumpRevision();

    // An edit returns to the record it changed; there is nothing to announce
    // that the updated detail screen does not already show.
    if (widget.isEditing) {
      context.pop();
      return;
    }

    setState(() {
      _submitting = false;
      _created = client;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_created != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SuccessState(
            title: 'Client registered',
            message: '${_created!.name} has been added to your territory.',
            details: AppCard(
              child: Column(
                children: [
                  KeyValueRow(label: 'Type', value: _created!.type.label),
                  KeyValueRow(label: 'Area', value: _created!.areaName),
                  KeyValueRow(
                    label: 'GPS',
                    value: _created!.location?.toString() ?? 'Not captured',
                  ),
                ],
              ),
            ),
            primaryLabel: 'View client',
            onPrimary: () =>
                context.pushReplacement(Routes.clientDetail(_created!.id)),
            secondaryLabel: 'Back to clients',
            onSecondary: () => context.go(Routes.clients),
          ),
        ),
      );
    }

    final areasAsync = ref.watch(_areasProvider);
    final territoriesAsync = ref.watch(_territoriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Client' : 'New Client'),
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: widget.isEditing ? 'Save changes' : 'Register client',
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
            SectionHeader(
              title: widget.isEditing
                  ? 'Client details'
                  : 'New client registration',
            ),
            AppTextField(
              label: 'Client name',
              required: true,
              controller: _name,
              validator: (v) => Validate.required(v, 'Client name'),
              onChanged: (v) => setState(() => _typedName = v),
            ),

            // The duplicate check, on the name the rep is already typing.
            //
            // It was a search box and a row of type filters above the form —
            // a second, smaller Clients screen sitting on top of a create
            // form, asking the rep to look for a record before entering the
            // one he came to enter. He types the name either way, so the name
            // field can do the looking, and nothing appears unless there is
            // actually something to say.
            //
            // The check itself is not optional: registering a doctor who is
            // already listed splits their visit history, targets and RCPA
            // across two records for good, and nothing downstream can tell
            // they are one person. Editing cannot duplicate anything, so it
            // is only ever shown while registering.
            if (!widget.isEditing) _DuplicateWarning(name: _typedName),

            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Designation',
              controller: _designation,
              hint: 'e.g. Consultant',
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownField<ClientType>(
              label: 'Client type',
              required: true,
              items: ClientType.values,
              value: _type,
              itemLabel: (t) => t.label,
              onChanged: (v) => setState(() => _type = v ?? ClientType.doctor),
            ),
            // Specialty is a doctor's attribute; a chemist does not have one.
            //
            // Chosen from master data rather than typed. Free text arrives as
            // "Cardiologist", "cardiologist" and "Cardio" — indistinguishable
            // to a rep, three separate rows in any report that groups by it.
            // The picker searches once the list passes eight entries, which
            // this one does.
            if (_type == ClientType.doctor) ...[
              const SizedBox(height: AppSpacing.lg),
              ref
                  .watch(_specialtiesProvider)
                  .when(
                    loading: () => const Skeleton(height: 68),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (specialties) => DropdownField<String>(
                      label: 'Specialty',
                      hint: 'Search or select',
                      items: specialties,
                      value: _specialty,
                      itemLabel: (s) => s,
                      onChanged: (v) => setState(() => _specialty = v),
                    ),
                  ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Two options, so both are on screen. A dropdown here hid one
            // answer behind a tap and charged a second tap to choose it.
            SegmentedField<ClientListing>(
              label: 'Category',
              required: true,
              options: ClientListing.values,
              value: _listing,
              itemLabel: (l) => l.label,
              onChanged: (v) => setState(() {
                _listing = v;
                // Coming off the list takes the status with it. Left as it
                // was, an "Inactive" answered while the client was listed
                // would sit on the record unasked and unshown, waiting for a
                // report to find it.
                if (v == ClientListing.unlisted) _isActive = true;
              }),
              helper: 'Listed clients are already on the company list.',
            ),

            // Active/Inactive is a fact about a client's place on the company
            // list — a clinic that has closed comes off it. An unlisted
            // client was never on the list, so the question has no answer and
            // is not asked.
            if (_listing == ClientListing.listed) ...[
              const SizedBox(height: AppSpacing.lg),
              SegmentedField<bool>(
                label: 'Status',
                options: const [true, false],
                value: _isActive,
                itemLabel: (active) => active ? 'Active' : 'Inactive',
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],

            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Contact'),
            AppTextField(
              label: 'Contact person',
              controller: _contact,
              required: true,
              validator: (v) => Validate.required(v, 'Contact person'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Mobile number',
              required: true,
              controller: _mobile,
              keyboardType: TextInputType.phone,
              validator: Validate.mobile,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              validator: (v) => Validate.email(v),
            ),

            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Address & territory'),
            AppTextField(
              label: 'Address',
              controller: _address,
              maxLines: 2,
              required: true,
              validator: (v) => Validate.required(v, 'Address'),
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
                  // The area below belongs to the territory above, so a
                  // stale selection is cleared rather than left mismatched.
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
            AppTextField(
              label: 'Pincode',
              controller: _pincode,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: AppSpacing.lg),
            DateField(
              label: 'Special date',
              value: _specialDate,
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _specialDate = d),
              helper: 'A date worth wishing them on.',
            ),

            // Only once there is a date. A lone occasion picker on an empty
            // field is a question about nothing, and the date is what the
            // rep came here to enter.
            if (_specialDate != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SegmentedField<SpecialOccasion>(
                label: 'Occasion',
                required: true,
                options: SpecialOccasion.values,
                value: _occasion,
                itemLabel: (o) => o.label,
                onChanged: (v) => setState(() => _occasion = v),
              ),
              if (_occasion == SpecialOccasion.other) ...[
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'What is the occasion?',
                  controller: _occasionNote,
                  hint: 'e.g. Clinic anniversary',
                  required: true,
                  validator: (v) => Validate.required(v, 'The occasion'),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Registered location'),
            _LocationCapture(
              captured: _captured,
              isCapturing: _capturing,
              error: _locationError,
              onCapture: _capture,
              // Read from the policy, not written into the copy: if the
              // geo-fence is ever widened, this sentence must not lie.
              radiusMeters: ref.watch(geoFenceRadiusProvider),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

final _areasProvider = FutureProvider.autoDispose<List<Area>>(
  (ref) => ref.watch(employeeRepositoryProvider).areas(),
);

final _territoriesProvider = FutureProvider.autoDispose<List<Territory>>(
  (ref) => ref.watch(employeeRepositoryProvider).territories(),
);

/// The specialty master list, for the doctor form.
final _specialtiesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(clientRepositoryProvider).specialties(),
);

/// Existing clients matching what has been typed, so a duplicate is caught
/// before it is created rather than merged afterwards.
final _duplicateSearchProvider = FutureProvider.autoDispose
    .family<List<Client>, String>((ref, query) async {
      if (query.trim().isEmpty) return const [];
      final session = ref.watch(sessionProvider);
      return ref.watch(clientRepositoryProvider).list(session, query: query);
    });

/// Says so when the name being typed is already on the master.
///
/// The single most damaging mistake on this screen is registering a client who
/// is already listed: their visit history, targets and RCPA then live under two
/// records, and nothing downstream can tell they are one person.
///
/// Silent until there is a match — a create form should not carry a control
/// that spends most of its life saying "no results".
class _DuplicateWarning extends ConsumerWidget {
  const _DuplicateWarning({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final probe = duplicateProbe(name);
    if (probe.isEmpty) return const SizedBox.shrink();

    final matches =
        ref.watch(_duplicateSearchProvider(probe)).valueOrNull ?? const [];
    if (matches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        color: AppColors.warningSoft,
        borderColor: Colors.transparent,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              matches.length == 1
                  ? 'Already listed. Open it instead of adding a duplicate.'
                  : '${matches.length} already listed. Open one instead of '
                        'adding a duplicate.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final client in matches.take(4))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: AppAvatar(name: client.name, size: 32),
                title: Text(client.name, style: AppTypography.titleSm),
                subtitle: Text(
                  '${client.type.label} · ${client.areaName}',
                  style: AppTypography.caption,
                ),
                trailing: const Icon(Icons.chevron_right, size: AppSizes.iconMd),
                onTap: () => context.push(Routes.clientDetail(client.id)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Active or inactive, as words rather than an unlabelled switch (§73).

class _LocationCapture extends StatelessWidget {
  const _LocationCapture({
    required this.captured,
    required this.isCapturing,
    required this.error,
    required this.onCapture,
    required this.radiusMeters,
  });

  final GeoPoint? captured;
  final bool isCapturing;
  final String? error;
  final VoidCallback onCapture;
  final double radiusMeters;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: captured != null
          ? AppColors.success.withValues(alpha: 0.4)
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                captured != null ? Icons.location_on : Icons.location_searching,
                size: 22,
                color: captured != null ? AppColors.success : AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  captured != null
                      ? 'Location captured'
                      : 'Capture the client location',
                  style: AppTypography.titleSm,
                ),
              ),
              if (captured != null)
                const StatusBadge(
                  label: 'Saved',
                  tone: StatusTone.success,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            captured != null
                ? 'Capture this at the client premises. Every future visit is '
                      'verified against this point, and counts as verified only '
                      'within ${radiusMeters.round()} m of it.'
                : 'Stand at the client premises and capture the GPS position. '
                      'Future visits count as verified only within '
                      '${radiusMeters.round()} m of it.',
            style: AppTypography.caption,
          ),
          if (captured != null) ...[
            const SizedBox(height: AppSpacing.md),
            KeyValueRow(
              label: 'Coordinates',
              value: captured.toString(),
              labelWidth: 100,
              dense: true,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              error!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: captured == null ? 'Capture location' : 'Recapture',
            icon: Icons.my_location,
            small: true,
            isLoading: isCapturing,
            onPressed: onCapture,
          ),
        ],
      ),
    );
  }
}
