import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/navigate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/engagement.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

/// More (§55). Grouped, not a flat list of twenty items — grouping is what
/// makes twenty destinations navigable.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final employee = session.employee;

    final groups = <(String, List<(IconData, String, String)>)>[
      (
        'Field operations',
        [
          (Icons.map_outlined, 'Tour Plan', Routes.travelPlans),
          (Icons.receipt_long_outlined, 'Expenses', Routes.expenses),
          (Icons.people_outline, 'Clients', Routes.clients),
          (Icons.assignment_outlined, 'To-Do', Routes.tasks),
          (Icons.ios_share_outlined, 'Export Data', Routes.exportData),
        ],
      ),
      (
        'Workplace',
        [
          (Icons.badge_outlined, 'HR', Routes.hr),
          (Icons.chat_bubble_outline, 'Chat', Routes.chat),
          (Icons.library_books_outlined, 'Resources', Routes.resources),
        ],
      ),
      (
        'Feedback',
        [
          (Icons.fact_check_outlined, 'Surveys', Routes.surveys),
          (Icons.report_problem_outlined, 'Complaints', Routes.complaints),
        ],
      ),
      if (session.isManager)
        (
          'Management',
          [
            (Icons.checklist_outlined, 'Approvals', Routes.approvals),
            (Icons.groups_outlined, 'My team', Routes.team),
            (Icons.flag_outlined, 'Assign targets', Routes.targetAssignment),
            (Icons.payments_outlined, 'Travel rates', Routes.rateAssignment),
          ],
        ),
      (
        'Account',
        [
          (Icons.person_outline, 'My profile', Routes.profile),
          (Icons.notifications_none, 'Notifications', Routes.notifications),
          (Icons.settings_outlined, 'Settings', Routes.settings),
          (Icons.help_outline, 'Help & support', Routes.help),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.xxxl * 3,
        ),
        children: [
          AppCard(
            onTap: () => context.push(Routes.profile),
            child: Row(
              children: [
                AppAvatar(name: employee.name, size: AppSizes.avatarLg),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.name, style: AppTypography.h3),
                      const SizedBox(height: 2),
                      Text(
                        '${employee.employeeCode} · ${employee.designation}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
          for (final (title, items) in groups) ...[
            const SizedBox(height: AppSpacing.section),
            SectionHeader(title: title),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: AppSpacing.cardPadding),
                    ListTile(
                      leading: Icon(
                        items[i].$1,
                        size: AppSizes.iconLg,
                        color: AppColors.brand,
                      ),
                      title: Text(items[i].$2, style: AppTypography.titleMd),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () => navigateTo(context, items[i].$3),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          DangerButton(
            label: 'Sign out',
            icon: Icons.logout,
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Sign out?',
                message:
                    'Any work saved on this device stays safe and will '
                    'sync the next time you sign in.',
                confirmLabel: 'Sign out',
                isDestructive: true,
              );
              if (confirmed) {
                await ref.read(authControllerProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ================================================================ profile ==

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(currentEmployeeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.editProfile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          AppCard(
            child: Column(
              children: [
                AppAvatar(name: employee.name, size: 76),
                const SizedBox(height: AppSpacing.md),
                Text(employee.name, style: AppTypography.h2),
                const SizedBox(height: AppSpacing.xxs),
                Text(employee.designation, style: AppTypography.bodySm),
                const SizedBox(height: AppSpacing.md),
                StatusBadge(
                  label: employee.employeeCode,
                  tone: StatusTone.brand,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          const SectionHeader(title: 'Employment'),
          AppCard(
            child: Column(
              children: [
                KeyValueRow(label: 'Employee ID', value: employee.employeeCode),
                KeyValueRow(label: 'Role', value: employee.role.label),
                KeyValueRow(label: 'Designation', value: employee.designation),
                KeyValueRow(label: 'Department', value: employee.department),
                KeyValueRow(label: 'Reports to', value: employee.managerName),
                KeyValueRow(
                  label: 'Joining date',
                  value: employee.joiningDate == null
                      ? null
                      : Fmt.date(employee.joiningDate!),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          const SectionHeader(title: 'Territory'),
          AppCard(
            child: Column(
              children: [
                KeyValueRow(label: 'Territory', value: employee.territoryName),
                KeyValueRow(
                  label: 'Headquarters',
                  value: employee.headquarters,
                ),
                KeyValueRow(label: 'Area', value: employee.areaName),
                KeyValueRow(label: 'Cluster', value: employee.clusterName),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          const SectionHeader(title: 'Contact'),
          AppCard(
            child: Column(
              children: [
                KeyValueRow(label: 'Mobile', value: employee.mobile),
                KeyValueRow(label: 'Email', value: employee.email),
                KeyValueRow(label: 'Blood group', value: employee.bloodGroup),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _blood;

  @override
  void initState() {
    super.initState();
    final employee = ref.read(currentEmployeeProvider);
    _mobile = TextEditingController(text: employee.mobile);
    _email = TextEditingController(text: employee.email);
    _blood = TextEditingController(text: employee.bloodGroup ?? '');
  }

  @override
  void dispose() {
    _mobile.dispose();
    _email.dispose();
    _blood.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Edit Profile')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: 'Save',
            onPressed: () {
              context.pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: AppSizes.iconMd,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Name, role and territory are managed by your '
                    'administrator. Contact details you can change yourself.',
                    style: AppTypography.bodySm,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Mobile number',
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
          const SizedBox(height: AppSpacing.lg),
          AppTextField(label: 'Blood group', controller: _blood),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// =========================================================== notifications ==

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider(_unreadOnly));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Notifications')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(
            label: 'Mark all as read',
            icon: Icons.done_all,
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: SegmentedControl<bool>(
              options: const [false, true],
              selected: _unreadOnly,
              labelOf: (v) => v ? 'Unread' : 'All',
              onSelected: (v) => setState(() => _unreadOnly = v),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) => const ErrorState(),
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: Icons.notifications_none,
                      title: _unreadOnly
                          ? 'Nothing unread'
                          : 'No notifications',
                      message: _unreadOnly
                          ? "You're all caught up."
                          : 'Approvals, tasks and reminders appear here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        0,
                        AppSpacing.screenH,
                        AppSpacing.xxxl,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.cardGap),
                      itemBuilder: (context, i) => Arrive.staggered(
                        index: i,
                        child: _NotificationCard(
                          notification: items[i],
                          onTap: () async {
                            await ref
                                .read(notificationRepositoryProvider)
                                .markRead(items[i].id);
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadNotificationsProvider);
                            if (context.mounted && items[i].deepLink != null) {
                              navigateTo(context, items[i].deepLink!);
                            }
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: notification.isRead ? AppColors.surface : AppColors.brandSoft,
      borderColor: notification.isRead ? AppColors.border : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread gets the lit well, read gets a flat grey chip. The glow is
          // doing real work here rather than decorating: an unread row is the
          // only one on the screen giving off light.
          IconTile(
            icon: notification.kind.icon,
            background: notification.isRead ? AppColors.surfaceSecondary : null,
            color: notification.isRead ? AppColors.textSecondary : null,
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
                        notification.title,
                        style: AppTypography.titleMd,
                      ),
                    ),
                    Text(
                      Fmt.timeAgo(notification.createdAt),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(notification.body, style: AppTypography.bodySm),
              ],
            ),
          ),
          if (!notification.isRead)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.xs),
              child: StatusDot(color: AppColors.brand, size: 7),
            ),
        ],
      ),
    );
  }
}

// =============================================================== settings ==

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          const SectionHeader(title: 'Notifications'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ToggleRow(
                  title: 'Push notifications',
                  subtitle: 'Approvals, tasks and reminders',
                  value: true,
                  onChanged: (_) =>
                      showComingWithBackend(context, 'Notification settings'),
                ),
                const Divider(height: 1, indent: AppSpacing.cardPadding),
                _ToggleRow(
                  title: 'Visit reminders',
                  subtitle: 'Alert 15 minutes before each planned visit',
                  value: true,
                  onChanged: (_) =>
                      showComingWithBackend(context, 'Notification settings'),
                ),
                const Divider(height: 1, indent: AppSpacing.cardPadding),
                _ToggleRow(
                  title: 'Daily report reminder',
                  subtitle: 'Prompt at 7 PM if the day is not submitted',
                  value: false,
                  onChanged: (_) =>
                      showComingWithBackend(context, 'Notification settings'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Developer'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Present because there is no backend yet: it is the only way
                // to exercise the offline treatments in a demo build.
                _ToggleRow(
                  title: 'Simulate offline',
                  subtitle: 'Test how the app behaves without a connection',
                  value: !isOnline,
                  onChanged: (v) =>
                      ref.read(isOnlineProvider.notifier).setOnline(!v),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'About'),
          AppCard(
            child: Column(
              children: [
                const KeyValueRow(label: 'Version', value: '1.0.0 (mock data)'),
                const KeyValueRow(label: 'Backend', value: 'Not connected'),
                KeyValueRow(
                  label: 'Geo-fence',
                  value:
                      '${ref.watch(geoFenceRadiusProvider).round()} m · '
                      '${ref.watch(geoFencePolicyProvider).name}',
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: AppTypography.titleMd),
      subtitle: Text(subtitle, style: AppTypography.caption),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const faqs = [
      (
        'Why is my visit showing as unverified?',
        'Your phone reported a position more than 50 metres from the '
            "client's registered address. The visit is still recorded — it is "
            'simply flagged so your manager has the context.',
      ),
      (
        'I lost signal during a visit. Is my work saved?',
        'Yes. Visits, expenses and orders are saved on your device first and '
            'sync automatically once you reconnect. The Sync Centre shows '
            'anything still waiting.',
      ),
      (
        'My expense was rejected. What do I do?',
        'Open the expense to read the reason your manager gave, correct the '
            'issue, and submit it again.',
      ),
      (
        'How far ahead can I plan tours?',
        'Up to 30 days. Submit tour plans early so your manager can approve '
            'them before the dates arrive.',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          const SectionHeader(title: 'Common questions'),
          for (final (question, answer) in faqs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question, style: AppTypography.titleMd),
                    const SizedBox(height: AppSpacing.sm),
                    Text(answer, style: AppTypography.bodySm),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Contact'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const IconTile(icon: Icons.phone_outlined),
                  title: Text('Call support', style: AppTypography.titleMd),
                  subtitle: Text(
                    '1800 200 4040 · Mon–Sat, 9 AM–7 PM',
                    style: AppTypography.caption,
                  ),
                  onTap: () => showComingWithBackend(context, 'Calling'),
                ),
                const Divider(height: 1, indent: AppSpacing.cardPadding),
                ListTile(
                  leading: const IconTile(icon: Icons.mail_outline),
                  title: Text('Email support', style: AppTypography.titleMd),
                  subtitle: Text(
                    'support@pharmaconnect.in',
                    style: AppTypography.caption,
                  ),
                  onTap: () => showComingWithBackend(context, 'Email'),
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

// ============================================================ sync center ==

/// Sync Centre (§137). Shows what is waiting, what failed, and lets the user
/// retry. A field worker must always be able to answer "is my work safe?".
class SyncCenterScreen extends ConsumerWidget {
  const SyncCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingSyncCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Sync Centre')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          AppCard(
            color: isOnline ? AppColors.successSoft : AppColors.warningSoft,
            borderColor: Colors.transparent,
            child: Row(
              children: [
                Icon(
                  isOnline
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 26,
                  color: isOnline ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnline ? 'Connected' : 'Offline',
                        style: AppTypography.titleMd.copyWith(
                          color: isOnline
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline
                            ? 'Everything is up to date.'
                            : '$pending item${pending == 1 ? '' : 's'} saved '
                                  'on this device, waiting to sync.',
                        style: AppTypography.bodySm.copyWith(
                          color: isOnline
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Queue'),
          if (pending == 0)
            const AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.check_circle_outline,
                title: 'Nothing waiting',
                message: 'All your work has been synced to the server.',
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < pending; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: const IconTile(
                        icon: Icons.schedule_outlined,
                        color: AppColors.warning,
                      ),
                      title: Text(
                        i == 0
                            ? 'Visit — Dr. Anjali Sharma'
                            : 'Expense — Travel',
                        style: AppTypography.titleMd,
                      ),
                      subtitle: Text(
                        'Saved locally · waiting for a connection',
                        style: AppTypography.caption,
                      ),
                      trailing: const StatusBadge(
                        label: 'Pending',
                        tone: StatusTone.warning,
                        dense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Sync now',
            icon: Icons.sync,
            onPressed: isOnline
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Everything is already synced.'),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// ================================================================= search ==

/// Global search (§56). Results are grouped by entity type, because a flat
/// list of mixed results forces the user to re-read every row.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: SearchField(
          hint: 'Search clients, activities, orders…',
          controller: _controller,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
        ),
        titleSpacing: 0,
      ),
      body: _query.trim().length < 2
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search Mr Sales',
              message:
                  'Find clients, visits, orders and team members. '
                  'Type at least two characters.',
            )
          : FutureBuilder(
              future: _search(ref, session, _query),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LoadingState();
                final results = snapshot.data!;

                if (results.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No results for "$_query"',
                    message: 'Try a different name, code or area.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  children: [
                    for (final group in results.entries) ...[
                      SectionHeader(
                        title: '${group.key} (${group.value.length})',
                      ),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < group.value.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              ListTile(
                                leading: Icon(
                                  group.value[i].icon,
                                  color: AppColors.brand,
                                  size: AppSizes.iconLg,
                                ),
                                title: Text(
                                  group.value[i].title,
                                  style: AppTypography.titleMd,
                                ),
                                subtitle: Text(
                                  group.value[i].subtitle,
                                  style: AppTypography.caption,
                                ),
                                onTap: () =>
                                    navigateTo(context, group.value[i].route),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _SearchHit {
  const _SearchHit({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

Future<Map<String, List<_SearchHit>>> _search(
  WidgetRef ref,
  Session session,
  String query,
) async {
  final q = query.trim().toLowerCase();
  final results = <String, List<_SearchHit>>{};

  final clients = await ref
      .read(clientRepositoryProvider)
      .list(session, query: q);
  if (clients.isNotEmpty) {
    results['Clients'] = [
      for (final c in clients.take(6))
        _SearchHit(
          title: c.name,
          subtitle: '${c.subtitle} · ${c.areaName}',
          icon: Icons.person_outline,
          route: Routes.clientDetail(c.id),
        ),
    ];
  }

  final orders = await ref.read(businessRepositoryProvider).orders(session);
  final matchedOrders = orders
      .where(
        (o) =>
            o.orderNumber.toLowerCase().contains(q) ||
            o.clientName.toLowerCase().contains(q),
      )
      .take(5)
      .toList();
  if (matchedOrders.isNotEmpty) {
    results['Orders'] = [
      for (final o in matchedOrders)
        _SearchHit(
          title: o.orderNumber,
          subtitle: '${o.clientName} · ${Fmt.money(o.grandTotal)}',
          icon: Icons.shopping_bag_outlined,
          route: Routes.orderDetail(o.id),
        ),
    ];
  }

  if (session.isManager) {
    final team = await ref.read(employeeRepositoryProvider).teamOf(session);
    final matched = team
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.employeeCode.toLowerCase().contains(q),
        )
        .take(5)
        .toList();
    if (matched.isNotEmpty) {
      results['Team'] = [
        for (final e in matched)
          _SearchHit(
            title: e.name,
            subtitle: '${e.employeeCode} · ${e.designation}',
            icon: Icons.badge_outlined,
            route: Routes.employeeDetail(e.id),
          ),
      ];
    }
  }

  return results;
}
