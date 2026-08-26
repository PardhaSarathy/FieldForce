import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/activity.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';
import '../../manager/presentation/manager_dashboard_screen.dart';
import '../../authentication/presentation/widgets/brand_mark.dart';
import '../../shell/presentation/app_shell.dart';

/// Home / My Day (§15).
///
/// This screen answers exactly one question: *what do I need to do today?*
/// It is deliberately not an analytics dashboard (§78) — no sales charts, no
/// KPI grid, no target rings. Those live in Business and Reports, one tap away.
///
/// The hierarchy is: where am I → how am I doing → what is next → what else can
/// I start. Everything below "next action" is secondary.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    // A manager's "home" is their team's exceptions, not their own visit list.
    if (session.isManager) return const ManagerDashboardScreen();

    final summaryAsync = ref.watch(todaySummaryProvider);
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final employee = session.employee;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(todaySummaryProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(
                  name: employee.name.split(' ').first,
                  territory: employee.headquarters,
                  unreadCount: unread,
                ),
              ),
              summaryAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxxl * 2),
                    child: LoadingState(message: 'Loading your day'),
                  ),
                ),
                error: (_, _) => SliverToBoxAdapter(
                  child: ErrorState(
                    onRetry: () => ref.invalidate(todaySummaryProvider),
                  ),
                ),
                data: (summary) => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    0,
                    AppSpacing.screenH,
                    AppSpacing.xxxl * 3,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _TodayMetrics(summary: summary),
                      const SizedBox(height: AppSpacing.md),
                      _StatusStrip(summary: summary),
                      const SizedBox(height: AppSpacing.section),
                      _NextActionSection(summary: summary),
                      const SizedBox(height: AppSpacing.section),
                      const _QuickActionsGrid(),
                      const SizedBox(height: AppSpacing.section),
                      _RestOfDay(summary: summary),
                    ],
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

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.name,
    required this.territory,
    required this.unreadCount,
  });

  final String name;
  final String territory;
  final int unreadCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    return Column(
      // Explicit: the greeting block spans the full width and its text is
      // left-aligned at the gutter. Relying on the default here would leave
      // the alignment at the mercy of whether the widest line happens to fill
      // the row.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top bar: menu, brand, actions. The greeting used to share this row,
        // which squeezed it into a narrow column on the right. Giving the brand
        // the centre and dropping the greeting below restores a normal
        // app-bar rhythm and lets the greeting breathe at full width.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              _HeaderIconButton(
                icon: Icons.menu,
                onTap: () => openAppDrawer(ref),
                tooltip: 'Menu',
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CustomPaint(painter: BrandMarkPainter()),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Flexible so the wordmark gives way on a 320pt phone
                    // rather than pushing the action buttons off-screen.
                    Flexible(
                      child: Text(
                        'PharmaConnect',
                        style: AppTypography.titleMd.copyWith(
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIconButton(
                icon: Icons.search,
                onTap: () => context.push(Routes.search),
                tooltip: 'Search',
              ),
              const SizedBox(width: AppSpacing.sm),
              _HeaderIconButton(
                icon: Icons.notifications_none,
                badgeCount: unreadCount,
                onTap: () => context.push(Routes.notifications),
                tooltip: 'Notifications',
              ),
            ],
          ),
        ),

        // Greeting block, full width beneath the bar.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Fmt.weekday(now)} · ${Fmt.date(now)} · $territory',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('${Fmt.greeting()}, $name', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.xxs),
              Text("Here's your agenda for today.",
                  style: AppTypography.bodySm),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20, color: AppColors.textPrimary),
              if (badgeCount > 0)
                Positioned(
                  right: -4,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: AppTypography.badge.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                      ),
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

