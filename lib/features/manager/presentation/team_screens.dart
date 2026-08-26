import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/location/geo_math.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/client.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/mock_map.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import '../../activity/presentation/widgets/activity_card.dart';

/// Today's activity for one team member, used to compute per-person progress.
final _memberDayProvider =
    FutureProvider.autoDispose.family<DaySummary, String>((ref, employeeId) {
  ref.watch(dataRevisionProvider);
  return ref
      .watch(activityRepositoryProvider)
      .daySummary(employeeId, DateTime.now());
});

// ============================================================== team list ==

class MyTeamScreen extends ConsumerWidget {
  const MyTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Team'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Team map',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(Routes.teamMap),
          ),
          IconButton(
            tooltip: 'Team activity',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.push(Routes.teamActivity),
          ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => ErrorState(onRetry: () => ref.invalidate(teamProvider)),
        data: (team) => team.isEmpty
            ? const EmptyState(
                icon: Icons.groups_outlined,
                title: 'No team members',
                message: 'Employees reporting to you will appear here.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(teamProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.screenH,
                    AppSpacing.screenH, AppSpacing.xxxl * 3,
                  ),
                  itemCount: team.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) =>
                      _TeamMemberCard(employee: team[i]),
                ),
              ),
      ),
    );
  }
}

class _TeamMemberCard extends ConsumerWidget {
  const _TeamMemberCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayAsync = ref.watch(_memberDayProvider(employee.id));

