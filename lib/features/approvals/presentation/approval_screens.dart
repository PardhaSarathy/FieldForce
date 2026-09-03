import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/engagement.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/primitives.dart';
import '../../../shared/widgets/states.dart';

final _kindFilterProvider = StateProvider.autoDispose<ApprovalKind?>(
  (ref) => null,
);
final _showDecidedProvider = StateProvider.autoDispose<bool>((ref) => false);

final _approvalsProvider = FutureProvider.autoDispose<List<ApprovalItem>>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  final repo = ref.watch(approvalRepositoryProvider);
  final kind = ref.watch(_kindFilterProvider);
  ref.watch(dataRevisionProvider);

  return ref.watch(_showDecidedProvider)
      ? repo.decided(session, kind: kind)
      : repo.pending(session, kind: kind);
});

/// Approval center (§43).
///
/// One queue across leave, expense, tour plan and order. A manager should not
/// have to visit four modules to clear their day, and the normalised
/// [ApprovalItem] projection is what makes bulk approval possible at all.
class ApprovalCenterScreen extends ConsumerStatefulWidget {
  const ApprovalCenterScreen({super.key});

  @override
  ConsumerState<ApprovalCenterScreen> createState() =>
      _ApprovalCenterScreenState();
}

class _ApprovalCenterScreenState extends ConsumerState<ApprovalCenterScreen> {
  final Set<String> _selected = {};
  bool _busy = false;

  bool get _isSelecting => _selected.isNotEmpty;

  Future<void> _approveSelected(List<ApprovalItem> all) async {
    final items = all.where((i) => _selected.contains(i.id)).toList();

    final confirmed = await showConfirmDialog(
      context,
      title: 'Approve ${items.length} request${items.length == 1 ? '' : 's'}?',
      message:
          'This cannot be undone. Each decision is recorded against your '
          'name in the approval history.',
      confirmLabel: 'Approve all',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    await ref
        .read(approvalRepositoryProvider)
        .approveAll(ref.read(sessionProvider), items);

    if (!mounted) return;
    ref.bumpRevision();
    ref.invalidate(pendingApprovalsProvider);
    ref.invalidate(managerDashboardProvider);
    setState(() {
      _busy = false;
      _selected.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${items.length} requests approved.')),
    );
  }

  Future<void> _decide(ApprovalItem item, {required bool approve}) async {
    String? reason;

    if (!approve) {
      // Rejection always requires a reason (§66.4) — the person has to know
      // what to fix.
      reason = await _askReason(context);
      if (reason == null) return;
    }

    final session = ref.read(sessionProvider);
    final repo = ref.read(approvalRepositoryProvider);

    if (approve) {
      await repo.approve(session, item);
    } else {
      await repo.reject(session, item, reason: reason!);
    }

    if (!mounted) return;
    ref.bumpRevision();
    ref.invalidate(pendingApprovalsProvider);
    ref.invalidate(managerDashboardProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approve ? '${item.title} approved.' : '${item.title} rejected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_approvalsProvider);
    final kind = ref.watch(_kindFilterProvider);
    final showDecided = ref.watch(_showDecidedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _isSelecting ? '${_selected.length} selected' : 'Approvals',
        ),
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              )
            : null,
      ),
      bottomNavigationBar: _isSelecting
          ? BottomActionBar(
              children: [
                SecondaryButton(
                  label: 'Clear',
                  onPressed: () => setState(_selected.clear),
                ),
                PrimaryButton(
                  label: 'Approve ${_selected.length}',
                  isLoading: _busy,
                  onPressed: () => _approveSelected(async.valueOrNull ?? []),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: SegmentedControl<bool>(
              options: const [false, true],
              selected: showDecided,
              labelOf: (v) => v ? 'Decided' : 'Pending',
              onSelected: (v) =>
                  ref.read(_showDecidedProvider.notifier).state = v,
            ),
          ),
          FilterChipBar<ApprovalKind?>(
            options: [null, ...ApprovalKind.values.take(4)],
            selected: kind,
            labelOf: (k) => k?.label ?? 'All',
            countOf: (k) => k == null
                ? null
                : async.valueOrNull?.where((i) => i.kind == k).length,
            onSelected: (k) => ref.read(_kindFilterProvider.notifier).state = k,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (_, _) =>
                  ErrorState(onRetry: () => ref.invalidate(_approvalsProvider)),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: showDecided
                        ? Icons.history
                        : Icons.check_circle_outline,
                    title: showDecided
                        ? 'No decisions yet'
                        : 'Nothing awaiting approval',
                    message: showDecided
                        ? 'Requests you approve or reject will be listed here.'
                        : 'Your team has no pending requests. '
                              'Everything is clear.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    0,
                    AppSpacing.screenH,
                    AppSpacing.xxxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Arrive.staggered(
                      index: i,
                      child: _ApprovalCard(
                        item: item,
                        isSelected: _selected.contains(item.id),
                        selectionMode: _isSelecting,
                        isDecided: showDecided,
                        onToggleSelect: () => setState(() {
                          if (!_selected.remove(item.id)) {
                            _selected.add(item.id);
                          }
                        }),
                        onApprove: () => _decide(item, approve: true),
                        onReject: () => _decide(item, approve: false),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Rejection reason prompt. Returns null when cancelled; never returns empty.
Future<String?> _askReason(BuildContext context) async {
  final controller = TextEditingController();

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reason for rejection', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The employee sees this, so be specific about what needs to '
                'change before they resubmit.',
                style: AppTypography.bodySm,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                hint: 'e.g. Receipt is not legible — please re-upload',
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => DangerButton(
                        label: 'Reject',
                        filled: true,
                        onPressed: controller.text.trim().isEmpty
                            ? null
                            : () => Navigator.of(
                                sheetContext,
                              ).pop(controller.text.trim()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    ),
  );

  controller.dispose();
  return result;
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.isSelected,
    required this.selectionMode,
    required this.isDecided,
    required this.onToggleSelect,
    required this.onApprove,
    required this.onReject,
  });

  final ApprovalItem item;
  final bool isSelected;
  final bool selectionMode;
  final bool isDecided;
  final VoidCallback onToggleSelect;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: isSelected ? AppColors.brand : AppColors.border,
      child: Column(
        children: [
          InkWell(
            onLongPress: isDecided ? null : onToggleSelect,
            onTap: selectionMode ? onToggleSelect : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onToggleSelect(),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: IconTile(icon: item.kind.icon),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.employeeName,
                                style: AppTypography.titleMd,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.amount != null)
                              Text(
                                Fmt.money(item.amount!),
                                style: AppTypography.numeric,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.kind.label} · ${item.title}',
                          style: AppTypography.bodySm,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.subtitle?.isNotEmpty == true) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.subtitle!,
                            style: AppTypography.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (item.date != null) ...[
                              const Icon(
                                Icons.event_outlined,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  Fmt.dateShort(item.date!),
                                  style: AppTypography.caption,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            // The status badge must always stay visible, so the
                            // timestamp is what gives way on a narrow screen.
                            Flexible(
                              child: Text(
                                'Submitted ${Fmt.timeAgo(item.submittedAt)}',
                                style: AppTypography.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            StatusBadge.approval(item.status, dense: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isDecided && !selectionMode) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: DangerButton(label: 'Reject', onPressed: onReject),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Approve',
                      small: true,
                      onPressed: onApprove,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