/// Current status and today's progress, combined into one card because they
/// are read together — "where am I working, and how far through am I".
/// The three figures a rep checks first: how today is going, how much work it
/// holds, and what is outstanding.
///
/// Tinted cards rather than three identical white ones — the tint groups the
/// row visually and gives each card its own identity without introducing a
/// colour from outside the palette. Teal carries progress, sand carries
/// what-is-waiting; both are already load-bearing elsewhere in the app.
class _TodayMetrics extends ConsumerWidget {
  const _TodayMetrics({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayAsync = ref.watch(
      daySummaryProvider(DateTime(yesterday.year, yesterday.month, yesterday.day)),
    );
    final pendingTasks = ref.watch(pendingTaskCountProvider).valueOrNull;
    final monthTarget = ref.watch(monthlyVisitTargetProvider).valueOrNull;

    final yesterdayPlanned = yesterdayAsync.valueOrNull?.planned;
    final delta = yesterdayPlanned == null
        ? null
        : summary.planned - yesterdayPlanned;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: _MetricTile(
              label: "Today's Goal",
              icon: Icons.track_changes_outlined,
              background: AppColors.surface,
              accent: AppColors.brand,
              body: Center(
                child: _GoalRing(
                  percent: summary.progress * 100,
                  caption: 'Achieved',
                ),
              ),
              // Kept short: the tile is a third of a phone wide, and
              // "this month" was the first thing to be ellipsised away.
              footer: monthTarget == null
                  ? '${summary.completed} / ${summary.planned} today'
                  : '${monthTarget.visitsAchieved} / '
                      '${monthTarget.visitTarget} visits',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 9,
            child: _MetricTile(
              label: "Today's Work",
              icon: Icons.event_available_outlined,
              background: AppColors.brandSoft,
              accent: AppColors.brandDark,
              onTap: () => context.push(Routes.dayPlan),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${summary.planned}', style: AppTypography.metric),
                  Text('Planned Visits',
                      style: AppTypography.caption, maxLines: 2),
                ],
              ),
              footerWidget: delta == null || delta == 0
                  ? Text('Same as yesterday', style: AppTypography.caption)
                  : Row(
                      children: [
                        Icon(
                          delta > 0 ? Icons.north_east : Icons.south_east,
                          size: 12,
                          color: delta > 0
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            '${delta.abs()} ${delta > 0 ? 'more' : 'fewer'} '
                            'than yesterday',
                            style: AppTypography.caption.copyWith(fontSize: 11),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 9,
            child: _MetricTile(
              label: 'Pending Tasks',
              icon: Icons.checklist_outlined,
              background: AppColors.sandSoft,
              accent: AppColors.textPrimary,
              onTap: () => context.push(Routes.tasks),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pendingTasks == null
                      ? const Skeleton(width: 36, height: 26)
                      : Text('$pendingTasks', style: AppTypography.metric),
                  Text('Tasks Pending',
                      style: AppTypography.caption, maxLines: 2),
                ],
              ),
              footerWidget: Row(
                children: [
                  Flexible(
                    child: Text(
                      'View All',
                      style: AppTypography.titleSm
                          .copyWith(color: AppColors.brand),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.brand),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.icon,
    required this.background,
    required this.accent,
    required this.body,
    this.footer,
    this.footerWidget,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color accent;
  final Widget body;
  final String? footer;
  final Widget? footerWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isTinted = background != AppColors.surface;

    return AppCard(
      onTap: onTap,
      color: background,
      borderColor: isTinted ? Colors.transparent : AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // On a tinted card the icon chip lifts out in white; on the
              // white card it needs a tint of its own to read as a chip.
              color: isTinted ? AppColors.surface : AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.titleSm
                .copyWith(color: accent, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: body),
          const SizedBox(height: AppSpacing.sm),
          if (footerWidget != null)
            footerWidget!
          else if (footer != null)
            Text(
              footer!,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// Compact progress ring for the goal tile.
class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.percent, required this.caption});

  final double percent;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final color = percent >= 100
        ? AppColors.success
        : percent >= 50
            ? AppColors.brand
            : AppColors.warning;

    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percent.round()}%',
                style: AppTypography.metricSm.copyWith(color: color),
              ),
              Text(
                caption,
                style: AppTypography.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where I am working and whether I am keeping pace — the context §15 asks for,
/// now that the numbers themselves live in the tiles above.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final inProgress = summary.inProgress;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          StatusDot(
            color: inProgress != null ? AppColors.success : AppColors.brand,
            size: 8,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              inProgress != null
                  ? 'Visit in progress'
                  : summary.workType.label,
              style: AppTypography.titleSm,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              summary.paceLabel(),
              style: AppTypography.caption,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The single most important element on the screen: the next thing to do.
class _NextActionSection extends ConsumerWidget {
  const _NextActionSection({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = summary.inProgress ?? summary.nextAction;

    if (next == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Next action'),
          AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.task_alt,
              title: summary.planned == 0
                  ? 'No visits planned today'
                  : 'All visits complete',
              message: summary.planned == 0
                  ? 'Add an activity to start building your day.'
                  : 'Nice work. Your day plan is fully covered.',
              actionLabel: summary.planned == 0 ? 'Add activity' : null,
              onAction: () => context.push(Routes.addActivity),
            ),
          ),
        ],
      );
    }

    final isRunning = next.status == ActivityStatus.inProgress;
    final minutesAway =
        next.scheduledStart.difference(DateTime.now()).inMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: isRunning ? 'In progress' : 'Next action',
          actionLabel: 'Full plan',
          onAction: () => context.push(Routes.dayPlan),
        ),
        AppCard(
          accentColor: isRunning ? AppColors.success : AppColors.brand,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppAvatar(name: next.clientName, size: AppSizes.avatarLg),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(next.clientName, style: AppTypography.h3),
                              const SizedBox(height: 2),
                              Text(
                                next.clientSpecialty ?? next.clientType.label,
                                style: AppTypography.bodySm,
                              ),
                            ],
                          ),
                        ),
                        if (!isRunning &&
                            minutesAway > 0 &&
                            minutesAway <= 60)
                          StatusBadge(
                            label: 'In $minutesAway min',
                            tone: StatusTone.warning,
                            dense: true,
                          )
                        else
                          StatusBadge.activity(next.status, dense: true),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _MetaLine(
                      icon: Icons.schedule_outlined,
                      text: next.scheduledEnd == null
                          ? Fmt.time(next.scheduledStart)
                          : Fmt.timeRange(
                              next.scheduledStart, next.scheduledEnd!),
                    ),
                    if (next.locationName != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _MetaLine(
                        icon: Icons.place_outlined,
                        text: '${next.locationName}'
                            '${next.areaName != null ? ', ${next.areaName}' : ''}',
                      ),
                    ],
                    if (next.purpose != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _MetaLine(
                        icon: Icons.flag_outlined,
                        text: next.purpose!.label,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Details',
                        small: true,
                        onPressed: () =>
                            context.push(Routes.activityDetail(next.id)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: isRunning ? 'Complete visit' : 'Start visit',
                        icon: isRunning
                            ? Icons.check_circle_outline
                            : Icons.play_arrow_rounded,
                        small: true,
                        onPressed: () =>
                            context.push(Routes.visitFlow(next.id)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.iconSm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTypography.bodySm)),
      ],
    );
  }
}

/// Entry points to the work a rep starts most often. Four tiles, not twelve —
/// the full module list lives in More.
/// A quick action: where it goes, and which palette family it belongs to.
class _QuickAction {
  const _QuickAction(this.icon, this.label, this.route, this.tone);

