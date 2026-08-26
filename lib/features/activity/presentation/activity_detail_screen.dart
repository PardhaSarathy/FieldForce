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

final _activityProvider =
    FutureProvider.autoDispose.family<Activity, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(activityRepositoryProvider).byId(id);
});

/// Full record of one activity (§17). Everything captured during the visit,
/// plus its location evidence and sync state.
class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_activityProvider(activityId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Activity Detail'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing will be enabled with the backend.')),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => ErrorState(
          onRetry: () => ref.invalidate(_activityProvider(activityId)),
        ),
        data: (activity) => _Body(activity: activity),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (activity) => activity.status.isOpen
            ? BottomActionBar(
                children: [
                  SecondaryButton(
                    label: 'Navigate',
                    icon: Icons.directions_outlined,
                    onPressed: () {},
                  ),
                  PrimaryButton(
                    label: activity.status == ActivityStatus.inProgress
                        ? 'Continue visit'
                        : 'Start visit',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => context.push(Routes.visitFlow(activity.id)),
                  ),
                ],
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final geo = activity.geoResult;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        // Header
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(name: activity.clientName, size: AppSizes.avatarLg),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity.clientName, style: AppTypography.h3),
                        const SizedBox(height: 2),
                        Text(
                          activity.clientSpecialty ?? activity.clientType.label,
                          style: AppTypography.bodySm,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.activity(activity.status, dense: true),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  StatusBadge.sync(activity.syncStatus, dense: true),
                  if (geo != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge.geo(geo.verification, dense: true),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        _Section(
          title: 'Visit',
          children: [
            KeyValueRow(label: 'Date', value: Fmt.date(activity.scheduledStart)),
            KeyValueRow(
              label: 'Scheduled',
              value: activity.scheduledEnd == null
                  ? Fmt.time(activity.scheduledStart)
                  : Fmt.timeRange(activity.scheduledStart, activity.scheduledEnd!),
            ),
            if (activity.actualStart != null)
              KeyValueRow(
                label: 'Actual',
                value: activity.actualEnd == null
                    ? Fmt.time(activity.actualStart!)
                    : Fmt.timeRange(activity.actualStart!, activity.actualEnd!),
              ),
            if (activity.duration != null)
              KeyValueRow(
                  label: 'Duration', value: Fmt.duration(activity.duration!)),
            KeyValueRow(label: 'Work type', value: activity.workType.label),
            KeyValueRow(label: 'Purpose', value: activity.purpose?.label),
            KeyValueRow(label: 'Client type', value: activity.clientType.label),
            KeyValueRow(label: 'Area', value: activity.areaName),
          ],
        ),

        _Section(
          title: 'Contact',
          children: [
            KeyValueRow(label: 'Contact person', value: activity.contactPerson),
            KeyValueRow(label: 'Mobile', value: activity.contactMobile),
          ],
        ),

        if (activity.status == ActivityStatus.completed)
          _Section(
            title: 'Call report',
            children: [
              KeyValueRow(
                label: 'RCPA score',
                valueWidget: activity.rcpaScore == null
                    ? null
                    : Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              i <= activity.rcpaScore!
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 18,
                              color: i <= activity.rcpaScore!
                                  ? AppColors.sand
                                  : AppColors.border,
                            ),
                        ],
                      ),
                value: activity.rcpaScore == null ? null : '',
              ),
              KeyValueRow(label: 'Feedback', value: activity.feedback),
              KeyValueRow(label: 'POP shared', value: activity.pop),
              KeyValueRow(label: 'Remarks', value: activity.remarks),
              KeyValueRow(
                label: 'Next visit',
                value: activity.expectedNextVisit == null
                    ? null
                    : Fmt.date(activity.expectedNextVisit!),
              ),
            ],
          ),

        if (activity.rcpaEntries.isNotEmpty) ...[
          const SectionHeader(title: 'RCPA'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < activity.rcpaEntries.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _RcpaRow(entry: activity.rcpaEntries[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],

        if (geo != null)
          _Section(
            title: 'Location verification',
            children: [
              KeyValueRow(
                label: 'Result',
                valueWidget: StatusBadge.geo(geo.verification, dense: true),
              ),
              KeyValueRow(label: 'Distance', value: geo.distanceLabel),
              KeyValueRow(
                  label: 'Fence radius', value: '${geo.radiusMeters.round()} m'),
              if (geo.captured != null)
                KeyValueRow(label: 'Captured at', value: geo.captured.toString()),
              if (geo.capturedAt != null)
                KeyValueRow(label: 'Timestamp', value: Fmt.dateTime(geo.capturedAt!)),
              if (activity.outOfRangeReason != null)
                KeyValueRow(label: 'Reason given', value: activity.outOfRangeReason),
            ],
          ),

        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, padding: const EdgeInsets.only(
          left: AppSpacing.xs, right: AppSpacing.xs,
          top: AppSpacing.md, bottom: AppSpacing.md,
        )),
        AppCard(child: Column(children: children)),
      ],
    );
  }
}

class _RcpaRow extends StatelessWidget {
  const _RcpaRow({required this.entry});

  final RcpaEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.productName, style: AppTypography.titleSm),
              ),
              Text('${entry.sharePercent.round()}% share',
                  style: AppTypography.numeric.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(value: entry.sharePercent / 100, height: 5),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('Ours: ${entry.ownQuantity}', style: AppTypography.caption),
              const SizedBox(width: AppSpacing.lg),
              Text(
                '${entry.competitorName ?? 'Competitor'}: ${entry.competitorQuantity}',
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
