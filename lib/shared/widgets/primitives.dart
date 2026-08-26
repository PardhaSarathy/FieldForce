import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../enums/app_enums.dart';

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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  /// When set, draws a 3px leading rail. Used sparingly to mark a card that
  /// needs attention (overdue, rejected, next action).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);

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
    return Material(
      color: color ?? AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? AppColors.border),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: radius,
              splashColor: AppColors.brandSoft.withValues(alpha: 0.5),
              highlightColor: AppColors.brandSoft.withValues(alpha: 0.3),
              child: content,
            ),
    );
  }
}

/// An uppercase eyebrow label with an optional trailing action, used to open
/// a group of related content.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
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
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
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

  StatusBadge.activity(ActivityStatus status, {super.key, this.dense = false})
      : label = status.label,
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
          Text(
            label,
            style: AppTypography.badge.copyWith(color: tone.foreground),
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
  });

  final String name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final bool showOnlineDot;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.brandSoft,
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
                color: AppColors.brandDark,
                fontSize: size * 0.36,
              ),
            ),
    );

    if (!showOnlineDot) return avatar;

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
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: backgroundColor ?? AppColors.surfaceSecondary,
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.brand),
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
      padding: EdgeInsets.symmetric(vertical: dense ? AppSpacing.xs : AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: AppTypography.bodySm),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: valueWidget ??
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

/// Left-aligned icon in a soft tinted square. Used in list rows and module
/// grids to give scannable anchors without resorting to colorful illustrations.
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
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? AppColors.brand),
    );
  }
}
