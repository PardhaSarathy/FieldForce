import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../enums/app_enums.dart';
import '../models/activity.dart';
import 'primitives.dart';

/// Append-only approval trail (§62, §69).
///
/// Shows who did what and when, and — crucially — the reason attached to a
/// rejection. An approval record that loses its reason is useless to the person
/// who has to fix and resubmit.
class ApprovalTimeline extends StatelessWidget {
  const ApprovalTimeline({
    super.key,
    required this.events,
    this.emptyMessage = 'Not yet submitted for approval.',
  });

  final List<ApprovalEvent> events;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            const Icon(
              Icons.history_toggle_off,
              size: AppSizes.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(emptyMessage, style: AppTypography.bodySm)),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < events.length; i++)
            _TimelineRow(
              event: events[i],
              isFirst: i == 0,
              isLast: i == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final ApprovalEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tone = event.status.tone;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.foreground, width: 1.2),
                ),
                child: Icon(
                  switch (event.status) {
                    ApprovalStatus.approved => Icons.check,
                    ApprovalStatus.rejected => Icons.close,
                    _ => Icons.arrow_upward,
                  },
                  size: 12,
                  color: tone.foreground,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1.5, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.status.label,
                          style: AppTypography.titleSm.copyWith(
                            color: tone.foreground,
                          ),
                        ),
                      ),
                      Text(
                        Fmt.dateTime(event.at),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.actorName} · ${event.actorRole}',
                    style: AppTypography.caption,
                  ),
                  if (event.reason != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        event.reason!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                  if (event.comment != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(event.comment!, style: AppTypography.bodySm),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
