import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glow.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../enums/app_enums.dart';
import 'motion.dart';

/// The standard content container. A hairline-bordered white card on ivory —
/// no shadows. Elevation in this system is communicated by the border and the
/// background contrast, which stays legible in sunlight on a cheap screen.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.color,
    this.borderColor,
    this.accentColor,
    this.animateColour = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  /// When set, draws a 3px leading rail. Used sparingly to mark a card that
  /// needs attention (overdue, rejected, next action).
  final Color? accentColor;

  /// Cross-fades [color] and [borderColor] when they change.
  ///
  /// Off by default: most cards never change colour, and an implicitly
  /// animated container for every row in a list is work for nothing. On for
  /// cards that *are* a control — a segmented option, a selected day.
  final bool animateColour;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl);

    Widget content = Padding(
      padding: accentColor == null
          ? padding
          : padding.add(const EdgeInsets.only(left: 3)),
      child: child,
    );

    if (accentColor != null) {
      // The rail is painted as a positioned overlay rather than a Row child.
      // A `Row(crossAxisAlignment: stretch)` has no bounded height inside a
      // scrolling list, which silently collapses the card — and, in release
      // builds, the rest of the list with it.
      content = Stack(
        children: [
          content,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: accentColor!),
          ),
        ],
      );
    }

    // `shape` carries the radius *and* the hairline border, so `borderRadius`
    // must not also be set — Material asserts against having both, and the
    // assert is compiled out in release, which hides the mistake.
    //
    // Shadow *and* border, not one or the other. The shadow is what gives the
    // card depth indoors; outdoors glare flattens it completely, and a card
    // whose only edge was a shadow loses its edge. The border is faint enough
    // to disappear behind the shadow in normal light and still hold the edge
    // in sun.
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: AppColors.shadowAmbient,
            blurRadius: 30,
            spreadRadius: -8,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: animateColour ? Colors.transparent : (color ?? AppColors.surface),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: animateColour
                ? Colors.transparent
                : (borderColor ?? AppColors.border),
          ),
        ),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: radius,
                splashColor: AppColors.brandSoft.withValues(alpha: 0.6),
                highlightColor: AppColors.brandSoft.withValues(alpha: 0.35),
                child: content,
              ),
      ),
    );

    final skinned = !animateColour
        ? card
        : AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            decoration: BoxDecoration(
              color: color ?? AppColors.surface,
              borderRadius: radius,
              border: Border.all(color: borderColor ?? AppColors.border),
            ),
            child: card,
          );

    // A splash says the tap registered; the scale says the thing under the
    // finger is an object. Only for cards that actually do something.
    return onTap == null ? skinned : Pressable(onTap: onTap, child: skinned);
  }
}

/// An uppercase eyebrow label with an optional trailing action, used to open
/// a group of related content.
///
/// A short brand-blue rule sits in front of the label. It is doing a real job
/// rather than decorating: the eyebrow is small, grey and uppercase, which is
/// exactly the treatment the eye skips, and on a white page with no rules
/// anywhere else a section could start without anything marking that it had.
/// The tick is the cheapest possible "a new group begins here".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.accentColor,
    this.padding = const EdgeInsets.only(
      left: AppSpacing.xs,
      right: AppSpacing.xs,
      bottom: AppSpacing.md,
    ),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  /// Overrides the tick's colour. Defaults to the brand, which is right almost
  /// everywhere; a section that belongs to one module can take that hue.
  final Color? accentColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              color: accentColor ?? AppColors.brand,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Expanded(
            child: Text(title.toUpperCase(), style: AppTypography.overline),
          ),
          if (trailing != null)
            trailing!
          else if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  actionLabel!,
                  style: AppTypography.titleSm.copyWith(color: AppColors.brand),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Status pill. Always renders text alongside color so state is never conveyed