    return AppCard(
      onTap: () => context.push(Routes.employeeDetail(employee.id)),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(
                name: employee.name,
                showOnlineDot: true,
                isOnline: dayAsync.valueOrNull?.completed != null &&
                    (dayAsync.valueOrNull?.completed ?? 0) > 0,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.name, style: AppTypography.titleMd),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.employeeCode} · ${employee.areaName ?? employee.territoryName}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: employee.role.shortLabel,
                tone: StatusTone.neutral,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          dayAsync.when(
            loading: () => const Skeleton(height: 24),
            error: (_, _) => const SizedBox.shrink(),
            data: (day) {
              final behind = day.planned > 0 && day.completed < day.planned;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          day.planned == 0
                              ? 'No visits planned today'
                              : '${day.completed} of ${day.planned} visits today',
                          style: AppTypography.caption,
                        ),
                      ),
                      Text(
                        '${day.progressPercent}%',
                        style: AppTypography.titleSm.copyWith(
                          color: behind ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppProgressBar(
                    value: day.progress,
                    height: 5,
                    color: behind ? AppColors.warning : AppColors.success,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ========================================================= employee detail ==

final _employeeProvider =
    FutureProvider.autoDispose.family<Employee, String>((ref, id) {
  return ref.watch(employeeRepositoryProvider).byId(id);
});

final _employeeTargetProvider =
    FutureProvider.autoDispose.family<List<Target>, String>((ref, id) {
  final session = ref.watch(sessionProvider);
  return ref.watch(businessRepositoryProvider).targets(
        session,
        employeeId: id,
        month: DateTime.now(),
      );
});

class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeAsync = ref.watch(_employeeProvider(employeeId));
    final dayAsync = ref.watch(_memberDayProvider(employeeId));
    final targetAsync = ref.watch(_employeeTargetProvider(employeeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Employee')),
      body: employeeAsync.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (employee) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      AppAvatar(name: employee.name, size: AppSizes.avatarLg),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(employee.name, style: AppTypography.h3),
                            const SizedBox(height: 2),
                            Text(employee.subtitle,
                                style: AppTypography.bodySm),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.phone_outlined,
                          label: 'Call',
                          onTap: () {},
                        ),
                      ),
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.chat_bubble_outline,
                          label: 'Message',
                          onTap: () => context.push(Routes.chat),
                        ),
                      ),
                      Expanded(
                        child: _ContactAction(
                          icon: Icons.assignment_outlined,
                          label: 'Assign task',
                          onTap: () => context.push(Routes.taskAssignment),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            const SectionHeader(title: 'Today'),
            dayAsync.when(
              loading: () => const Skeleton(height: 80, radius: AppRadius.lg),
              error: (_, _) => const SizedBox.shrink(),
              data: (day) => AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                              label: 'Planned', value: '${day.planned}'),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Completed',
                            value: '${day.completed}',
                            color: AppColors.success,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Remaining',
                            value: '${day.remaining}',
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppProgressBar(value: day.progress),
                    const SizedBox(height: AppSpacing.sm),
                    Text(day.paceLabel(), style: AppTypography.caption),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            const SectionHeader(title: 'This month'),
            targetAsync.when(
              loading: () => const Skeleton(height: 80, radius: AppRadius.lg),
              error: (_, _) => const SizedBox.shrink(),
              data: (targets) {
                if (targets.isEmpty) {
                  return const AppCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.flag_outlined,
                      title: 'No target assigned',
                      message: 'Assign a monthly target to track performance.',
                    ),
                  );
                }
                final t = targets.first;
                return AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Sales target',
                                style: AppTypography.titleSm),
                          ),
                          StatusBadge(
                            label: '${t.achievementPercent.round()}%',
                            tone: t.tone,
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppProgressBar(
                        value: t.achievementPercent / 100,
                        color: t.tone.foreground,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Text(Fmt.money(t.achievedAmount),
                              style: AppTypography.caption),
                          Text(' of ${Fmt.money(t.targetAmount)}',
                              style: AppTypography.caption),
                          const Spacer(),
                          Text('${t.visitsAchieved}/${t.visitTarget} visits',
                              style: AppTypography.caption),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.cardGap),

            const SectionHeader(title: 'Profile'),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(
                      label: 'Employee ID', value: employee.employeeCode),
                  KeyValueRow(label: 'Role', value: employee.role.label),
                  KeyValueRow(label: 'Territory', value: employee.territoryName),
                  KeyValueRow(label: 'Area', value: employee.areaName),
                  KeyValueRow(label: 'HQ', value: employee.headquarters),
                  KeyValueRow(label: 'Mobile', value: employee.mobile),
                  KeyValueRow(label: 'Email', value: employee.email),
                  KeyValueRow(
                    label: 'Joined',
                    value: employee.joiningDate == null
                        ? null
                        : Fmt.date(employee.joiningDate!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            SectionHeader(
              title: "Today's visits",
              actionLabel: 'All activity',
              onAction: () => context.push(Routes.teamActivity),
            ),
            dayAsync.maybeWhen(
              data: (day) => day.activities.isEmpty
                  ? const AppCard(
                      child: EmptyState(
                        compact: true,
                        icon: Icons.event_busy_outlined,
                        title: 'No visits today',
                      ),
                    )
                  : Column(
                      children: [
                        for (final a in day.activities.take(5))
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.cardGap),
                            child: ActivityCard(activity: a),
                          ),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.brand),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: AppTypography.metricSm.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      );
}

// =========================================================== team activity ==

final _teamActivityProvider =
    FutureProvider.autoDispose<List<Activity>>((ref) async {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(activityRepositoryProvider)
      .list(session, date: DateTime.now());
});

class TeamActivityScreen extends ConsumerStatefulWidget {
  const TeamActivityScreen({super.key});

  @override
  ConsumerState<TeamActivityScreen> createState() => _TeamActivityScreenState();
}

class _TeamActivityScreenState extends ConsumerState<TeamActivityScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_teamActivityProvider);
    const filters = ['All', 'Completed', 'Pending', 'Unverified'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Team Activity')),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          FilterChipBar<String>(
            options: filters,
            selected: _filter,
            labelOf: (f) => f,
            onSelected: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) => const ErrorState(),
              data: (all) {
                final items = all.where((a) => switch (_filter) {
                      'Completed' => a.status == ActivityStatus.completed,
                      'Pending' => a.status.isOpen,
                      'Unverified' =>
                        a.status == ActivityStatus.completed && !a.isVerified,
                      _ => true,
                    }).toList();

                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'Nothing here',
                    message: _filter == 'Unverified'
                        ? 'Every completed visit today passed location '
                            'verification.'
                        : 'No $_filter activity recorded today.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xxxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) =>
                      ActivityCard(activity: items[i], showEmployee: true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================ team map ==

/// Team map (§42).
///
/// A real map needs a Google Maps key and billing, which is a Phase 6 concern.
/// Rather than ship a fake map image, this presents the same operational data
/// the map exists to deliver — who is where, doing what, and when they were
/// last seen — as a list, and states plainly that the map view is pending.
/// Clients in scope, drawn as context beneath the team markers so a manager can
/// see coverage — who is standing where relative to the accounts they own.
final _mapClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  final session = ref.watch(sessionProvider);
  return ref.watch(clientRepositoryProvider).list(session);
});

class TeamMapScreen extends ConsumerStatefulWidget {
  const TeamMapScreen({super.key});

  @override
  ConsumerState<TeamMapScreen> createState() => _TeamMapScreenState();
}

class _TeamMapScreenState extends ConsumerState<TeamMapScreen> {
  String? _selectedId;
  bool _showClients = true;

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamProvider);
    final clientsAsync = ref.watch(_mapClientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Team Map'),
        actions: [
          IconButton(
            tooltip: _showClients ? 'Hide clients' : 'Show clients',
            icon: Icon(
              _showClients ? Icons.location_on : Icons.location_off_outlined,
            ),
            onPressed: () => setState(() => _showClients = !_showClients),
          ),
        ],
      ),
      body: teamAsync.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (team) {
          final located =
              team.where((e) => e.lastKnownLatitude != null).toList();

          final markers = <MapMarker>[
            if (_showClients)
              for (final client in clientsAsync.valueOrNull ?? const <Client>[])
                if (client.location != null)
                  MapMarker(
                    id: 'client-${client.id}',
                    point: client.location!,
                    label: client.name,
                    kind: MapMarkerKind.client,
                  ),
            for (final member in located)
              MapMarker(
                id: member.id,
                point: GeoPoint(
                  member.lastKnownLatitude!,
                  member.lastKnownLongitude!,
                ),
                label: member.name,
                sublabel: member.areaName,
                kind: MapMarkerKind.person,
                color: _statusColour(ref, member.id),
                isActive: _isOnVisit(ref, member.id),
              ),
          ];

          final selected = _selectedId == null
              ? null
              : team.where((e) => e.id == _selectedId).firstOrNull;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              if (markers.isEmpty)
                const AppCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.location_off_outlined,
                    title: 'No positions reported',
                    message: 'Positions appear once your team records visits '
                        'with location enabled.',
                  ),
                )
              else
                MockMapCanvas(
                  markers: markers,
                  selectedId: _selectedId,
                  height: 340,
                  onSelect: (marker) => setState(
                    () => _selectedId =
                        _selectedId == marker.id ? null : marker.id,
                  ),
                ),

