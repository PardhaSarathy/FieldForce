import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/states.dart';
import 'app_drawer.dart';

/// Key for the shell's Scaffold, so a screen nested inside the shell can open
/// the side menu. Screens have their own Scaffolds, which means `Scaffold.of`
/// would find the wrong one.
final shellScaffoldKeyProvider =
    Provider<GlobalKey<ScaffoldState>>((ref) => GlobalKey<ScaffoldState>());

/// Opens the app's side menu from anywhere inside the shell.
void openAppDrawer(WidgetRef ref) =>
    ref.read(shellScaffoldKeyProvider).currentState?.openDrawer();

/// One tab in the bottom navigation.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}

/// Navigation adapts to role (§13) while reusing one visual language — a
/// manager gets Team where a rep gets Business, but nothing else changes.
///
/// Four tabs, not five: the old "More" tab was a menu masquerading as a
/// destination. Every module it held now lives in the side menu, which is
/// where users look for a full index anyway — and four tabs sit either side of
/// the docked action button without crowding it.
List<NavDestination> destinationsFor({required bool isManager, required bool isAdmin}) {
  if (isAdmin) {
    return const [
      NavDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        route: Routes.admin,
      ),
      NavDestination(
        label: 'Users',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        route: Routes.adminUsers,
      ),
      NavDestination(
        label: 'Master Data',
        icon: Icons.storage_outlined,
        activeIcon: Icons.storage,
        route: Routes.adminMasterData,
      ),
      NavDestination(
        label: 'Reports',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        route: Routes.reports,
      ),
    ];
  }

  return [
    const NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      route: Routes.home,
    ),
    const NavDestination(
      label: 'Activity',
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note,
      route: Routes.activity,
    ),
    if (isManager)
      const NavDestination(
        label: 'Team',
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups,
        route: Routes.team,
      )
    else
      const NavDestination(
        label: 'Business',
        icon: Icons.trending_up_outlined,
        activeIcon: Icons.trending_up,
        route: Routes.business,
      ),
    const NavDestination(
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      route: Routes.reports,
    ),
  ];
}

/// Persistent chrome around the five primary destinations.
///
/// The offline strip lives here rather than per screen so connectivity is
/// communicated continuously (§61), and the central action button is anchored
/// to the shell because "record something" is available from every tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final pendingSync = ref.watch(pendingSyncCountProvider);

    final destinations = destinationsFor(
      isManager: session.isManager,
      isAdmin: session.isAdmin,
    );

    return Scaffold(
      key: ref.watch(shellScaffoldKeyProvider),
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      body: Column(
        children: [
          if (!isOnline)
            OfflineBanner(
              pendingCount: pendingSync,
              onTap: () => context.push(Routes.syncCenter),
            ),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: session.isAdmin
          ? null
          : _QuickAddButton(isManager: session.isManager),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        destinations: destinations,
        currentIndex: navigationShell.currentIndex,
        showCentreGap: !session.isAdmin,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
    required this.showCentreGap,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showCentreGap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++) ...[
                // Reserve room for the docked action button between tabs 2 & 3.
                if (showCentreGap && i == 2) const SizedBox(width: 64),
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    isSelected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.brand : AppColors.textSecondary;

    return Semantics(
      selected: isSelected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? destination.activeIcon : destination.icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: AppTypography.overline.copyWith(
                color: color,
                letterSpacing: 0.2,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The docked "+" opens a sheet of the actions a user can start from anywhere.
/// Contents are role-aware so a manager is offered assignment actions rather
/// than visit logging.
class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.isManager});

  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showQuickActions(context, isManager: isManager),
      tooltip: 'Quick actions',
      child: const Icon(Icons.add, size: 26),
    );
  }
}

void _showQuickActions(BuildContext context, {required bool isManager}) {
  final actions = <(IconData, String, String, String)>[
    if (!isManager) ...[
      (Icons.event_available_outlined, 'Add activity',
          'Log or plan a client visit', Routes.addActivity),
      (Icons.person_add_alt_outlined, 'New client',
          'Register a doctor, hospital or chemist', Routes.newClient),
      (Icons.receipt_long_outlined, 'New expense',
          'Claim travel, food or lodging', Routes.newExpense),
      (Icons.shopping_bag_outlined, 'New order',
          'Capture an order for a client', Routes.newOrder),
      (Icons.map_outlined, 'Travel plan', 'Plan an upcoming tour',
          Routes.newTravelPlan),
    ] else ...[
      (Icons.assignment_outlined, 'Assign task', 'Give a team member a task',
          Routes.taskAssignment),
      (Icons.flag_outlined, 'Set targets', 'Assign monthly targets',
          Routes.targetAssignment),
      (Icons.receipt_long_outlined, 'New expense', 'Claim your own expense',
          Routes.newExpense),
      (Icons.event_busy_outlined, 'Apply leave', 'Request time off',
          Routes.newLeave),
    ],
  ];

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.md),
            child: Row(
              children: [
                Text('Quick actions', style: AppTypography.h3),
              ],
            ),
          ),
          for (final (icon, title, subtitle, route) in actions)
            ListTile(
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 19, color: AppColors.brand),
              ),
              title: Text(title, style: AppTypography.titleMd),
              subtitle: Text(subtitle, style: AppTypography.caption),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(route);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}
