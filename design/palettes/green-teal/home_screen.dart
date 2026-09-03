import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/navigate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_glow.dart';
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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Pinned. The bar carries the menu, notifications and profile —
            // controls you may want at any scroll position — so it sits above
            // the scroll view rather than inside it. A Column, not a floating
            // overlay: content scrolls *below* the bar, never under it, so the
            // bar needs no opaque fill and the ground's wash stays unbroken.
            _HomeTopBar(unreadCount: unread),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(todaySummaryProvider),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HomeGreeting(
                        name: employee.name.split(' ').first,
                        territory: employee.headquarters,
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
                            const SizedBox(height: AppSpacing.lg),
                            const _QuickActionsGrid(),
                            const SizedBox(height: AppSpacing.section),
                            _NextActionSection(summary: summary),
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
          ],
        ),
      ),
    );
  }
}

/// The pinned bar: menu, brand, notifications, profile.
///
/// Split out of the old header so it can stay put while the page scrolls —
/// these are the controls a rep may want at any position, and the brand mark
/// is what tells them which app they are in.
class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
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
                // Flexible so the wordmark gives way on a 320pt phone rather
                // than pushing the action buttons off-screen.
                Flexible(
                  child: Text(
                    'Mr Sales',
                    style: AppTypography.titleMd.copyWith(letterSpacing: -0.2),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
          // Two things a rep checks rather than navigates to. Profile moved to
          // the side menu, where tapping your own photo opens it — the place
          // people look for it.
          _HeaderIconButton(
            icon: Icons.chat_bubble_outline,
            onTap: () => navigateTo(context, Routes.chat),
            tooltip: 'Chat',
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
    );
  }
}

/// The greeting, which scrolls away. It is a welcome, not a control — there is
/// no reason to spend pinned height on it.
class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({required this.name, required this.territory});

  final String name;
  final String territory;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.md,
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
        ],
      ),
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
        // No border. A hairline box was right on the old flat ground; against
        // a wash, three outlined squares read as controls stuck on top of the
        // page rather than sitting in it. The soft lift does the same job.
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 2, offset: Offset(0, 1)),
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                spreadRadius: -6,
                offset: Offset(0, 5),
              ),
            ],
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

