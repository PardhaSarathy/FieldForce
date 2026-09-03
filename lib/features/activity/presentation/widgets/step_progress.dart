import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Numbered step indicator for the multi-step forms (§18).
///
/// Steps are labelled, not just numbered — "Location / Call report / Review"
/// tells a user what is still ahead of them, which a row of bare circles does
/// not.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.currentStep,
    required this.labels,
  });

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  constraints: const BoxConstraints(minWidth: AppSpacing.md),
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  color: i <= currentStep ? AppColors.brand : AppColors.border,
                ),
              ),
            // Flexible, not intrinsic. The dots size to their labels, and at
            // maximum text size "Call report" is wide enough that three of
            // them plus two connectors overflow a 320pt phone by 43pt — the
            // label is simply cut off, which is the one thing a step header
            // must never do. Now the labels share what is left after the
            // connectors and ellipsise rather than overflowing.
            Flexible(
              child: _StepDot(
                index: i,
                label: labels[i],
                isComplete: i < currentStep,
                isCurrent: i == currentStep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.isComplete,
    required this.isCurrent,
  });

  final int index;
  final String label;
  final bool isComplete;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final active = isComplete || isCurrent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isComplete
                ? AppColors.brand
                : isCurrent
                ? AppColors.brandSoft
                : AppColors.surfaceSecondary,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? AppColors.brand : AppColors.border,
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: isComplete
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: AppTypography.badge.copyWith(
                    color: isCurrent
                        ? AppColors.brand
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