/// by hue alone (§73).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
  });

  StatusBadge.approval(ApprovalStatus status, {super.key, this.dense = false})
    : label = status.label,
      tone = status.tone,
      icon = null;

  /// The badge on an activity: its **origin** while the call is still ahead,
  /// its **outcome** once it has happened.
  ///
  /// Before the call, "did I plan this?" is the useful fact. "Upcoming" is
  /// not — every open call is upcoming, so the word separated nothing from
  /// anything, and it read as a second name for Planned. The status still
  /// exists underneath (it is how the day's *next* call is found), it just
  /// has nothing to say on a badge. Afterwards the question changes to
  /// whether it happened, and the outcome answers it.
  ///
  /// In Progress is the exception and keeps its own word: a call being made
  /// right now is neither an origin nor an outcome.
  ///
  /// One badge either way. A card carrying both squeezes the pair until one
  /// ellipsises, which is what a client row already taught this app.
  StatusBadge.activity(
    ActivityStatus status, {
    super.key,
    bool isUnplanned = false,
    this.dense = false,
  }) : label = status.isOpen && status != ActivityStatus.inProgress
           ? (isUnplanned ? 'Unplanned' : 'Planned')
           : status.label,
       tone = status.tone,
       icon = null;

  StatusBadge.sync(SyncStatus status, {super.key, this.dense = false})
    : label = status.label,
      tone = status.tone,
      icon = switch (status) {
        SyncStatus.synced => Icons.cloud_done_outlined,
        SyncStatus.syncing => Icons.sync,
        SyncStatus.failed => Icons.cloud_off_outlined,
        SyncStatus.pending => Icons.schedule_outlined,
        SyncStatus.savedLocally => Icons.save_outlined,
      };

  StatusBadge.geo(GeoVerification status, {super.key, this.dense = false})
    : label = status.label,
      tone = status.tone,
      icon = switch (status) {
        GeoVerification.verified => Icons.verified_outlined,
        GeoVerification.outOfRange => Icons.location_off_outlined,
        GeoVerification.unavailable => Icons.location_disabled_outlined,
        GeoVerification.suspect => Icons.gpp_maybe_outlined,
      };

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone.foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          // A badge sits inside constrained rows all over the app; at a large
          // text size its label has to give way rather than push the row wide.
          Flexible(
            child: Text(
              label,
              style: AppTypography.badge.copyWith(color: tone.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small colored dot used in calendars and dense rows where a full badge would
/// not fit. Must always be paired with a legend or adjacent text.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Avatar with initials fallback. Photos are optional throughout the app, so
/// the fallback is the common path and must look deliberate.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = AppSizes.avatarMd,
    this.backgroundColor,
    this.showOnlineDot = false,
    this.isOnline = false,
    this.heroTag,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final bool showOnlineDot;
  final bool isOnline;

  /// Flies between screens when set on both ends.
  ///
  /// Used for a client's avatar going from the list into their detail: the
  /// same object continuing rather than one screen replacing another. Needs a
  /// tag unique on the page — a record id — or Flutter has two heroes with one
  /// tag and throws.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    // The hue is derived from the name, so a person keeps the same one
    // everywhere in the app and a list of them is a spread of colour rather
    // than a column of identical mint discs.
    //
    // This is what earns the "photography" of a consumer app without faking
    // photographs a pharma company does not have: it is real information —
    // two clients with different names are visibly different at a glance —
    // rather than decoration.
    final module = backgroundColor != null
        ? null
        : ModulePalette.values[name.hashCode.abs() % ModulePalette.values.length];

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? module!.tile,
        shape: BoxShape.circle,
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl != null
          ? null
          : Text(
              Fmt.initials(name),
              style: AppTypography.titleSm.copyWith(
                // The module's ink on the module's tile — a pairing already
                // measured at 4.5:1 or better for all six.
                color: module?.ink ?? AppColors.brandDark,
                fontSize: size * 0.36,
              ),
            ),
    );

    if (!showOnlineDot) {
      return heroTag == null
          ? avatar
          : Hero(tag: heroTag!, child: avatar);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: StatusDot(
              color: isOnline ? AppColors.success : AppColors.textSecondary,
              size: size * 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal progress track. Defaults to brand; pass [color] to signal a
/// state (e.g. behind plan).
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
    this.backgroundColor,
  });

  /// 0.0 – 1.0. Values above 1 are clamped for the bar but callers should still
  /// display the true percentage in text (over-achievement is good news).
  final double value;
  final Color? color;
  final double height;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      // Fills to its value rather than being painted at it. Used on every
      // target and team row in the app, so this one line animates all of
      // them — and a bar that grows is the clearest possible way to say the
      // figure beside it is a proportion of something.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: backgroundColor ?? AppColors.surfaceSecondary,
          valueColor: AlwaysStoppedAnimation(color ?? AppColors.brand),
        ),
      ),
    );
  }
}

