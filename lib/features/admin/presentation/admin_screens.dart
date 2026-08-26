import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/mock/mock_dataset.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

/// Admin dashboard (§52). Configuration-oriented: counts of what exists and
/// direct routes into each master-data set. Deliberately not an operational
/// dashboard — an administrator manages the system, not the field.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = MockDataset.instance;

    final counts = <({String label, String value, IconData icon, String route})>[
      (
        label: 'Users',
        value: '${data.employees.length}',
        icon: Icons.people_outline,
        route: Routes.adminUsers
      ),
      (
        label: 'Clients',
        value: '${data.clients.length}',
        icon: Icons.local_hospital_outlined,
        route: Routes.adminMasterData
      ),
      (
        label: 'Products',
        value: '${data.products.length}',
        icon: Icons.medication_outlined,
        route: Routes.adminMasterData
      ),
      (
        label: 'Territories',
        value: '${data.territories.length}',
        icon: Icons.map_outlined,
        route: Routes.adminMasterData
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Administration'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.md,
          AppSpacing.screenH, AppSpacing.xxxl * 3,
        ),
        children: [
          const SectionHeader(title: 'System'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.9,
            children: [
              for (final c in counts)
                AppCard(
                  onTap: () => context.push(c.route),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(c.icon, size: 20, color: AppColors.brand),
                      const SizedBox(height: AppSpacing.sm),
                      Text(c.value, style: AppTypography.metricSm),
                      Text(c.label, style: AppTypography.caption),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Configuration'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _AdminRow(
                  icon: Icons.people_alt_outlined,
                  title: 'Users & roles',
                  subtitle: 'Accounts, hierarchy and permissions',
                  route: Routes.adminUsers,
                ),
                const Divider(height: 1, indent: AppSpacing.cardPadding),
                _AdminRow(
                  icon: Icons.storage_outlined,
                  title: 'Master data',
                  subtitle: 'Territories, products, types and lists',
                  route: Routes.adminMasterData,
                ),
                const Divider(height: 1, indent: AppSpacing.cardPadding),
                _AdminRow(
                  icon: Icons.my_location_outlined,
                  title: 'Geo-fence',
                  subtitle: 'Visit verification radius and policy',
                  route: Routes.adminGeoFence,
                ),
                const Divider(height: 1, indent: AppSpacing.cardPadding),
                _AdminRow(
                  icon: Icons.rule_outlined,
                  title: 'Approval rules',
                  subtitle: 'Who approves what, and at which threshold',
                  route: Routes.adminApprovalRules,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(icon: icon),
      title: Text(title, style: AppTypography.titleMd),
      subtitle: Text(subtitle, style: AppTypography.caption),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () => context.push(route),
    );
  }
}

// ================================================================== users ==

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  UserRole? _roleFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = MockDataset.instance.employees;
    final q = _search.text.trim().toLowerCase();

    final users = all.where((e) {
      if (_roleFilter != null && e.role != _roleFilter) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.employeeCode.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Users'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User creation is enabled with the backend.')),
        ),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add user'),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md,
            ),
            child: SearchField(
              hint: 'Search by name or employee ID',
              controller: _search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilterChipBar<UserRole?>(
            options: [null, ...UserRole.values],
            selected: _roleFilter,
            labelOf: (r) => r?.shortLabel ?? 'All',
            countOf: (r) =>
                r == null ? null : all.where((e) => e.role == r).length,
            onSelected: (r) => setState(() => _roleFilter = r),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: users.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No users match',
                    message: 'Try a different name, ID or role.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0,
                      AppSpacing.screenH, AppSpacing.xxxl * 3,
                    ),
                    itemCount: users.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.cardGap),
                    itemBuilder: (context, i) => _UserCard(employee: users[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
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
                  '${employee.employeeCode} · ${employee.territoryName}',
                  style: AppTypography.caption,
                ),
                if (employee.managerName != null) ...[
                  const SizedBox(height: 2),
                  Text('Reports to ${employee.managerName}',
                      style: AppTypography.caption),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(
                label: employee.role.shortLabel,
                tone: StatusTone.brand,
                dense: true,
              ),
              const SizedBox(height: AppSpacing.xs),
              StatusBadge(
                label: employee.isActive ? 'Active' : 'Inactive',
                tone: employee.isActive
                    ? StatusTone.success
                    : StatusTone.neutral,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================ master data ==

/// Master data (§52). One screen with expandable sets rather than fifteen
/// near-identical list screens — the shape of the data is the same in each
/// case, and an admin is usually checking, not editing.
class AdminMasterDataScreen extends ConsumerWidget {
  const AdminMasterDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = MockDataset.instance;

    final sets = <({String title, IconData icon, List<String> items})>[
      (
        title: 'Territories',
        icon: Icons.public,
        items: data.territories.map((t) => '${t.name} · ${t.headquarters}').toList()
      ),
      (
        title: 'Areas',
        icon: Icons.location_city_outlined,
        items: data.areas.map((a) => a.name).toList()
      ),
      (
        title: 'Clusters',
        icon: Icons.hub_outlined,
        items: data.clusters.map((c) => c.name).toList()
      ),
      (
        title: 'Products',
        icon: Icons.medication_outlined,
        items: data.products
            .map((p) => '${p.name} · ${p.code} · GST ${p.gstPercent.round()}%')
            .toList()
      ),
      (
        title: 'Specialties',
        icon: Icons.medical_services_outlined,
        items: const [
          'Cardiologist', 'Physician', 'Gynecologist', 'Neurologist',
          'Pediatrician', 'Orthopedic', 'Diabetologist', 'Pulmonologist',
        ]
      ),
      (
        title: 'Work types',
        icon: Icons.work_outline,
        items: WorkType.values.map((w) => w.label).toList()
      ),
      (
        title: 'Tour types',
        icon: Icons.route_outlined,
        items: TourType.values.map((t) => t.label).toList()
      ),
      (
        title: 'Expense types',
        icon: Icons.receipt_long_outlined,
        items: ExpenseCategory.values.map((e) => e.label).toList()
      ),
      (
        title: 'Leave types',
        icon: Icons.event_busy_outlined,
        items: LeaveType.values.map((l) => l.label).toList()
      ),
      (
        title: 'Holidays',
        icon: Icons.celebration_outlined,
        items: data.holidays
            .map((h) => '${h.name} · ${h.date.day}/${h.date.month}')
            .toList()
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Master Data'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.screenH,
          AppSpacing.screenH, AppSpacing.xxxl * 3,
        ),
        children: [
          for (final set in sets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: IconTile(icon: set.icon),
                    title: Text(set.title, style: AppTypography.titleMd),
                    subtitle: Text('${set.items.length} entries',
                        style: AppTypography.caption),
                    childrenPadding: const EdgeInsets.only(
                      left: AppSpacing.cardPadding,
                      right: AppSpacing.cardPadding,
                      bottom: AppSpacing.md,
                    ),
                    children: [
                      for (final item in set.items)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              const StatusDot(
                                  color: AppColors.border, size: 5),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child:
                                    Text(item, style: AppTypography.bodySm),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        label: 'Add ${set.title.toLowerCase()}',
                        icon: Icons.add,
                        small: true,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Master-data editing is enabled with the backend.'),
                          ),
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

// ============================================================== geo-fence ==

/// Geo-fence configuration (§130).
///
/// The policy choice here is the single most consequential setting in the
/// product, so each option states its operational consequence rather than just
/// its name. Strict enforcement is offered but not the default — see the
/// reasoning in [GeoFencePolicy].
class AdminGeoFenceScreen extends ConsumerWidget {
  const AdminGeoFenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = ref.watch(geoFenceRadiusProvider);
    final policy = ref.watch(geoFencePolicyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Geo-fence')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          const SectionHeader(title: 'Verification radius'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${radius.round()}', style: AppTypography.metric),
                    const SizedBox(width: AppSpacing.xs),
                    Text('metres', style: AppTypography.bodySm),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'A visit is verified when the rep is within this distance of '
                  "the client's registered location.",
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.md),
                Slider(
                  value: radius,
                  min: 20,
                  max: 200,
                  divisions: 18,
                  label: '${radius.round()} m',
                  onChanged: (v) =>
                      ref.read(geoFenceRadiusProvider.notifier).state = v,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('20 m', style: AppTypography.caption),
                    Text('200 m', style: AppTypography.caption),
                  ],
                ),
                if (radius < 40) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Warning(
                    text: 'Below about 40 m, ordinary GPS drift inside '
                        'buildings will start failing honest visits.',
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Enforcement policy'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PolicyOption(
                  value: GeoFencePolicy.warn,
                  groupValue: policy,
                  title: 'Warn and record',
                  subtitle: 'Out-of-range visits are allowed but require a '
                      'written reason and are permanently flagged as '
                      'unverified. Recommended.',
                  onChanged: (v) =>
                      ref.read(geoFencePolicyProvider.notifier).state = v,
                ),
                const Divider(height: 1),
                _PolicyOption(
                  value: GeoFencePolicy.strict,
                  groupValue: policy,
                  title: 'Block',
                  subtitle: 'Visits cannot be started outside the radius. '
                      'A rep who genuinely met the doctor elsewhere will be '
                      'unable to record the call at all.',
                  onChanged: (v) =>
                      ref.read(geoFencePolicyProvider.notifier).state = v,
                ),
                const Divider(height: 1),
                _PolicyOption(
                  value: GeoFencePolicy.off,
                  groupValue: policy,
                  title: 'Record only',
                  subtitle: 'Distance is captured for reporting but never '
                      'gates a visit.',
                  onChanged: (v) =>
                      ref.read(geoFencePolicyProvider.notifier).state = v,
                ),
              ],
            ),
          ),

          if (policy == GeoFencePolicy.strict) ...[
            const SizedBox(height: AppSpacing.md),
            _Warning(
              text: 'Blocking pushes legitimate work out of the system. '
                  'Teams under a strict policy often stop logging visits they '
                  'actually made, which makes coverage reporting worse rather '
                  'than better.',
            ),
          ],

          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Integrity'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: true,
                  onChanged: (_) {},
                  title: Text('Detect mock locations',
                      style: AppTypography.titleMd),
                  subtitle: Text(
                    'Flag visits captured while a location-spoofing app is '
                    'active.',
                    style: AppTypography.caption,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: true,
                  onChanged: (_) {},
                  title: Text('Store location history',
                      style: AppTypography.titleMd),
                  subtitle: Text(
                    'Retain captured coordinates against each visit for audit.',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _PolicyOption extends StatelessWidget {
  const _PolicyOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final GeoFencePolicy value;
  final GeoFencePolicy groupValue;
  final String title;
  final String subtitle;
  final ValueChanged<GeoFencePolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.brand : AppColors.border,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMd),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: AppSizes.iconMd, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style:
                    AppTypography.caption.copyWith(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

// ========================================================= approval rules ==

class AdminApprovalRulesScreen extends ConsumerWidget {
  const AdminApprovalRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = <({ApprovalKind kind, String approver, String threshold})>[
      (
        kind: ApprovalKind.expense,
        approver: 'Reporting manager',
        threshold: 'All claims'
      ),
      (
        kind: ApprovalKind.leave,
        approver: 'Reporting manager',
        threshold: 'All requests'
      ),
      (
        kind: ApprovalKind.tourPlan,
        approver: 'Reporting manager',
        threshold: 'All plans'
      ),
      (
        kind: ApprovalKind.order,
        approver: 'ASM, then RSM above ₹1,00,000',
        threshold: 'Two-step above threshold'
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Approval Rules')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          AppCard(
            color: AppColors.infoSoft,
            borderColor: Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: AppSizes.iconMd, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Rules determine who sees each request in their approval '
                    'queue. Rejections always require a reason, regardless of '
                    'the rule.',
                    style:
                        AppTypography.bodySm.copyWith(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Current rules'),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: AppCard(
                child: Row(
                  children: [
                    IconTile(icon: rule.kind.icon),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rule.kind.label, style: AppTypography.titleMd),
                          const SizedBox(height: 2),
                          Text('Approved by ${rule.approver}',
                              style: AppTypography.caption),
                          Text(rule.threshold, style: AppTypography.caption),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      color: AppColors.brand,
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Rule editing is enabled with the backend.'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