  final IconData icon;
  final String label;
  final String route;
  final _ActionTone tone;
}

/// Tints for the action grid.
///
/// Grouped by the kind of work rather than assigned at random, so the colour
/// carries a little meaning: teal for planning and executing the day, sand for
/// client relationships, info for coordination, success for money and movement.
/// All four are existing palette families — no semantic colour is borrowed for
/// decoration.
enum _ActionTone {
  plan(AppColors.brandSoft, AppColors.brand),
  client(AppColors.sandSoft, AppColors.sandDeep),
  coordinate(AppColors.infoSoft, AppColors.info),
  commercial(AppColors.successSoft, AppColors.success);

  const _ActionTone(this.background, this.accent);

  final Color background;
  final Color accent;
}

/// Eight entry points to the work a rep starts most often.
///
/// Two rows of four. This is the fastest route into the modules that used to
/// sit behind the "More" tab, which no longer exists — the side menu holds the
/// full index, and this grid holds the frequent few.
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  static const _actions = [
    _QuickAction(Icons.event_note_outlined, 'My Day Plan', Routes.dayPlan,
        _ActionTone.plan),
    _QuickAction(Icons.timeline_outlined, 'My Activity', Routes.activity,
        _ActionTone.plan),
    _QuickAction(Icons.person_add_alt_outlined, 'Add Client', Routes.newClient,
        _ActionTone.client),
    _QuickAction(Icons.people_outline, 'Clients Data', Routes.clients,
        _ActionTone.client),
    _QuickAction(Icons.chat_bubble_outline, 'Chat', Routes.chat,
        _ActionTone.coordinate),
    _QuickAction(Icons.checklist_outlined, 'To-Do', Routes.tasks,
        _ActionTone.coordinate),
    _QuickAction(Icons.map_outlined, 'Tour Plan', Routes.travel,
        _ActionTone.commercial),
    _QuickAction(Icons.account_balance_wallet_outlined, 'Expenses',
        Routes.expenses, _ActionTone.commercial),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick actions'),
        LayoutBuilder(
          builder: (context, constraints) {
            // Four columns on a phone, eight on a tablet — one row instead of
            // two once there is width for it.
            final columns = constraints.maxWidth >= AppBreakpoints.expanded ? 8 : 4;

            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              // Tall enough for a two-line label plus the accent rule at
              // 320pt, where each tile is only ~63pt wide.
              childAspectRatio: 0.76,
              children: [
                for (final action in _actions)
                  _QuickActionTile(action: action),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(action.route),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: action.tone.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(action.icon, size: 20, color: action.tone.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // The accent rule from the reference — it ties the label back to the
          // icon chip and gives the grid a rhythm without adding more colour.
          Container(
            width: 14,
            height: 2,
            decoration: BoxDecoration(
              color: action.tone.accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestOfDay extends StatelessWidget {
  const _RestOfDay({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final upcoming = summary.activities
        .where((a) => a.status.isOpen)
        .skip(summary.inProgress != null ? 0 : 1)
        .take(3)
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Later today',
          actionLabel: 'See all',
          onAction: () => context.push(Routes.activity),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < upcoming.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: AppSpacing.cardPadding),
                _CompactActivityRow(activity: upcoming[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactActivityRow extends StatelessWidget {
  const _CompactActivityRow({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(Routes.activityDetail(activity.id)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                Fmt.time(activity.scheduledStart),
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.clientName,
                    style: AppTypography.titleSm,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    activity.clientSpecialty ?? activity.clientType.label,
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right,
                size: AppSizes.iconMd, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
