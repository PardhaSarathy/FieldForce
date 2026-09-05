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
import '../../../core/theme/app_motion.dart';
import '../../../shared/widgets/motion.dart';
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
                            // The day's figures, the modules, and the day
                            // itself — read in that order, so they arrive in
                            // that order.
                            //
                            // There used to be a fourth block between the last
                            // two: a "Next action" card repeating the first
                            // row of the list underneath it, with its own
                            // avatar, badge, two metadata rows and a button
                            // bar. One appointment, a quarter of the screen,
                            // and the same appointment again immediately
                            // below. The list absorbed it — the next call is
                            // the row with the accent and the button on it.
                            Arrive(child: _TodayMetrics(summary: summary)),
                            const SizedBox(height: AppSpacing.lg),
                            Arrive(
                              delay: AppMotion.staggerFor(1),
                              child: const _QuickActionsGrid(),
                            ),
                            const SizedBox(height: AppSpacing.section),
                            Arrive(
                              delay: AppMotion.staggerFor(2),
                              child: _TodaysVisits(summary: summary),
                            ),
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
            // The glyph with the dots in it. A plain empty bubble is the
            // "comment" mark; the one people read as *chat* is the one that
            // has a conversation inside it.
            icon: Icons.textsms_outlined,
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
        customBorder: const CircleBorder(),
        // Circles, not rounded squares. Every other rounded rectangle on this
        // screen is a *card* — something you read. These are controls you
        // press, and the shape is what separates the two vocabularies.
        //
        // No border. A hairline box was right on the old flat ground; against
        // a wash, three outlined squares read as controls stuck on top of the
        // page rather than sitting in it. The soft lift does the same job.
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: AppColors.shadowAmbient,
                blurRadius: 14,
                spreadRadius: -4,
                offset: Offset(0, 6),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
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
                    // The hero figure of the whole app, at the size that
                    // implies. It counts up so the eye lands on it.
                    //
                    // "out of", not "of". Four characters more, and they are
                    // the four a rep would say out loud — the review wrote the
                    // line back as "1 out of 10 visits completed today" twice,
                    // once here and once for the month, which is how people
                    // read a ratio when they are not reading a spreadsheet.
                    //
                    // Scaled down rather than wrapped: at this size a wrap
                    // puts "10" on its own line under "1 out of", which reads
                    // as two figures instead of one.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: CountUp(
                        value: summary.completed.toDouble(),
                        builder: (context, v) => Text(
                          '${v.round()} out of ${summary.planned}',
                          maxLines: 1,
                          style: AppTypography.metric.copyWith(
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'visits completed today',
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
              // The tier, as a word and a colour. The percentage is inside the
              // pill rather than beside it, so the row states the figure once.
              Flexible(child: _TierChip(percent: summary.progress * 100)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _GoalBar(percent: summary.progress * 100),
          const SizedBox(height: AppSpacing.md),

          // The day's state, in one sentence. The dot is paired with words,
          // never colour alone (§73).
          //
          // What it says now comes from the rep's own intimation rather than
          // from the clock: "Day not started" until they file My Day Plan,
          // then the pace — or, on a declared meeting or training day, the
          // work type, because pace against a visit target means nothing on a
          // day with no visits in it. The logic is on [DaySummary]; a widget
          // that decides this would disagree with the day-plan screen the
          // first time either changed.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: StatusDot(
                  color: isRunning
                      ? AppColors.success
                      : summary.isDeclared
                      ? AppColors.brand
                      : AppColors.grey500,
                  size: 7,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  summary.dayStatusLabel(),
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
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (monthTarget == null)
                const Skeleton(width: 92, height: 14)
              else
                Flexible(
                  child: Text(
                    '${monthTarget.visitsAchieved} out of '
                    '${Fmt.count(monthTarget.visitTarget, 'visit')}',
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

  /// The bar takes the tier's ink, so the bar and the chip above it always
  /// agree. This is colour-*coded*, not colour-*alone*: the chip beside it
  /// spells the tier out, and the pace line under it is a full sentence.
  ///
  /// An earlier version changed colour with the pace on its own — amber when
  /// behind — and it read as a warning light rather than as progress, because
  /// nothing named what the amber meant. Naming it is the whole difference.

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0);
    // Brand at every value. Tinting this by tier was tried and reverted twice:
    // amber made the hero element read as a warning light, and slate made it
    // grey for the first half of every day — which is most mornings. The tier
    // is stated in words in the chip above; the bar's job is to show how far
    // along the day is, and it does that in the app's own colour.
    const ink = AppColors.brand;
    final radius = BorderRadius.circular(AppRadius.pill);
    // Light at the start, deep at the leading edge — across whatever has been
    // filled, so the ramp is complete at 5% as well as at 100%. Two deep stops
    // (what this was) makes a flat blue block; the ramp is what turns the fill
    // into distance travelled.
    const ramp = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [AppColors.progressStart, AppColors.brandDark],
    );

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
                AnimatedContainer(
                  duration: AppMotion.slow,
                  curve: AppMotion.curve,
                  width: filled,
                  height: _height,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: ramp,
                    boxShadow: AppGlow.halo(ink, _height * 2.4, strength: 0.7),
                  ),
                ),
              // The light itself: a green core in a white ring, blooming
              // green. It sits half on the deep segment and half on the light
              // track, which is exactly where a glow has something to register
              // against.
              //
              // Green, where it used to be a white core ringed in brand. The
              // bar says *how far*; the knob says *moving*, and that is a
              // different fact, so it gets the one second colour allowed on a
              // control in this app. It stays a knob and never a fill — a
              // green **bar** would read as "done" at 20%, which is the trap
              // here; a green light at the front of a blue one does not.
              //
              // The white ring is load-bearing: the knob crosses from the deep
              // fill onto the light track as the day runs, and green alone
              // would lose its edge against one end or the other.
              AnimatedPositioned(
                duration: AppMotion.slow,
                curve: AppMotion.curve,
                left: knobCentre - _knob / 2,
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.progressKnob,
                    border: Border.all(color: AppColors.surface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.progressKnob.withValues(alpha: 0.55),
                        blurRadius: _knob * 0.55,
                      ),
                      BoxShadow(
                        color: AppColors.progressKnob.withValues(alpha: 0.3),
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

/// The day's standing, as a rung on [GameTier] rather than a bare number.
///
/// "30%" is a measurement; "Getting started · 30%" is a position on a ladder,
/// and the second is what makes a slow morning feel recoverable instead of
/// failed. The word ships with the colour because state is never colour alone.
class _TierChip extends StatelessWidget {
  const _TierChip({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final tier = GameTier.of(percent);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tier.soft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '${tier.label} · ${percent.round()}%',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.badge.copyWith(color: tier.ink),
      ),
    );
  }
}

/// Entry points to the work a rep starts most often. Four tiles, not twelve —
/// the full module list lives in More.
/// A quick action: an icon, a word, where it goes, and the hue it owns.
///
/// The hue came back after a spell where every well was the same green. One
/// colour did make the grid read as a single object — and that was the
/// problem: six identical squares are a list, not six places. With the tile,
/// the chip and the label all carrying one hue, each module becomes somewhere
/// you go, and the six of them still read as a set because the layout, the
/// radius and the light are identical across all of them.
class _QuickAction {
  const _QuickAction(this.icon, this.label, this.route, this.palette);

  final IconData icon;
  final String label;
  final String route;
  final ModulePalette palette;
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
    _QuickAction(
      Icons.calendar_month_outlined,
      'My Day Plan',
      Routes.dayPlan,
      ModulePalette.dayPlan,
    ),
    _QuickAction(
      Icons.show_chart,
      'My Activity',
      Routes.activity,
      ModulePalette.activity,
    ),
    _QuickAction(
      Icons.people_outline,
      'Clients',
      Routes.clients,
      ModulePalette.clients,
    ),
    // "Tour Plan", because that is the screen it opens. It said "Travel" back
    // when it opened a hub with two doors in it; with the hub gone the tile
    // was the last place in the app still calling this something else, and a
    // label that changes on the way through reads as a different screen.
    _QuickAction(
      Icons.map_outlined,
      'Tour Plan',
      Routes.travelPlans,
      ModulePalette.travel,
    ),
    _QuickAction(Icons.person_outline, 'HR', Routes.hr, ModulePalette.hr),
    // Expenses, not Sales. A rep touches this every working day; Sales is a
    // figure they read now and then, and it is still one tap away in the side
    // menu and on the Business dashboard.
    _QuickAction(
      Icons.receipt_long_outlined,
      'Expenses',
      Routes.expenses,
      ModulePalette.expenses,
    ),
  ];
}

class _QuickActionsGridState extends State<_QuickActionsGrid> {
  @override
  Widget build(BuildContext context) {
    const actions = _QuickActionsGrid.actions;

    // No heading. It said "QUICK ACTIONS", which names the *widget* rather
    // than the content — the tell of a screen assembled from patterns instead
    // of written for a rep. Six labelled tiles need no label of their own, and
    // dropping it gives the block back about 30pt, which is most of what made
    // it feel tall.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            final extent =
                _tilePadding * 2 + _iconChip + AppSpacing.sm + labelBlock;

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
              itemBuilder: (context, i) => Arrive.staggered(
                index: i,
                child: _QuickActionTile(action: actions[i], labelLines: lines),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A tile is a white card, a coloured chip and a word in ink.
///
/// The hue is stated **once**, by the chip. An earlier version tinted the card
/// and coloured the label too — three colour statements per tile, eighteen on
/// this screen — and next to the apps this is measured against it read as a
/// paint box rather than a system. Apple and Uber Eats are close to
/// monochrome; all of their colour is in content, and what little sits in the
/// chrome is confined to small marks like these chips.
///
/// One statement is still enough to say *which module*: the chip is 42pt of
/// saturated colour on white, which is the most legible any of it gets.
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
            color: action.palette.ink,
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

/// Today's schedule — the next few calls, not the whole day.
///
/// It has been three different things. It was "Later today": three rows, with
/// the next call skipped because a card above repeated it and the completed
/// ones dropped. Then it was the entire day, every visit, which fixed the
/// disagreement with the count above but turned Home into a page you scroll
/// past to reach the tab bar.
///
/// It is a **window of six anchored on the next call**, which is what a rep
/// actually needs on this screen. The first row is always the one they are
/// about to do; "See all" carries the rest, and that is what a See-all is for.
/// It does not back-fill. It did, to keep the card a constant height — and
/// that was fine while a finished visit carried a tick. With the tick gone at
/// the review's request, a back-filled row is a visit already made sitting
/// above the NEXT mark, indistinguishable from one still to come.
class _TodaysVisits extends StatelessWidget {
  const _TodaysVisits({required this.summary});

  final DaySummary summary;

  /// How many rows Home spends on the day. Six is a card you take in at a
  /// glance; ten is a page.
  static const _window = 6;

  @override
  Widget build(BuildContext context) {
    final all = summary.activities;

    if (all.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: "Today's planned visits"),
          AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.event_note_outlined,
              title: 'Nothing planned yet',
              message: 'Add the calls you are making today and they show up '
                  'here in order.',
              actionLabel: 'Add activity',
              onAction: () => context.push(Routes.addActivity),
            ),
          ),
        ],
      );
    }

    // The one call the rep is either on or about to make. It anchors the
    // window, carries the NEXT mark and holds the button that starts work.
    final next = summary.inProgress ?? summary.nextAction;
    final anchor = next == null
        ? 0
        : all.indexWhere((a) => a.id == next.id).clamp(0, all.length - 1);

    // The window *starts* at the next call. It used to slide back when fewer
    // than six remained, to keep the card a constant height — and that was
    // fine while a finished visit carried a green tick. With the tick gone at
    // the review's request, a backfilled row is a visit already made, sitting
    // above the NEXT mark, looking exactly like one still to come. A shorter
    // card late in the day is the honest answer; "See all" holds the morning.
    final visits = all.skip(anchor).take(_window).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: "Today's planned visits",
          actionLabel: 'See all',
          onAction: () => navigateTo(context, Routes.activity),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < visits.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: AppSpacing.cardPadding),
                _VisitRow(
                  activity: visits[i],
                  isNext: visits[i].id == next?.id,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One call: who, where, and the way in.
///
/// No time on it. It was a "10:00 / AM" pill down the left, and it went at the
/// review's request — the rows are already in the order the day runs, and the
/// hour is on the activity itself one tap away. The names now start at the
/// card's own gutter, which is where every other list in the app starts them.
///
/// The completed ones render exactly like the rest. They carried a green tick
/// for a while, on the argument that a rep should see what is behind them —
/// but the count above already says "4 out of 10", the tick was the only
/// coloured mark in the card, and six of them turned a schedule into a
/// checklist. A tick is a *reward*, and this list is not the place to hand one
/// out.
///
/// One trailing control, and it opens the record. A call button beside it was
/// drawn and cut: two identical squares side by side halve the odds of hitting
/// the right one with a thumb, and the number is one tap away on the client.
///
/// No Start-visit button either. It was here, on the NEXT row, as the one-tap
/// way into a call — and on an in-progress visit its label is "Complete visit",
/// which at this width truncates to "Complete …". A button that cannot say
/// what it does is worse than the extra tap: **Start** and **Complete** both
/// live on the activity detail, one tap away, at full width where the words
/// fit. Home's job here is to show the day, not to run the visit.
class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.activity, required this.isNext});

  final Activity activity;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final isRunning = activity.status == ActivityStatus.inProgress;

    final row = Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Gives way first: the mark beside it is short and
                        // fixed, the name is not.
                        Flexible(
                          child: Text(
                            activity.clientName,
                            style: AppTypography.titleSm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNext) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _NextMark(),
                        ] else if (activity.status == ActivityStatus.missed)
                          ...[
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge.activity(activity.status, dense: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [
                        if (activity.areaName != null) activity.areaName!,
                        activity.clientSpecialty ?? activity.clientType.label,
                      ].join(' · '),
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _RowAction(
                icon: Icons.near_me_outlined,
                tooltip: 'Open visit',
                onTap: () => context.push(Routes.activityDetail(activity.id)),
              ),
            ],
          ),
        ],
      ),
    );

    final tappable = InkWell(
      onTap: () => context.push(Routes.activityDetail(activity.id)),
      child: row,
    );

    if (!isNext) return tappable;

    // The rail is a positioned overlay, never a `Row(stretch)` child — that
    // has no bounded height in a scrolling list and silently collapses the
    // card, and everything after it, in release builds.
    return Stack(
      children: [
        tappable,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 3,
          child: ColoredBox(
            color: isRunning ? AppColors.success : AppColors.brand,
          ),
        ),
      ],
    );
  }
}

/// The mark on the call the rep is about to make.
///
/// Deliberately not a [StatusBadge]: those name a record's *state* — planned,
/// missed, approved — and "next" is not a state, it is a position in a list
/// that changes every time a visit is completed without the record changing at
/// all.
class _NextMark extends StatelessWidget {
  const _NextMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        'NEXT',
        style: AppTypography.badge.copyWith(
          color: AppColors.brand,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// The square control at the end of a row.
///
/// Outlined rather than filled: a filled one competes with the Start button
/// two lines below it, and on a card holding six rows that is six filled
/// controls arguing about which is the action.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: AppSizes.iconSm, color: AppColors.brand),
        ),
      ),
    );
  }
}
