import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/field_ops.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/approval_timeline.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

/// Detail and correction for a single filed claim.
///
/// The list that used to live here was a flat run of receipts with status
/// filters over it. It has been replaced by [ExpenseClaimScreen] — a month of
/// *declared days* — because a claim now hangs off the day it was worked, and
/// a list that could not show a day with nothing claimed against it was
/// missing the only rows that need action.
final _expenseProvider = FutureProvider.autoDispose.family<Expense, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(expenseRepositoryProvider).byId(id);
});

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_expenseProvider(expenseId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Expense Detail')),
      bottomNavigationBar: async.maybeWhen(
        data: (expense) => expense.status == ApprovalStatus.draft
            ? BottomActionBar(
                children: [
                  SecondaryButton(
                    label: 'Edit',
                    onPressed: () => context.push(Routes.editExpense(expense.id)),
                  ),
                  PrimaryButton(
                    label: 'Submit for approval',
                    onPressed: () async {
                      await ref
                          .read(expenseRepositoryProvider)
                          .submit(expense.id);
                      AppHaptics.success();
                      ref.bumpRevision();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Expense submitted for approval.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              )
            : null,
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (expense) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconTile(icon: expense.category.icon, size: 44),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Fmt.money(expense.amount),
                              style: AppTypography.metricSm,
                            ),
                            Text(
                              expense.category.label,
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge.approval(expense.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(label: 'Employee', value: expense.employeeName),
                  KeyValueRow(label: 'Date', value: Fmt.date(expense.date)),
                  KeyValueRow(label: 'Category', value: expense.category.label),
                  KeyValueRow(label: 'Description', value: expense.description),

                  // The three the claim form captures and nothing displayed.
                  //
                  // Data a rep enters must be shown back somewhere, and this
                  // is the screen a manager opens to decide. Without the
                  // allowance beside the amount there is nothing on the page
                  // saying whether ₹1,450 was reasonable, and without the
                  // territory there is nothing saying why.
                  KeyValueRow(
                    label: 'Day allowance',
                    value: Fmt.money(expense.allowance),
                  ),
                  if (expense.excess > 0)
                    KeyValueRow(
                      label: 'Above allowance',
                      value: Fmt.money(expense.excess),
                    ),
                  KeyValueRow(
                    label: 'Territory',
                    value: expense.scope.label,
                  ),
                  if (expense.place != null)
                    KeyValueRow(label: 'Travelled to', value: expense.place),
                  if (expense.travelMode != null)
                    KeyValueRow(
                      label: 'Travel mode',
                      value: expense.travelMode!.label,
                    ),
                  if (expense.fromLocation != null)
                    KeyValueRow(label: 'From', value: expense.fromLocation),
                  if (expense.toLocation != null)
                    KeyValueRow(label: 'To', value: expense.toLocation),
                  if (expense.distanceKm != null)
                    KeyValueRow(
                      label: 'Distance',
                      value: '${expense.distanceKm!.toStringAsFixed(1)} km',
                    ),
                  KeyValueRow(label: 'Remarks', value: expense.remarks),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            const SectionHeader(title: 'Receipt'),
            AppCard(
              child: expense.hasReceipt
                  ? Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(
                            Icons.receipt_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Receipt attached',
                            style: AppTypography.titleSm,
                          ),
                        ),
                        TextButton(
                          onPressed: () => showComingWithBackend(
                            context,
                            'Viewing the receipt',
                          ),
                          child: const Text('View'),
                        ),
                      ],
                    )
                  : const EmptyState(
                      compact: true,
                      icon: Icons.receipt_outlined,
                      title: 'No receipt attached',
                      message: 'Claims above ₹500 usually require a receipt.',
                    ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            const SectionHeader(title: 'Approval history'),
            ApprovalTimeline(events: expense.approvalHistory),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ==================================================================== new ==

/// The claim form, for both creating and editing a draft.
class EditExpenseScreen extends ConsumerWidget {
  const EditExpenseScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_expenseProvider(expenseId)).when(
          loading: () => const Scaffold(
            backgroundColor: Colors.transparent,
            body: LoadingState(message: 'Loading claim'),
          ),
          error: (_, _) => Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('Edit Expense')),
            body: ErrorState(
              onRetry: () => ref.invalidate(_expenseProvider(expenseId)),
            ),
          ),
          data: (expense) => _EditClaimForm(expense: expense),
        );
  }
}

/// Correcting a filed claim.
///
/// Narrow on purpose. The date, the day plan it hangs off and the allowance it
/// was worth are all evidence of a day that has already happened — a
/// correction fixes what the rep *typed*, never what the day *was*. Rebuilding
/// the record from the form alone would drop the id, the created date and the
/// append-only approval history, which is how an edit quietly becomes a
/// duplicate.
class _EditClaimForm extends ConsumerStatefulWidget {
  const _EditClaimForm({required this.expense});

  final Expense expense;

  @override
  ConsumerState<_EditClaimForm> createState() => _EditClaimFormState();
}

class _EditClaimFormState extends ConsumerState<_EditClaimForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.expense.amount.toStringAsFixed(0),
  );
  late final _remarks = TextEditingController(
    text: widget.expense.description ?? '',
  );
  late ExpenseCategory _category = widget.expense.category;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    final entered = double.tryParse(_amount.text.trim()) ?? 0;
    final excess = entered - e.allowance;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Edit Expense')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: _saving ? null : () => context.pop(),
          ),
          PrimaryButton(
            label: 'Save changes',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            AppCard(
              color: AppColors.surfaceSecondary,
              borderColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  KeyValueRow(label: 'Date', value: Fmt.date(e.date)),
                  const AppDivider(height: AppSpacing.md),
                  KeyValueRow(
                    label: 'Day allowance',
                    value: Fmt.money(e.allowance),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            DropdownField<ExpenseCategory>(
              label: 'Category',
              required: true,
              items: ExpenseCategory.values,
              value: _category,
              itemLabel: (c) => c.label,
              onChanged: (v) =>
                  setState(() => _category = v ?? ExpenseCategory.other),
            ),
            const SizedBox(height: AppSpacing.lg),

            CurrencyField(
              label: 'Amount',
              required: true,
              controller: _amount,
              onChanged: (_) => setState(() {}),
              validator: (v) => Validate.amount(v),
              helper: '${Fmt.money(e.allowance)} a day is paid without a '
                  'bill. Anything above it needs one.',
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: excess > 0 ? 'Why the extra' : 'Description',
              required: excess > 0,
              controller: _remarks,
              maxLines: 3,
              validator: excess > 0
                  ? (v) => Validate.required(v, 'Reason')
                  : null,
            ),

            if (excess > 0 && !e.hasReceipt) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                borderColor: AppColors.warning.withValues(alpha: 0.4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: AppSizes.iconMd,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${Fmt.money(excess)} above the allowance has no bill '
                        'attached. Add one before saving.',
                        style: AppTypography.bodySm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final e = widget.expense;
    final entered = double.tryParse(_amount.text.trim()) ?? 0;

    if (entered - e.allowance > 0 && !e.hasReceipt) {
      AppHaptics.failure();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attach the bill for the amount above the allowance.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    // `copyWith`, never a rebuilt constructor: the id, the created date, the
    // day plan and the approval trail all have to survive a correction.
    await ref.read(expenseRepositoryProvider).update(
          e.copyWith(
            amount: entered,
            description: _remarks.text.trim().isEmpty
                ? null
                : _remarks.text.trim(),
          ),
        );

    if (!mounted) return;
    AppHaptics.success();
    ref.bumpRevision();
    setState(() => _saving = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Claim updated.')),
    );
  }
}

