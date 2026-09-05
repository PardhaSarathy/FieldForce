import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/primitives.dart';

/// The client, and how far through the flow you are — in one box.
///
/// It was two full-width white strips stacked under the app bar: a hard edge
/// across the screen, the avatar flush against the top of it with no padding
/// at all, and the whole block reading as chrome bolted on rather than as part
/// of the page. A card sits *on* the wash with margins around it, which is
/// what every other block in this app does.
///
/// Shared by the live visit flow and Add New Activity — the same reason their
/// call reports are one widget.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.currentStep,
    required this.labels,
  });

  final String name;
  final String subtitle;
  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          // The client is the record; the steps are where you are in it. Only
          // the first belongs in a box — boxing the pair made one object out
          // of two different kinds of thing.
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                AppAvatar(name: name, size: AppSizes.avatarMd),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.titleMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          StepProgress(currentStep: currentStep, labels: labels),
        ],
      ),
    );
  }
}

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
    // Equal columns, not label-width ones.
    //
    // The dots used to size to their own labels with the connectors taking
    // whatever was left, so the circles landed wherever the words happened to
    // end — "Review" is short, so the last one sat well inside the right edge
    // and left a gap after it. Three equal cells put the circles at a sixth,
    // a half and five sixths of the width, symmetrical whatever the labels
    // say, and each connector runs from its circle to the next rather than
    // filling a leftover.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: _dotSize,
                  child: Row(
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox.shrink()
                            : _Connector(done: i <= currentStep),
                      ),
                      _StepDot(
                        index: i,
                        isComplete: i < currentStep,
                        isCurrent: i == currentStep,
                      ),
                      Expanded(
                        child: i == labels.length - 1
                            ? const SizedBox.shrink()
                            : _Connector(done: i < currentStep),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    color: i <= currentStep
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        i == currentStep ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The rule between two steps. Centred on the circles it joins, because it is
/// drawn beside them rather than under the whole column.
class _Connector extends StatelessWidget {
  const _Connector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    // Dark, not a hairline. `border` is the palest value in the palette — as a
    // 2pt rule between two circles on a near-white wash it barely registered,
    // so the three steps read as three loose marks rather than as one run.
    // The stretch already walked keeps the brand; the stretch ahead takes a
    // grey with enough weight to be a rail rather than a smudge.
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(vertical: _dotSize / 2 - 1),
      color: done ? AppColors.brand : AppColors.grey500,
    );
  }
}

/// The circle's diameter. The connector's top margin is derived from it, so
/// the two cannot drift out of alignment.
const double _dotSize = 26;

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.isComplete,
    required this.isCurrent,
  });

  final int index;
  final bool isComplete;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _dotSize,
      height: _dotSize,
      alignment: Alignment.center,
      // White, not a tint of the ground.
      //
      // The steps sit on the wash now rather than inside a card, and a circle
      // filled with `surfaceSecondary` is a circle filled with very nearly the
      // colour behind it — so the ring read as a faint outline drawn on the
      // page instead of as a marker sitting on it. White gives every circle an
      // edge against the wash; a finished one keeps its solid brand fill,
      // because that is the only one that has actually happened.
      decoration: BoxDecoration(
        color: isComplete ? AppColors.brand : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: isComplete || isCurrent
              ? AppColors.brand
              : AppColors.border,
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
    );
  }
}
