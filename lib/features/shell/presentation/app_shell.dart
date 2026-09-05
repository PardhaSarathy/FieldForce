import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/states.dart';
import 'app_drawer.dart';

/// Key for the shell's Scaffold, so a screen nested inside the shell can open
/// the side menu. Screens have their own Scaffolds, which means `Scaffold.of`
/// would find the wrong one.
final shellScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>(
  (ref) => GlobalKey<ScaffoldState>(),
);

/// Opens the app's side menu from anywhere inside the shell.
void openAppDrawer(WidgetRef ref) =>
    ref.read(shellScaffoldKeyProvider).currentState?.openDrawer();

/// The leading control for a screen that is a shell branch root.
///
/// A branch root has nothing to pop back to, so the slot that would hold a
/// back arrow holds the app's index instead. Pushed screens keep their normal
/// implied back button — see the navigation rules in CLAUDE.md.
class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Back when there is somewhere to go back to, the menu when there is not.
    //
    // The same screen is a tab root for one role and a pushed screen for
    // another — My Activity is a manager's tab and a rep arrives at it from
    // the module grid. Hard-coding the menu stranded the rep: no back arrow
    // on a screen they had pushed. Asking the navigator is the only thing
    // that is true in both positions, and it means no screen has to know
    // which one it is in.
    if (Navigator.of(context).canPop()) return const BackButton();

    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onPressed: () => openAppDrawer(ref),
    );
  }
}

/// One tab in the bottom navigation.
///
/// [branch] is the index of the shell branch this tab shows. It is carried
/// explicitly because the branches are role-neutral — every branch holds
/// exactly one route — while the visible four tabs differ per role. Without
/// it, tapping a tab would switch to the branch at the tab's own position and
/// land on whatever route happened to be first there.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    required this.branch,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final int branch;
}

/// Branch indices, matching the order declared in the router. One route per
/// branch, so a branch's default location is never ambiguous.
abstract final class ShellBranch {
  static const home = 0;
  static const activity = 1;
  static const team = 2;
  static const reports = 3;
  static const chat = 4;
  static const resources = 5;
  static const admin = 6;
  static const adminUsers = 7;
  static const adminMasterData = 8;
  static const tasks = 9;
}

