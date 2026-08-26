import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/location/geo_math.dart';
import '../../../core/location/location_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/models/client.dart';
import '../../../shared/models/organization.dart';
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
final _clientFilterProvider =
    StateProvider.autoDispose<ClientFilter>((ref) => ClientFilter.all);

final _clientListProvider =
    FutureProvider.autoDispose<List<Client>>((ref) async {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(clientRepositoryProvider).list(
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newClient),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New client'),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md,
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
            onSelected: (f) => ref.read(_clientFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: listAsync.when(
              loading: () => const SkeletonList(),
              error: (_, _) =>
                  ErrorState(onRetry: () => ref.invalidate(_clientListProvider)),
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
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xxxl * 3,
                  ),
                  itemCount: clients.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) => _ClientCard(client: clients[i]),
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
          AppAvatar(name: client.name),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.name,
                    style: AppTypography.titleMd,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(client.subtitle,
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(client.areaName,
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis),
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

final _clientProvider =
    FutureProvider.autoDispose.family<Client, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(clientRepositoryProvider).byId(id);
});

final _clientHistoryProvider =
    FutureProvider.autoDispose.family<List<Activity>, String>((ref, id) {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Client Detail')),
      bottomNavigationBar: clientAsync.maybeWhen(
        data: (client) => BottomActionBar(
          children: [
            SecondaryButton(
              label: 'Add activity',
              icon: Icons.event_available_outlined,
              onPressed: () => context.push(
                '${Routes.addActivity}?clientId=${client.id}',
              ),
            ),
            PrimaryButton(
              label: 'Navigate',
              icon: Icons.directions_outlined,
              onPressed: () {},
            ),
          ],
        ),
        orElse: () => null,
      ),
      body: clientAsync.when(
        loading: () => const LoadingState(),
        error: (_, _) =>
            ErrorState(onRetry: () => ref.invalidate(_clientProvider(clientId))),
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
                      AppAvatar(name: client.name, size: AppSizes.avatarLg),
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
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge(
                        label: client.isActive ? 'Active' : 'Inactive',
                        tone: client.isActive
                            ? StatusTone.success
                            : StatusTone.neutral,
                        dense: true,
                      ),
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

            const SectionHeader(title: 'Contact'),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(label: 'Designation', value: client.designation),
                  KeyValueRow(label: 'Contact person', value: client.contactPerson),
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
                      message: 'Completed visits to this client will appear here.',
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final a in history.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
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
      backgroundColor: AppColors.background,
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
                itemBuilder: (context, i) =>
                    ActivityCard(activity: history[i], showDate: true),
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
class NewClientScreen extends ConsumerStatefulWidget {
  const NewClientScreen({super.key});

  @override
  ConsumerState<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends ConsumerState<NewClientScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _designation = TextEditingController();
  final _specialty = TextEditingController();
  final _contact = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _pincode = TextEditingController();

  ClientType _type = ClientType.doctor;
  ClientCategory _category = ClientCategory.regular;
  Area? _area;

  GeoPoint? _captured;
  bool _capturing = false;
  String? _locationError;

  bool _submitting = false;
  Client? _created;

  @override
  void dispose() {
    for (final c in [
      _name, _designation, _specialty, _contact,
      _mobile, _email, _address, _pincode,
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

    final client = Client(
      id: const Uuid().v4(),
      name: _name.text.trim(),
      type: _type,
      category: _category,
      areaId: _area!.id,
      areaName: _area!.name,
      territoryId: _area!.territoryId,
      specialty: _specialty.text.trim().isEmpty ? null : _specialty.text.trim(),
      designation:
          _designation.text.trim().isEmpty ? null : _designation.text.trim(),
      contactPerson: _contact.text.trim(),
      mobile: _mobile.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      addressLine: _address.text.trim(),
      pincode: _pincode.text.trim().isEmpty ? null : _pincode.text.trim(),
      latitude: _captured?.latitude,
      longitude: _captured?.longitude,
      ownerEmployeeId: session.employee.id,
      createdAt: DateTime.now(),
      syncStatus: ref.read(isOnlineProvider)
          ? SyncStatus.synced
          : SyncStatus.savedLocally,
    );

    await ref.read(clientRepositoryProvider).create(client);
    if (!mounted) return;

    ref.bumpRevision();
    setState(() {
      _submitting = false;
      _created = client;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_created != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Client')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: 'Register client',
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
            const SectionHeader(title: 'Identity'),
            AppTextField(
              label: 'Client name',
              required: true,
              controller: _name,
              validator: (v) => Validate.required(v, 'Client name'),
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
            const SizedBox(height: AppSpacing.lg),
            if (_type == ClientType.doctor) ...[
              AppTextField(
                label: 'Specialty',
                controller: _specialty,
                hint: 'e.g. Cardiologist',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Designation',
                controller: _designation,
                hint: 'e.g. Consultant',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            DropdownField<ClientCategory>(
              label: 'Category',
              required: true,
              items: ClientCategory.values,
              value: _category,
              itemLabel: (c) => c.label,
              onChanged: (v) =>
                  setState(() => _category = v ?? ClientCategory.regular),
              helper: 'Determines planning priority.',
            ),

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
            AppTextField(
              label: 'Pincode',
              controller: _pincode,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),

            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Registered location'),
            _LocationCapture(
              captured: _captured,
              isCapturing: _capturing,
              error: _locationError,
              onCapture: _capture,
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

class _LocationCapture extends StatelessWidget {
  const _LocationCapture({
    required this.captured,
    required this.isCapturing,
    required this.error,
    required this.onCapture,
  });

  final GeoPoint? captured;
  final bool isCapturing;
  final String? error;
  final VoidCallback onCapture;

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
                captured != null
                    ? Icons.location_on
                    : Icons.location_searching,
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
                ? 'Every future visit to this client is verified against this '
                    'point. Stand at the entrance before capturing.'
                : 'Stand at the client premises and capture the GPS position. '
                    'This becomes the reference for visit verification.',
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
            Text(error!,
                style: AppTypography.caption.copyWith(color: AppColors.error)),
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
