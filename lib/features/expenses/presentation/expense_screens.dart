import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/field_ops.dart';
import '../../../shared/widgets/approval_timeline.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

enum ExpenseFilter {
  all('All'),
  draft('Draft'),
  submitted('Submitted'),
  approved('Approved'),
  rejected('Rejected');

  const ExpenseFilter(this.label);
  final String label;

  bool matches(Expense e) => switch (this) {
        all => true,
        draft => e.status == ApprovalStatus.draft,
        submitted => e.status.awaitsDecision,
        approved => e.status == ApprovalStatus.approved,
        rejected => e.status == ApprovalStatus.rejected,
      };
}

final _filterProvider =
    StateProvider.autoDispose<ExpenseFilter>((ref) => ExpenseFilter.all);

final _expensesProvider = FutureProvider.autoDispose<List<Expense>>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(expenseRepositoryProvider).list(
        session,
        employeeId: session.employee.id,
      );
});

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_filterProvider);
    final async = ref.watch(_expensesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newExpense),
        icon: const Icon(Icons.add),
        label: const Text('New expense'),
      ),
      body: Column(
        children: [
          async.maybeWhen(
            data: (items) => Padding(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: _ExpenseSummary(items: items),
            ),
            orElse: () => const SizedBox(height: AppSpacing.md),
          ),
          FilterChipBar<ExpenseFilter>(
            options: ExpenseFilter.values,
            selected: filter,
            labelOf: (f) => f.label,
            countOf: (f) => f == ExpenseFilter.all
                ? null
                : async.valueOrNull?.where(f.matches).length,
            onSelected: (f) => ref.read(_filterProvider.notifier).state = f,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) =>
                  ErrorState(onRetry: () => ref.invalidate(_expensesProvider)),
              data: (items) {
                final filtered = items.where(filter.matches).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: items.isEmpty
                        ? 'No expenses yet'
                        : 'No ${filter.label.toLowerCase()} expenses',
                    message: items.isEmpty
                        ? 'Claim your travel, food and lodging costs here.'
                        : 'Try a different filter.',
                    actionLabel: items.isEmpty ? 'Add an expense' : null,
                    onAction: () => context.push(Routes.newExpense),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xxxl * 3,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) => _ExpenseCard(expense: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseSummary extends StatelessWidget {
  const _ExpenseSummary({required this.items});

  final List<Expense> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = items.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );

    double sum(bool Function(Expense) test) =>
        thisMonth.where(test).fold(0, (s, e) => s + e.amount);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _SummaryCell(
              label: 'This month',
              value: Fmt.money(sum((_) => true)),
            ),
          ),
          Container(width: 1, height: 34, color: AppColors.border),
          Expanded(
            child: _SummaryCell(
              label: 'Approved',
              value: Fmt.money(sum((e) => e.status == ApprovalStatus.approved)),
              color: AppColors.success,
            ),
          ),
          Container(width: 1, height: 34, color: AppColors.border),
          Expanded(
            child: _SummaryCell(
              label: 'Pending',
              value: Fmt.money(sum((e) => e.status.awaitsDecision)),
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTypography.titleMd.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.expenseDetail(expense.id)),
      child: Row(
        children: [
          IconTile(icon: expense.category.icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.category.label, style: AppTypography.titleMd),
                const SizedBox(height: 2),
                Text(
                  expense.description ?? Fmt.date(expense.date),
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Flexible(
                      child: Text(Fmt.dateShort(expense.date),
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false),
                    ),
                    if (expense.hasReceipt) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.attachment,
                          size: 12, color: AppColors.textSecondary),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(expense.amount), style: AppTypography.numeric),
              const SizedBox(height: AppSpacing.xs),
              StatusBadge.approval(expense.status, dense: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================= detail ==

final _expenseProvider =
    FutureProvider.autoDispose.family<Expense, String>((ref, id) {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Expense Detail')),
      bottomNavigationBar: async.maybeWhen(
        data: (expense) => expense.status == ApprovalStatus.draft
            ? BottomActionBar(
                children: [
                  SecondaryButton(label: 'Edit', onPressed: () {}),
                  PrimaryButton(
                    label: 'Submit for approval',
                    onPressed: () async {
                      await ref
                          .read(expenseRepositoryProvider)
                          .submit(expense.id);
                      ref.bumpRevision();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Expense submitted for approval.')),
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
                            Text(Fmt.money(expense.amount),
                                style: AppTypography.metricSm),
                            Text(expense.category.label,
                                style: AppTypography.bodySm),
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
                  if (expense.travelMode != null)
                    KeyValueRow(
                        label: 'Travel mode', value: expense.travelMode!.label),
                  if (expense.fromLocation != null)
                    KeyValueRow(label: 'From', value: expense.fromLocation),
                  if (expense.toLocation != null)
                    KeyValueRow(label: 'To', value: expense.toLocation),
                  if (expense.distanceKm != null)
                    KeyValueRow(
                        label: 'Distance',
                        value: '${expense.distanceKm!.toStringAsFixed(1)} km'),
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
                          child: const Icon(Icons.receipt_outlined,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text('Receipt attached',
                              style: AppTypography.titleSm),
                        ),
                        TextButton(onPressed: () {}, child: const Text('View')),
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

class NewExpenseScreen extends ConsumerStatefulWidget {
  const NewExpenseScreen({super.key});

  @override
  ConsumerState<NewExpenseScreen> createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends ConsumerState<NewExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _remarks = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _distance = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.travel;
  TravelMode _travelMode = TravelMode.bike;
  DateTime _date = DateTime.now();
  bool _hasReceipt = false;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [_amount, _description, _remarks, _from, _to, _distance]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool submit}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final session = ref.read(sessionProvider);
    final expense = Expense(
      id: const Uuid().v4(),
      employeeId: session.employee.id,
      employeeName: session.employee.name,
      date: _date,
      category: _category,
      amount: double.parse(_amount.text.trim()),
      status: submit ? ApprovalStatus.submitted : ApprovalStatus.draft,
      description: _description.text.trim(),
      remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
      receiptPaths: _hasReceipt ? const ['receipt'] : const [],
      travelMode: _category == ExpenseCategory.travel ? _travelMode : null,
      fromLocation: _from.text.trim().isEmpty ? null : _from.text.trim(),
      toLocation: _to.text.trim().isEmpty ? null : _to.text.trim(),
      distanceKm: double.tryParse(_distance.text.trim()),
      createdAt: DateTime.now(),
      syncStatus: ref.read(isOnlineProvider)
          ? SyncStatus.synced
          : SyncStatus.savedLocally,
    );

    await ref.read(expenseRepositoryProvider).create(expense);
    if (!mounted) return;

    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(submit
            ? 'Expense submitted for approval.'
            : 'Expense saved as a draft.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTravel = _category == ExpenseCategory.travel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New Expense')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(
            label: 'Save draft',
            onPressed: _submitting ? null : () => _save(submit: false),
          ),
          PrimaryButton(
            label: 'Submit',
            isLoading: _submitting,
            onPressed: () => _save(submit: true),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
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
            DateField(
              label: 'Date',
              required: true,
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: AppSpacing.lg),
            CurrencyField(
              label: 'Amount',
              required: true,
              controller: _amount,
              validator: (v) => Validate.amount(v),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Description',
              required: true,
              controller: _description,
              hint: 'What was this for?',
              validator: (v) => Validate.required(v, 'Description'),
            ),

            if (isTravel) ...[
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Travel detail'),
              DropdownField<TravelMode>(
                label: 'Travel mode',
                items: TravelMode.values,
                value: _travelMode,
                itemLabel: (m) => m.label,
                onChanged: (v) =>
                    setState(() => _travelMode = v ?? TravelMode.bike),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: AppTextField(label: 'From', controller: _from)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: AppTextField(label: 'To', controller: _to)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Distance (km)',
                controller: _distance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],

            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Receipt'),
            AppCard(
              child: Column(
                children: [
                  if (_hasReceipt)
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.success),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text('Receipt attached',
                              style: AppTypography.titleSm),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _hasReceipt = false),
                          child: const Text('Remove'),
                        ),
                      ],
                    )
                  else ...[
                    Text(
                      'Attach a photo of the bill. Claims without a receipt '
                      'may be rejected.',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Camera',
                            icon: Icons.photo_camera_outlined,
                            small: true,
                            onPressed: () => setState(() => _hasReceipt = true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Gallery',
                            icon: Icons.photo_library_outlined,
                            small: true,
                            onPressed: () => setState(() => _hasReceipt = true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Remarks',
              controller: _remarks,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}