              const SizedBox(height: AppSpacing.md),
              const _MapLegend(),

              if (selected != null) ...[
                const SizedBox(height: AppSpacing.md),
                _SelectedMemberCard(
                  employee: selected,
                  onClose: () => setState(() => _selectedId = null),
                ),
              ],

              const SizedBox(height: AppSpacing.section),
              SectionHeader(
                title: 'Last known positions',
                trailing: Text(
                  '${located.length} of ${team.length} reporting',
                  style: AppTypography.caption,
                ),
              ),
              for (final member in team)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                  child: _MapMemberCard(
                    employee: member,
                    isSelected: member.id == _selectedId,
                    onTap: () => setState(
                      () => _selectedId =
                          _selectedId == member.id ? null : member.id,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          );
        },
      ),
    );
  }

  /// Marker colour carries pace, not identity: a manager scanning the map is
  /// looking for who is falling behind, not who is who.
  Color? _statusColour(WidgetRef ref, String employeeId) {
    final day = ref.watch(_memberDayProvider(employeeId)).valueOrNull;
    if (day == null || day.planned == 0) return AppColors.textSecondary;

    final hour = DateTime.now().hour + DateTime.now().minute / 60;
    final elapsed = ((hour - 9) / 9).clamp(0.0, 1.0);
    final expected = day.planned * elapsed;

    if (day.completed >= expected) return AppColors.success;
    if (day.completed >= expected - 1) return AppColors.brand;
    return AppColors.warning;
  }

  bool _isOnVisit(WidgetRef ref, String employeeId) {
    final day = ref.watch(_memberDayProvider(employeeId)).valueOrNull;
    return day?.inProgress != null;
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.md,
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: const [
          _LegendEntry(color: AppColors.success, label: 'On plan'),
          _LegendEntry(color: AppColors.brand, label: 'Near plan'),
          _LegendEntry(color: AppColors.warning, label: 'Behind plan'),
          _LegendEntry(color: AppColors.sand, label: 'Client', isDot: true),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    this.isDot = false,
  });

  final Color color;
  final String label;
  final bool isDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isDot ? 9 : 14,
          height: isDot ? 9 : 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 1.5),
          ),
          child: isDot
              ? null
              : const Icon(Icons.person, size: 8, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

/// Detail for the pin a manager just tapped — the operational answer to
/// "what is this person doing right now".
class _SelectedMemberCard extends ConsumerWidget {
  const _SelectedMemberCard({required this.employee, required this.onClose});

  final Employee employee;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(_memberDayProvider(employee.id)).valueOrNull;
    final current = day?.inProgress ?? day?.nextAction;

    return AppCard(
      accentColor: AppColors.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: employee.name),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.name, style: AppTypography.titleMd),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.employeeCode} · '
                      '${employee.areaName ?? employee.territoryName}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: AppSizes.iconMd),
                color: AppColors.textSecondary,
                onPressed: onClose,
              ),
            ],
          ),
          const AppDivider(),
          KeyValueRow(
            label: 'Status',
            valueWidget: day == null
                ? const Skeleton(width: 90, height: 12)
                : StatusBadge(
                    label: day.inProgress != null
                        ? 'On a visit'
                        : day.planned == 0
                            ? 'No plan today'
                            : '${day.completed}/${day.planned} visits done',
                    tone: day.inProgress != null
                        ? StatusTone.success
                        : StatusTone.neutral,
                    dense: true,
                  ),
          ),
          if (current != null)
            KeyValueRow(
              label: day?.inProgress != null ? 'At' : 'Next',
              value: '${current.clientName} · '
                  '${Fmt.time(current.scheduledStart)}',
            ),
          KeyValueRow(
            label: 'Position',
            value: employee.lastKnownLatitude == null
                ? 'Not reported'
                : '${employee.lastKnownLatitude!.toStringAsFixed(4)}, '
                    '${employee.lastKnownLongitude!.toStringAsFixed(4)}',
          ),
          KeyValueRow(
            label: 'Last seen',
            value: employee.lastSeenAt == null
                ? null
                : Fmt.timeAgo(employee.lastSeenAt!),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Call',
                  icon: Icons.phone_outlined,
                  small: true,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: 'View profile',
                  small: true,
                  onPressed: () =>
                      context.push(Routes.employeeDetail(employee.id)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapMemberCard extends ConsumerWidget {
  const _MapMemberCard({
    required this.employee,
    this.isSelected = false,
    this.onTap,
  });

  final Employee employee;
  final bool isSelected;

  /// Tapping the row selects the corresponding pin rather than navigating —
  /// the list and the map are two views of one selection.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayAsync = ref.watch(_memberDayProvider(employee.id));
    final hasPosition = employee.lastKnownLatitude != null;

    return AppCard(
      onTap: onTap ?? () => context.push(Routes.employeeDetail(employee.id)),
      borderColor: isSelected ? AppColors.brand : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: hasPosition ? Icons.location_on : Icons.location_off,
            background:
                hasPosition ? AppColors.successSoft : AppColors.surfaceSecondary,
            color: hasPosition ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name, style: AppTypography.titleMd),
                const SizedBox(height: 2),
                Text(
                  hasPosition
                      ? '${employee.lastKnownLatitude!.toStringAsFixed(4)}, '
                          '${employee.lastKnownLongitude!.toStringAsFixed(4)}'
                      : 'No position reported',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.xs),
                dayAsync.maybeWhen(
                  data: (day) {
                    final current = day.inProgress ?? day.nextAction;
                    return Text(
                      current == null
                          ? 'No active visit'
                          : '${day.inProgress != null ? 'At' : 'Next'}: '
                              '${current.clientName}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textPrimary),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (employee.lastSeenAt != null)
            Text(Fmt.timeAgo(employee.lastSeenAt!),
                style: AppTypography.caption),
        ],
      ),
    );
  }
}

// ======================================================== team performance ==

class TeamPerformanceScreen extends ConsumerWidget {
  const TeamPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final async = ref.watch(_teamTargetsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Team Performance')),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (targets) {
          if (targets.isEmpty) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No targets assigned',
              message: 'Assign monthly targets to compare performance.',
            );
          }

          final ranked = [...targets]
            ..sort((a, b) =>
                b.achievementPercent.compareTo(a.achievementPercent));

          final totalTarget =
              ranked.fold<double>(0, (s, t) => s + t.targetAmount);
          final totalAchieved =
              ranked.fold<double>(0, (s, t) => s + t.achievedAmount);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Text('${session.employee.territoryName} · '
                        '${Fmt.monthYear(DateTime.now())}',
                        style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Team achievement',
                            value:
                                '${Fmt.achievement(totalAchieved, totalTarget).round()}%',
                            color: AppColors.brand,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Achieved',
                            value: Fmt.moneyCompact(totalAchieved),
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Target',
                            value: Fmt.moneyCompact(totalTarget),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Ranking'),
              for (var i = 0; i < ranked.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                  child: AppCard(
                    onTap: () =>
                        context.push(Routes.employeeDetail(ranked[i].employeeId)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? AppColors.sandSoft
                                    : AppColors.surfaceSecondary,
                                shape: BoxShape.circle,
                              ),
                              child: Text('${i + 1}',
                                  style: AppTypography.badge.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textPrimary)),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(ranked[i].employeeName,
                                  style: AppTypography.titleMd),
                            ),
                            StatusBadge(
                              label:
                                  '${ranked[i].achievementPercent.round()}%',
                              tone: ranked[i].tone,
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppProgressBar(
                          value: ranked[i].achievementPercent / 100,
                          color: ranked[i].tone.foreground,
                          height: 5,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${Fmt.moneyCompact(ranked[i].achievedAmount)}'
                                ' of ${Fmt.moneyCompact(ranked[i].targetAmount)}',
                                style: AppTypography.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                                '${ranked[i].visitsAchieved} / '
                                '${ranked[i].visitTarget} visits',
                                style: AppTypography.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          );
        },
      ),
    );
  }
}

final _teamTargetsProvider = FutureProvider.autoDispose<List<Target>>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(businessRepositoryProvider)
      .targets(session, month: DateTime.now());
});
