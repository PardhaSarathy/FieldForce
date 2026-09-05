import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/enums/app_enums.dart';
import '../../../../shared/models/activity.dart';
import '../../../../shared/widgets/primitives.dart';

/// The canonical activity row, used by Activity, Client history, Day plan and
/// the team views. One component means a visit looks the same everywhere it
/// appears, which is the difference between a product and a pile of screens.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.showDate = false,
    this.showEmployee = false,
    this.onTap,
  });

  final Activity activity;

  /// Enable when the list spans multiple days (history, reports).
  final bool showDate;

  /// Enable in manager views where rows belong to different people.
  final bool showEmployee;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final needsFlag =
        activity.status == ActivityStatus.completed && !activity.isVerified;

    return AppCard(
      onTap: onTap ?? () => context.push(Routes.activityDetail(activity.id)),
      accentColor: activity.status == ActivityStatus.inProgress
          ? AppColors.success
          : activity.status == ActivityStatus.missed
          ? AppColors.error
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: activity.clientName),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.clientName,
                      style: AppTypography.titleMd,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.clientSpecialty ?? activity.clientType.label,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge.activity(
                activity.status,
                isUnplanned: activity.isUnplanned,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _Meta(
                icon: Icons.schedule_outlined,
                text: showDate
                    ? '${Fmt.dateShort(activity.scheduledStart)} · '
                          '${Fmt.time(activity.scheduledStart)}'
                    : Fmt.time(activity.scheduledStart),
              ),
              if (activity.areaName != null)
                // No pin glyph here: the metadata row already reads as
                // place-and-time, and a second icon competed with the clock
                // without adding meaning.
                Text(activity.areaName!, style: AppTypography.caption),
              if (showEmployee)
                _Meta(icon: Icons.person_outline, text: activity.employeeName),
            ],
          ),
          if (needsFlag || activity.syncStatus == SyncStatus.failed) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (needsFlag)
                  StatusBadge.geo(
                    activity.geoResult?.verification ??
                        GeoVerification.unavailable,
                    dense: true,
                  ),
                if (needsFlag && activity.syncStatus == SyncStatus.failed)
                  const SizedBox(width: AppSpacing.sm),
                if (activity.syncStatus == SyncStatus.failed)
                  StatusBadge.sync(activity.syncStatus, dense: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: AppTypography.caption),
      ],
    );
  }
}