/// Label/value pair for detail screens. The workhorse of every "Detail" view
/// in the app — keeps alignment and type consistent across 40+ screens.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.labelWidth = 132,
    this.dense = false,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final double labelWidth;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: dense ? AppSpacing.xs : AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: AppTypography.bodySm),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                valueWidget ??
                Text(
                  value?.isNotEmpty == true ? value! : '—',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: value?.isNotEmpty == true
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Thin separator matching the card border weight.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.height = AppSpacing.lg, this.indent = 0});

  final double height;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(height: height, indent: indent, endIndent: 0);
  }
}

/// A lit square with an icon in it. The app's module anchor.
///
/// Three layers, each doing something the others cannot:
///
/// * the **well** — a deep teal gradient, lightest at the top-left where the
///   light falls, deepest at the bottom-right;
/// * the **glyph** in [AppColors.wellGlyph], bright enough to look like it is
///   giving light off rather than sitting on the well;
/// * the **bloom**, in two stops: a tight saturated aura hugging the strokes,
///   which is what the eye actually reads as emission, and a wider faint
///   falloff behind it so the tight one does not read as an outline. Both
///   scale with the glyph — a fixed radius turns a small icon to fog.
///
/// Under it all, a mint halo rather than a black one. A coloured shadow is
/// the difference between *raised* and *lit*.
///
/// Pass [color] and the whole well re-tints from that ink — a deep amber well
/// with a pale amber glyph — so a warning row is still a warning. Every tint
/// clears 4.5:1 at the light end of its own gradient; see
/// [AppColors.wellTop] for why the well is dark in the first place.
///
/// Pass [background] and you get the old flat pale chip instead, with the ink
/// drawn plainly on it. That is for the few places where the chip is a *state*
/// and must go quiet — a notification already read.
class IconWell extends StatelessWidget {
  const IconWell({
    super.key,
    required this.icon,
    required this.size,
    this.color,
    this.background,
    this.radius,
    this.glyphSize,
  });

  final IconData icon;
  final double size;

  /// The ink the well is built from. Defaults to the brand.
  final Color? color;

  /// A flat pale chip instead of a lit well. Opts out of the glow entirely.
  final Color? background;

  /// Corner radius. Defaults to **a circle**.
  ///
  /// It was `AppRadius.md`, and Home's tiles overrode it to a disc on their
  /// own — which left one screen saying a module mark is round and
  /// twenty-six others saying it is a rounded square. Same object, two
  /// shapes, and the odd one out was the screen the app is judged on.
  ///
  /// The cost is that a circle already means *a person* here: [AppAvatar] is
  /// a disc with initials in it. They coexist because they never carry the
  /// same content — an avatar holds letters, a well holds a glyph — and
  /// because a client row shows one of each, side by side, where the
  /// difference is obvious. Keep it that way: do not put a letter in a well.
  final double? radius;

  /// Defaults to half the well, which is the proportion the app uses
  /// everywhere.
  final double? glyphSize;

  @override
  Widget build(BuildContext context) {
    final glyph = glyphSize ?? size * 0.5;
    final ink = color ?? AppColors.brand;
    final corner = radius ?? size / 2;

    if (background != null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(corner),
        ),
        child: Icon(icon, size: glyph, color: ink),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(corner),
        gradient: AppGlow.fill(ink),
        boxShadow: AppGlow.halo(ink, size),
      ),
      child: Icon(
        icon,
        size: glyph,
        color: AppGlow.glyphOn(ink),
        shadows: AppGlow.bloom(ink, glyph),
      ),
    );
  }
}

/// A target's rung on the [GameTier] ladder, with its percentage inside.
///
/// Deliberately not a [StatusBadge]. The tones there mean *states* — approved,
/// rejected, pending — and a target that is merely half done is not a warning;
/// it is a position, and it earns its own vocabulary. Using the state palette
/// for it is what used to paint a rep at 40% in error red.
///
/// The label ships with the colour, so this never says anything by hue alone.
class TierBadge extends StatelessWidget {
  const TierBadge({
    super.key,
    required this.tier,
    required this.percent,
    this.dense = true,
  });

  final GameTier tier;
  final double percent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 3 : 5,
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

/// Left-aligned icon in a lit square. Used in list rows and module grids to
/// give scannable anchors without resorting to colorful illustrations.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 38,
  });

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconWell(
      icon: icon,
      size: size,
      color: color,
      background: background,
    );
  }
}