/// How today is going — progress, pace and the month behind it, in one card.
///
/// This used to be two cards that answered the same question twice: a goal
/// card saying "7 of 10 visits done today" and, directly beneath it, a status
/// strip saying "1 visit behind schedule". Both are the same fact — how far
/// through the day's work you are — so they belong in one place, where the
/// pace can sit against the count it is derived from instead of contradicting
/// it a card later.
///
/// The month figure stays, but subordinated below a rule: it is context, not
/// today's job (§78 — Home is not an analytics dashboard).
class _TodayMetrics extends ConsumerWidget {
  const _TodayMetrics({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthTarget = ref.watch(monthlyVisitTargetProvider).valueOrNull;
    final isRunning = summary.inProgress != null;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The count and the percentage sit on one line, above the bar they
          // both describe — the percentage reads as the bar's value rather
          // than as a second figure competing with the count.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.completed} of ${summary.planned}',
                      style: AppTypography.metricSm.copyWith(
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'visits done today',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${(summary.progress * 100).round()}% done',
                style: AppTypography.titleSm.copyWith(color: _GoalBar.ink),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _GoalBar(percent: summary.progress * 100),
          const SizedBox(height: AppSpacing.md),

          // Pace, with the work type it applies to. The dot is paired with
          // words, never colour alone (§73).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: StatusDot(
                  color: isRunning ? AppColors.success : AppColors.brand,
                  size: 7,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isRunning ? 'Visit in progress' : summary.paceLabel(),
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),

          // Always rendered, with a skeleton while the figure loads. The month
          // target resolves after the day summary it is chained behind, so
          // building this row only once it arrives made the card grow under
          // the reader a second after the screen settled.
          const AppDivider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'This month',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (monthTarget == null)
                const Skeleton(width: 92, height: 14)
              else
                Flexible(
                  child: Text(
                    '${monthTarget.visitsAchieved} of '
                    '${monthTarget.visitTarget} visits',
                    style: AppTypography.titleSm,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The day's progress, as a lit bar.
///
/// It was a ring, with the percentage inside it. A ring spends an 84pt square
/// to say one number and pushes everything else into the narrow column beside
/// it — which is what forced the count, the caption and the pace line to share
/// half the card's width. Laid flat, the same fact takes 12pt of height, the
/// text above it gets the full width, and the bar has somewhere to glow.
///
/// The ink still carries the pace: amber behind, brand on the way, green done.
/// [AppGlow] re-tints from that ink, so an amber bar glows amber — the light
/// says the same thing the colour does.
class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.percent});

  final double percent;

  /// The channel the segment runs in.
  static const _height = 14.0;

  /// The knob of light at the leading edge. Larger than the channel on
  /// purpose: it stands proud of the bar rather than sitting inside it, which
  /// is what makes it read as a light *at* the position reached rather than
  /// as the end of a fill.
  static const _knob = 20.0;

  /// One green, at every value.
  ///
  /// The bar used to change colour with the pace — amber behind, brand on the
  /// way, green done — and it was the only orange thing on a green screen: at
  /// 20% it read as a warning light rather than as progress. The pace is not
  /// lost by dropping it, because this app never says a state in colour alone
  /// (§73): "1 visit behind schedule" is written in words directly under the
  /// bar, which is where it was always actually being read.
  static const ink = AppColors.brand;

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(AppRadius.pill);

    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth;
        // A 1% day is still a day something happened on. Below one bar-height
        // the fill stops being a pill and becomes a sliver that reads as a
        // rendering artefact, so it floors there.
        final filled = value == 0 ? 0.0 : (full * value).clamp(_height, full);

        // The knob centres on the segment's end and is kept whole at both
        // extremes — half of it hanging off the track at 0% or 100% would
        // read as a rendering fault, not as a design.
        final knobCentre = filled.clamp(_knob / 2, full - _knob / 2);

        return SizedBox(
          // Sized to the knob, not the channel: the knob stands proud, and a
          // box sized to the bar would clip its glow top and bottom.
          height: _knob,
          width: full,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // The track stays light. A dark channel was tried and it made
              // the card heavy — the bar has to sit *in* a white card, not
              // become the loudest object on the screen.
              Container(
                height: _height,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: radius,
                ),
              ),
              if (filled > 0)
                Container(
                  width: filled,
                  height: _height,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: AppGlow.fill(
                      ink,
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    boxShadow: AppGlow.halo(ink, _height * 2.4, strength: 0.7),
                  ),
                ),
              // The light itself: a white core ringed in brand, blooming mint.
              // It sits half on the deep segment and half on the light track,
              // which is exactly where a glow has something to register
              // against.
              Positioned(
                left: knobCentre - _knob / 2,
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.brandLight, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.iconGlow,
                        blurRadius: _knob * 0.55,
                      ),
                      BoxShadow(
                        color: AppColors.wellHalo,
                        blurRadius: _knob * 1.3,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        // No action beside this header: the card below it is the one thing
        // the screen is for, and "Later today" already offers the full list.
        SectionHeader(title: isRunning ? 'In progress' : 'Next action'),

        // One padded block, not three. The card used to stack a header, three
        // icon rows and a divided button bar — a quarter of the screen for one
        // appointment. What it needs to say is: who, when, where, and the one
        // button that starts the work.
        AppCard(
          accentColor: isRunning ? AppColors.success : AppColors.brand,
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(name: next.clientName, size: AppSizes.avatarMd),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Two lines. This is the card's subject, and a
                        // client's name cut mid-word reads as a bug. The
                        // address below gives the line back by capping at
                        // one, so the card's height is unchanged.
                        Text(
                          next.clientName,
                          style: AppTypography.titleMd,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        // Specialty and purpose are both "what kind of meeting
                        // is this", so they share a line instead of costing a
                        // metadata row each.
                        Text(
                          [
                            next.clientSpecialty ?? next.clientType.label,
                            if (next.purpose != null) next.purpose!.label,
                          ].join(' · '),
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (!isRunning && minutesAway > 0 && minutesAway <= 60)
                    StatusBadge(
                      label: 'In $minutesAway min',
                      tone: StatusTone.warning,
                      dense: true,
                    )
                  else
                    StatusBadge.activity(next.status, dense: true),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              _MetaLine(
                icon: Icons.schedule_outlined,
                text: next.scheduledEnd == null
                    ? Fmt.time(next.scheduledStart)
                    : Fmt.timeRange(next.scheduledStart, next.scheduledEnd!),
              ),
              if (next.locationName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _MetaLine(
                  icon: Icons.place_outlined,
                  maxLines: 1,
                  text: '${next.locationName}'
                      '${next.areaName != null ? ', ${next.areaName}' : ''}',
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Row(
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
                      onPressed: () => context.push(Routes.visitFlow(next.id)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text, this.maxLines});

  final IconData icon;
  final String text;

  /// Unbounded by default. A full street address wrapping to three lines is
  /// the right call on a detail screen and the wrong one on a summary card.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.iconSm, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySm,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Entry points to the work a rep starts most often. Four tiles, not twelve —
/// the full module list lives in More.
/// A quick action: an icon, a word, and where it goes.
///
/// It used to carry a palette family as well, which tinted the chip one of
/// four ways. Six modules do not need four colours to be told apart — the icon
/// and the word already do that — and four washes in one grid pulled against
/// the single brand green the rest of the app is built from. Every well is now
/// the same lit green, and the grid reads as one object instead of four pairs.
class _QuickAction {
  const _QuickAction(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

/// Lines a quick-action label may wrap to at the reader's text size.
///
/// One at a normal size. All six labels fit a single line in a third of the
/// screen — "My Day Plan" is the longest and still clears it on a 320pt
/// phone — so the second line the tile used to reserve was empty space that
/// made every tile a square. Above ~1.15x the words do start needing a line
/// each, and the second is reserved only then.
///
/// The tile height and the label's `maxLines` both come from this, so they
/// cannot drift apart: a taller tile with a one-line cap still truncates, and
/// a two-line label in a one-line tile clips.
int _quickActionLabelLines(TextScaler scale) =>
    scale.scale(_labelFontSize) > _labelFontSize * 1.15 ? 2 : 1;

const _labelFontSize = 12.0;

/// The style the tile labels are painted in.
final _quickActionLabelStyle = AppTypography.caption.copyWith(
  color: AppColors.textPrimary,
  fontWeight: FontWeight.w600,
  height: 1.2,
);

/// Three columns on a phone, six on a tablet — one row instead of two once
/// there is width for it. Six tiles fill both cases completely, where four
/// columns would leave a ragged row of two.
///
/// Deliberately not derived from measuring the labels: text metrics differ
/// between the test font and the real one by roughly a factor of two, so a
/// measured column count would lay out differently under test than on a
/// device — which is worse than a fixed count. The height below is what
/// adapts to text size, and a long word on a 320pt phone at 1.3x still
/// ellipsizes rather than overflowing.
int _quickActionColumns(double width) =>
    width >= AppBreakpoints.expanded ? 6 : 3;

class _QuickActionsGrid extends StatefulWidget {
  const _QuickActionsGrid();

  @override
  State<_QuickActionsGrid> createState() => _QuickActionsGridState();

  /// Exposed so [_quickActionColumns] can measure the very labels that will
  /// be painted, rather than a copy that could drift out of step.
  /// Six tiles — the modules a rep opens daily, in the order the day runs:
  /// declare it, log it, who and where, then the admin behind it. To-Do moved
  /// to the bottom bar, and Expenses lives behind Travel where the claim
  /// actually follows the journey.
  static const actions = [
    _QuickAction(Icons.note_add_outlined, 'My Day Plan', Routes.dayPlan),
    _QuickAction(Icons.timeline_outlined, 'My Activity', Routes.activity),
    _QuickAction(Icons.people_outline, 'Clients', Routes.clients),
    _QuickAction(Icons.map_outlined, 'Travel', Routes.travel),
    _QuickAction(Icons.badge_outlined, 'HR', Routes.hr),
    _QuickAction(Icons.trending_up_outlined, 'Sales', Routes.sales),
  ];
}

class _QuickActionsGridState extends State<_QuickActionsGrid> {
  @override
  Widget build(BuildContext context) {
    const actions = _QuickActionsGrid.actions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick actions'),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context);
            final columns = _quickActionColumns(constraints.maxWidth);

            // Fixed height, not an aspect ratio. With childAspectRatio the
            // tile height follows the device width, so on a narrow phone the
            // tile shrank below what the label needed and the second line was
            // clipped mid-glyph. This derives the height from the content and
            // the user's text scale instead, so it is correct on every device.
            final lines = _quickActionLabelLines(scale);
            final labelBlock = scale.scale(_labelFontSize) * 1.25 * lines;
            final extent = _tilePadding * 2 +
                _iconChip +
                AppSpacing.sm +
                labelBlock;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                mainAxisExtent: extent,
              ),
              itemBuilder: (context, i) =>
                  _QuickActionTile(action: actions[i], labelLines: lines),
            );
          },
        ),
      ],
    );
  }
}

/// A tile is a chip and a word. The accent rule that used to sit under the
/// label is gone: it repeated what the chip's tint already says, and it was
/// the third element competing for attention in a 60pt-wide box.
const _iconChip = 42.0;
const _tileGlyph = 21.0;
const _tilePadding = AppSpacing.md;

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.labelLines});

  final _QuickAction action;
  final int labelLines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => navigateTo(context, action.route),
      padding: const EdgeInsets.symmetric(
        vertical: _tilePadding,
        horizontal: AppSpacing.xs,
      ),
      child: Column(
        // Top-aligned, not centred. The tile is sized for the longest label,
        // so centring left every one-line tile's icon sitting lower than its
        // two-line neighbour's — the row read as misaligned even though every
        // tile was the same height.
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          IconWell(
            icon: action.icon,
            size: _iconChip,
            glyphSize: _tileGlyph,
            radius: AppRadius.lg,
          ),
          const SizedBox(height: AppSpacing.sm),
          // The label takes the rest of the tile and centres in it. The chips
          // stay aligned across the row because the column is top-aligned,
          // while a one-word label sits in the middle of the space a two-line
          // one needs, instead of hanging from the top with a gap beneath it.
          Expanded(
            child: Center(
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: labelLines,
                overflow: TextOverflow.ellipsis,
                style: _quickActionLabelStyle,
              ),
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
          onAction: () => navigateTo(context, Routes.activity),
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