/// Navigation adapts to role (§13) while reusing one visual language.
///
/// Four tabs, not five: the old "More" tab was a menu masquerading as a
/// destination. Every module it held now lives in the side menu, which is
/// where users look for a full index anyway — and four tabs sit either side of
/// the docked action button without crowding it.
///
/// A field rep's four are the ones they touch hourly: their day, what they owe,
/// the material they show a doctor, and their numbers. Chat moved to the top
/// bar — it is checked, not navigated to, so it belongs with notifications
/// rather than taking a quarter of the bar.
List<NavDestination> destinationsFor({
  required bool isManager,
  required bool isAdmin,
}) {
  if (isAdmin) {
    return const [
      NavDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        route: Routes.admin,
        branch: ShellBranch.admin,
      ),
      NavDestination(
        label: 'Users',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        route: Routes.adminUsers,
        branch: ShellBranch.adminUsers,
      ),
      NavDestination(
        label: 'Master Data',
        icon: Icons.storage_outlined,
        activeIcon: Icons.storage,
        route: Routes.adminMasterData,
        branch: ShellBranch.adminMasterData,
      ),
      NavDestination(
        label: 'Reports',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        route: Routes.reports,
        branch: ShellBranch.reports,
      ),
    ];
  }

  if (isManager) {
    return const [
      NavDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        route: Routes.home,
        branch: ShellBranch.home,
      ),
      NavDestination(
        label: 'Activity',
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_note,
        route: Routes.activity,
        branch: ShellBranch.activity,
      ),
      NavDestination(
        label: 'Team',
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups,
        route: Routes.team,
        branch: ShellBranch.team,
      ),
      NavDestination(
        label: 'Reports',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        route: Routes.reports,
        branch: ShellBranch.reports,
      ),
    ];
  }

  return const [
    NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      route: Routes.home,
      branch: ShellBranch.home,
    ),
    NavDestination(
      label: 'To-Do',
      icon: Icons.checklist_outlined,
      activeIcon: Icons.checklist,
      route: Routes.tasks,
      branch: ShellBranch.tasks,
    ),
    NavDestination(
      label: 'Resources',
      icon: Icons.library_books_outlined,
      activeIcon: Icons.library_books,
      route: Routes.resources,
      branch: ShellBranch.resources,
    ),
    NavDestination(
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      route: Routes.reports,
      branch: ShellBranch.reports,
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

    // The bar highlights the tab whose branch is showing. A role never sees a
    // tab for a branch outside its own list, but a deep link could still land
    // on one, so fall back to no selection rather than an out-of-range index.
    final selected = destinations.indexWhere(
      (d) => d.branch == navigationShell.currentIndex,
    );

    // Switching branches uses `go`, which leaves no route to pop — so without
    // this, the Android back gesture on any tab but the first closed the app
    // outright. Back now walks to the first tab, and only exits from there,
    // which is what every tabbed Android app does.
    // `indexWhere` answers -1 when the branch on screen is not one of this
    // role's tabs — reachable by deep link, and previously read as "we are on
    // the first tab", so back exited the app from a screen the user had
    // navigated *into*. Only a genuine index of 0 is the first tab.
    final onFirstTab = selected == 0;

    return PopScope(
      canPop: onFirstTab,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || onFirstTab) return;
        navigationShell.goBranch(destinations.first.branch);
      },
      child: Scaffold(
        key: ref.watch(shellScaffoldKeyProvider),
        backgroundColor: Colors.transparent,
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
        // No floatingActionButton: a docked FAB floats above the bar and overlaps
        // whatever is behind it. The action now sits inside the bar itself, level
        // with the tabs.
        bottomNavigationBar: _BottomBar(
          destinations: destinations,
          currentIndex: selected,
          showCentreGap: !session.isAdmin,
          isManager: session.isManager,
          onTap: (index) {
            AppHaptics.selection();
            final branch = destinations[index].branch;
            navigationShell.goBranch(
              branch,
              // Tapping the tab you are already on returns to its root.
              initialLocation: branch == navigationShell.currentIndex,
            );
          },
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
    this.isManager = false,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showCentreGap;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    // A floating bar rather than a full-width strip welded to the bottom
    // edge. The selected tab is a filled pill carrying its icon *and* label
    // while the rest are icon-only — five equal labels compete with each
    // other, and the pill says where you are without anything having to be
    // read.
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl + 4),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 30,
                spreadRadius: -16,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Material(
            color: AppColors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl + 4),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (showCentreGap && i == 2)
                      _QuickAddButton(isManager: isManager),
                    // Only the selected item flexes. The others are icon-only
                    // and size to their content — giving all four an equal
                    // share left the labelled one too narrow and it rendered
                    // as "Ho".
                    if (i == currentIndex)
                      Flexible(
                        child: _NavItem(
                          destination: destinations[i],
                          isSelected: true,
                          onTap: () => onTap(i),
                        ),
                      )
                    else
                      _NavItem(
                        destination: destinations[i],
                        isSelected: false,
                        onTap: () => onTap(i),
                      ),
                  ],
                ],
              ),
            ),
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
    return Semantics(
      selected: isSelected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 42,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? AppSpacing.md : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.brandLight, AppColors.brand],
                  )
                : null,
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: AppColors.brandGlow,
                      blurRadius: 12,
                      spreadRadius: -3,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? destination.activeIcon : destination.icon,
                size: 21,
                color: isSelected
                    ? AppColors.textOnBrand
                    : AppColors.textSecondary,
              ),
              // The label belongs to the selected tab only. Wrapped so it
              // animates in rather than snapping, and clipped so the row never
              // overflows mid-transition.
              if (isSelected)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Text(
                      destination.label,
                      style: AppTypography.titleSm.copyWith(
                        color: AppColors.textOnBrand,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The quick-add button opens a sheet of the actions a user can start from
/// anywhere. Contents are role-aware so a manager is offered assignment
/// actions rather than visit logging.
///
/// A circle, not a rounded rectangle wedged into the bar, and one of the three
/// things in the app carrying a coloured shadow.
class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.isManager});

  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Tooltip(
        // "Add", not "Quick actions". The button adds things; naming it after
        // the pattern it is built from is the same tell that got the heading
        // taken off Home's module grid.
        message: 'Add',
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandLight, AppColors.brandDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandGlow,
                blurRadius: 18,
                spreadRadius: -2,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showQuickActions(context, isManager: isManager),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.add, size: 24, color: AppColors.textOnBrand),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showQuickActions(BuildContext context, {required bool isManager}) {
  final actions = <(IconData, String, String, String)>[
    if (!isManager) ...[
      (
        Icons.event_available_outlined,
        'Add activity',
        'Log or plan a client visit',
        Routes.addActivity,
      ),
      (
        Icons.person_add_alt_outlined,
        'New client',
        'Register a doctor, hospital or chemist',
        Routes.newClient,
      ),
      (
        Icons.shopping_bag_outlined,
        'New order',
        'Capture an order for a client',
        Routes.newOrder,
      ),
      // Lands on the month, not a blank day. A tour plan is submitted whole,
      // so "add" starts with the calendar showing which days are still empty.
      (
        Icons.map_outlined,
        'Tour plan',
        'Plan next month',
        Routes.travelPlans,
      ),
    ] else ...[
      (
        Icons.assignment_outlined,
        'Assign task',
        'Give a team member a task',
        Routes.taskAssignment,
      ),
      (
        Icons.flag_outlined,
        'Set targets',
        'Assign monthly targets',
        Routes.targetAssignment,
      ),
      (
        Icons.event_busy_outlined,
        'Apply leave',
        'Request time off',
        Routes.newLeave,
      ),
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
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.md,
            ),
            child: Row(
              children: [Text('Add new', style: AppTypography.h3)],
            ),
          ),
          for (final (icon, title, subtitle, route) in actions)
            ListTile(
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
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
