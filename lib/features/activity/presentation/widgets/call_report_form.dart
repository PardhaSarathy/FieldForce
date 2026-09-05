import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/inputs.dart';
import '../../../../shared/widgets/states.dart';

/// Every product in the catalogue, for the chips.
final callReportProductsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(businessRepositoryProvider).products(),
);

/// What a rep writes down about a call.
///
/// **One widget, used by both screens that ask for it** — the live visit flow
/// and Add New Activity. They had drifted into two different forms for the
/// same step: the visit asked for a star rating, the products discussed and
/// the material shared; the activity form asked for samples, a typed RCPA
/// number and a POB figure. Same record, same step number, same title, two
/// sets of questions — so what a call report contained depended on which door
/// the rep came through, and the two could never agree in a report.
///
/// The merged set is the union, in the order a call is actually recounted:
/// how it scored, what was said, what was discussed, what was handed over,
/// what it is worth, and when to come back.
class CallReportForm extends ConsumerWidget {
  const CallReportForm({
    super.key,
    required this.rcpaScore,
    required this.onRcpaChanged,
    required this.selectedProducts,
    required this.onProductsChanged,
    required this.feedback,
    required this.pop,
    required this.inputs,
    required this.pob,
    required this.remarks,
    required this.nextVisit,
    required this.onNextVisitChanged,
    this.feedbackRequired = false,
    this.nextVisitRequired = false,
  });

  final int rcpaScore;
  final ValueChanged<int> onRcpaChanged;

  final Set<String> selectedProducts;
  final ValueChanged<Set<String>> onProductsChanged;

  final TextEditingController feedback;
  final TextEditingController pop;
  final TextEditingController inputs;
  final TextEditingController pob;
  final TextEditingController remarks;

  final DateTime? nextVisit;
  final ValueChanged<DateTime> onNextVisitChanged;

  /// The live flow insists on feedback — a completed visit with nothing
  /// recorded is a visit nobody can report on. Logging one afterwards is
  /// often catch-up, so it asks but does not insist.
  final bool feedbackRequired;
  final bool nextVisitRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(callReportProductsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RCPA score', style: AppTypography.bodySm),
        const SizedBox(height: AppSpacing.sm),
        // Stars, not a number field. One of the two screens asked the rep to
        // type "1–5" into a box and validate it; the other showed five stars.
        // A rating is the one input a tap does better than a keyboard.
        StarRating(value: rcpaScore, onChanged: onRcpaChanged),
        const SizedBox(height: AppSpacing.xl),

        AppTextField(
          label: 'Feedback',
          hint: 'What did the client say, and what did you promise?',
          controller: feedback,
          maxLines: 4,
          required: feedbackRequired,
        ),
        const SizedBox(height: AppSpacing.lg),

        Text('Products discussed', style: AppTypography.bodySm),
        const SizedBox(height: AppSpacing.sm),
        productsAsync.when(
          loading: () => const Skeleton(height: 38),
          error: (_, _) => Text(
            'Products unavailable',
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
          data: (products) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final product in products)
                FilterChip(
                  label: Text(product.name),
                  selected: selectedProducts.contains(product.id),
                  onSelected: (selected) {
                    final next = Set<String>.of(selectedProducts);
                    if (selected) {
                      next.add(product.id);
                    } else {
                      next.remove(product.id);
                    }
                    onProductsChanged(next);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Input',
                controller: inputs,
                hint: 'Samples',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: 'POB',
                controller: pob,
                hint: '₹',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        AppTextField(
          label: 'POP / material shared',
          hint: 'Visual aid, brochure, samples…',
          controller: pop,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.lg),

        AppTextField(
          label: 'Remarks',
          hint: 'Anything else worth recording',
          controller: remarks,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.lg),

        DateField(
          label: 'Expected next visit',
          required: nextVisitRequired,
          value: nextVisit,
          firstDate: DateTime.now(),
          onChanged: onNextVisitChanged,
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

/// Five stars, tappable. Tapping the current score clears it, so a rating can
/// be undone without a separate control.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i == value ? 0 : i),
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            constraints: const BoxConstraints(),
            iconSize: 30,
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value ? AppColors.sand : AppColors.border,
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value == 0 ? 'Not rated' : '$value of 5',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}
