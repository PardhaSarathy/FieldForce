import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

/// The side menu (§12 Drawer, §55).
///
/// The app's full index. Bottom tabs carry the four things a user touches
/// constantly; everything else lives here, grouped by the job it belongs to.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final employee = session.employee;

    void go(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    // The drawer is now the app's full index — it replaced the "More" tab, so
    // every module has to be reachable here. Grouped, because a flat list of
    // twenty destinations is not navigable.
    final groups = <(String, List<({IconData icon, String label, String route})>)>[
      // An administrator owns the system, not a territory: they have no day
      // plan, expenses or tour plans of their own, so offering those here
      // would be eight guaranteed-empty screens.
      if (!session.isAdmin)
        (
          'Field operations',
          [
            (icon: Icons.today_outlined, label: "Today's Plan", route: Routes.dayPlan),
            (icon: Icons.people_outline, label: 'Clients', route: Routes.clients),
            (icon: Icons.map_outlined, label: 'Travel', route: Routes.travel),
            (icon: Icons.receipt_long_outlined, label: 'Expenses', route: Routes.expenses),
            (icon: Icons.calendar_month_outlined, label: 'Calendar', route: Routes.calendar),
            (icon: Icons.assignment_outlined, label: 'Tasks', route: Routes.tasks),
          ],
        ),
      (
        'Business',
        [
          (icon: Icons.trending_up, label: 'Sales', route: Routes.sales),
          (icon: Icons.flag_outlined, label: 'Targets', route: Routes.targets),
          (icon: Icons.shopping_bag_outlined, label: 'Orders', route: Routes.orders),
        ],
      ),
      (
        'Workplace',
        [
          if (!session.isAdmin)
            (icon: Icons.badge_outlined, label: 'HR', route: Routes.hr),
          (icon: Icons.chat_bubble_outline, label: 'Chat', route: Routes.chat),
          (icon: Icons.library_books_outlined, label: 'Resources', route: Routes.resources),
          (icon: Icons.fact_check_outlined, label: 'Surveys', route: Routes.surveys),
          (icon: Icons.report_problem_outlined, label: 'Complaints', route: Routes.complaints),
        ],
      ),
      if (session.isManager)
        (
          'Management',
          [
            (icon: Icons.checklist_outlined, label: 'Approvals', route: Routes.approvals),
            (icon: Icons.groups_outlined, label: 'My Team', route: Routes.team),
            (icon: Icons.map_outlined, label: 'Team Map', route: Routes.teamMap),
            (icon: Icons.flag_outlined, label: 'Assign Targets', route: Routes.targetAssignment),
            (icon: Icons.payments_outlined, label: 'Travel Rates', route: Routes.rateAssignment),
            (icon: Icons.insights_outlined, label: 'Team Performance', route: Routes.teamPerformance),
          ],
        ),
      if (session.isAdmin)
        (
          'Administration',
          [
            (icon: Icons.people_alt_outlined, label: 'Users', route: Routes.adminUsers),
            (icon: Icons.storage_outlined, label: 'Master Data', route: Routes.adminMasterData),
            (icon: Icons.my_location_outlined, label: 'Geo-fence', route: Routes.adminGeoFence),
            (icon: Icons.rule_outlined, label: 'Approval Rules', route: Routes.adminApprovalRules),
          ],
        ),
      (
        'Account',
        [
          (icon: Icons.person_outline, label: 'My Profile', route: Routes.profile),
          if (!session.isAdmin)
            (icon: Icons.folder_outlined, label: 'My Documents', route: Routes.documents),
          (icon: Icons.notifications_none, label: 'Notifications', route: Routes.notifications),
          (icon: Icons.sync_outlined, label: 'Sync Center', route: Routes.syncCenter),
          (icon: Icons.settings_outlined, label: 'Settings', route: Routes.settings),
          (icon: Icons.help_outline, label: 'Help & Support', route: Routes.help),
        ],
      ),
    ];

    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  AppAvatar(name: employee.name, size: AppSizes.avatarLg),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: AppTypography.titleMd,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          employee.employeeCode,
                          style: AppTypography.caption,
                        ),
                        Text(
                          employee.headquarters,
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                children: [
                  for (final (title, items) in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.xs,
                      ),
                      child: Text(title.toUpperCase(),
                          style: AppTypography.overline),
                    ),
                    for (final item in items)
                      ListTile(
                        dense: true,
                        leading: Icon(item.icon,
                            size: AppSizes.iconMd, color: AppColors.brand),
                        title:
                            Text(item.label, style: AppTypography.titleSm),
                        onTap: () => go(item.route),
                      ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ListTile(
                leading: const Icon(Icons.logout,
                    size: AppSizes.iconLg, color: AppColors.error),
                title: Text(
                  'Logout',
                  style: AppTypography.titleMd
                      .copyWith(color: AppColors.error),
                ),
                onTap: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Sign out?',
                    message: 'Any work saved on this device stays safe and '
                        'will sync the next time you sign in.',
                    confirmLabel: 'Sign out',
                    isDestructive: true,
                  );
                  if (confirmed) {
                    await ref.read(authControllerProvider.notifier).logout();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
