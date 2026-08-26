import 'package:flutter/material.dart';

import '../../../../core/location/geo_math.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/enums/app_enums.dart';
import '../../../../shared/widgets/buttons.dart';
import '../../../../shared/widgets/primitives.dart';

/// Shows the geo-fence outcome with its evidence (§9).
///
/// The distance is always visible, verified or not. A rep who is told only
/// "not verified" cannot act; one told "84 m from client — move within 50 m"
/// knows exactly what to do.
class GeoVerificationPanel extends StatelessWidget {
  const GeoVerificationPanel({
    super.key,
    required this.result,
    required this.isCapturing,
    required this.clientName,
    this.registeredAddress,
    this.errorMessage,
    this.onRetry,
    this.onOpenSettings,
  });

  final GeoFenceResult? result;
  final bool isCapturing;
  final String clientName;
  final String? registeredAddress;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (isCapturing) return const _CapturingCard();

    final data = result;
    if (data == null) {
      return AppCard(
        child: Column(
          children: [
            Text('Location not captured yet', style: AppTypography.titleSm),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Capture location',
              icon: Icons.my_location,
              small: true,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }

    final tone = data.verification.tone;

    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: tone.foreground.withValues(alpha: 0.3),
      child: Column(
        children: [
          // Verdict banner
          Container(
            width: double.infinity,
            color: tone.background,
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Icon(
                  switch (data.verification) {
                    GeoVerification.verified => Icons.verified_outlined,
                    GeoVerification.outOfRange => Icons.location_off_outlined,
                    GeoVerification.unavailable =>
                      Icons.location_disabled_outlined,
                    GeoVerification.suspect => Icons.gpp_maybe_outlined,
                  },
                  size: 22,
                  color: tone.foreground,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.verification.label,
                        style: AppTypography.titleMd
                            .copyWith(color: tone.foreground),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        errorMessage ?? data.message,
                        style: AppTypography.caption
                            .copyWith(color: tone.foreground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              children: [
                if (data.distanceMeters != null) ...[
                  _DistanceGauge(
                    distanceMeters: data.distanceMeters!,
                    radiusMeters: data.radiusMeters,
                    tone: tone,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                KeyValueRow(
                  label: 'Client',
                  value: clientName,
                  labelWidth: 110,
                  dense: true,
                ),
                if (registeredAddress?.isNotEmpty == true)
                  KeyValueRow(
                    label: 'Registered at',
                    value: registeredAddress,
                    labelWidth: 110,
                    dense: true,
                  ),
                if (data.captured != null)
                  KeyValueRow(
                    label: 'Your position',
                    value: data.captured.toString(),
                    labelWidth: 110,
                    dense: true,
                  ),
                if (data.capturedAt != null)
                  KeyValueRow(
                    label: 'Captured at',
                    value: Fmt.time(data.capturedAt!),
                    labelWidth: 110,
                    dense: true,
                  ),
                KeyValueRow(
                  label: 'Fence radius',
                  value: '${data.radiusMeters.round()} m',
                  labelWidth: 110,
                  dense: true,
                ),

                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Refresh location',
                        icon: Icons.refresh,
                        small: true,
                        onPressed: onRetry,
                      ),
                    ),
                    if (onOpenSettings != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Settings',
                          icon: Icons.settings_outlined,
                          small: true,
                          onPressed: onOpenSettings,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapturingCard extends StatelessWidget {
  const _CapturingCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Getting your location', style: AppTypography.titleSm),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Hold still for a moment while we confirm you are at the client.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Distance rendered against the fence radius, so "how far over" is legible at
/// a glance rather than requiring arithmetic.
class _DistanceGauge extends StatelessWidget {
  const _DistanceGauge({
    required this.distanceMeters,
    required this.radiusMeters,
    required this.tone,
  });

  final double distanceMeters;
  final double radiusMeters;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    // Scale so the fence marker sits at 60% of the track; anything beyond is
    // visibly outside without the bar pinning at full for a small overshoot.
    final scale = radiusMeters / 0.6;
    final fill = (distanceMeters / scale).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              GeoMath.formatDistance(distanceMeters) ?? '—',
              style: AppTypography.metric.copyWith(color: tone.foreground),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('from client', style: AppTypography.bodySm),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: AppProgressBar(
                      value: fill,
                      color: tone.foreground,
                      height: 8,
                    ),
                  ),
                  // Fence marker
                  Positioned(
                    left: constraints.maxWidth * 0.6 - 1,
                    top: 2,
                    child: Container(width: 2, height: 20, color: AppColors.textPrimary),
                  ),
                  Positioned(
                    left: constraints.maxWidth * 0.6 + 4,
                    top: 0,
                    child: Text(
                      '${radiusMeters.round()} m',
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
