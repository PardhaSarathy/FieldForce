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

/// HR hub (§23). A directory rather than a dashboard — each item is its own
/// workflow, and mixing them on one screen would bury the ones people use.
class HrHomeScreen extends ConsumerWidget {
  const HrHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = [
      (Icons.event_available_outlined, 'Attendance',
          'Your monthly presence record', Routes.attendance),
      (Icons.event_busy_outlined, 'Leave', 'Apply and track leave requests',
          Routes.leaves),
      (Icons.celebration_outlined, 'Holidays', 'Company holiday calendar',
          Routes.holidays),
      (Icons.payments_outlined, 'Pay slips', 'Monthly salary statements',
          Routes.payslips),
      (Icons.folder_outlined, 'Documents', 'Your employment documents',
          Routes.documents),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('HR')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: AppSpacing.cardPadding),
                  ListTile(
                    leading: IconTile(icon: items[i].$1),
                    title: Text(items[i].$2, style: AppTypography.titleMd),
                    subtitle: Text(items[i].$3, style: AppTypography.caption),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push(items[i].$4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================= attendance ==

final _attendanceMonthProvider = StateProvider.autoDispose<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final _attendanceProvider =
    FutureProvider.autoDispose<List<AttendanceRecord>>((ref) {
  final session = ref.watch(sessionProvider);
  final month = ref.watch(_attendanceMonthProvider);
  return ref.watch(hrRepositoryProvider).attendance(session.employee.id, month);
});

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_attendanceMonthProvider);
    final async = ref.watch(_attendanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          _MonthSwitcher(
            month: month,
            onChanged: (m) =>
                ref.read(_attendanceMonthProvider.notifier).state = m,
          ),
          const SizedBox(height: AppSpacing.lg),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxxl),
              child: LoadingState(),
            ),
            error: (_, _) => const ErrorState(),
            data: (records) => Column(
              children: [
                _AttendanceSummary(records: records),
                const SizedBox(height: AppSpacing.cardGap),
                AppCard(
                  child: _AttendanceCalendar(month: month, records: records),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                const _AttendanceLegend(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final canGoForward = month.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month),
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Expanded(
            child: Text(
              Fmt.monthYear(month),
              textAlign: TextAlign.center,
              style: AppTypography.titleMd,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoForward
                ? () => onChanged(DateTime(month.year, month.month + 1))
                : null,
          ),
        ],
      ),
    );
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({required this.records});

  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    int count(AttendanceStatus s) =>
        records.where((r) => r.status == s).length;

    final working = records
        .where((r) =>
            r.status != AttendanceStatus.holiday &&
            r.status != AttendanceStatus.weekOff)
        .length;

    return Row(
      children: [
        Expanded(child: _Stat(label: 'Working', value: '$working')),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Stat(
            label: 'Present',
            value: '${count(AttendanceStatus.present)}',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Stat(
            label: 'Leave',
            value: '${count(AttendanceStatus.leave)}',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Stat(
            label: 'Absent',
            value: '${count(AttendanceStatus.absent)}',
            color: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Text(value, style: AppTypography.metricSm.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _AttendanceCalendar extends StatelessWidget {
  const _AttendanceCalendar({required this.month, required this.records});

  final DateTime month;
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first grid.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;

    final byDay = {for (final r in records) r.date.day: r};

    return Column(
      children: [
        Row(
          children: [
            for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(label, style: AppTypography.overline),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _DayCell(day: day, record: byDay[day]),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, this.record});

  final int day;
  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final status = record?.status;
    final color = status?.color;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.12) ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: AppTypography.bodySm.copyWith(
              color: color ?? AppColors.textSecondary,
              fontWeight: status == null ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
          if (color != null) ...[
            const SizedBox(height: 2),
            StatusDot(color: color, size: 5),
          ],
        ],
      ),
    );
  }
}

class _AttendanceLegend extends StatelessWidget {
  const _AttendanceLegend();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          for (final status in AttendanceStatus.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusDot(color: status.color, size: 8),
                const SizedBox(width: AppSpacing.xs),
                Text(status.label, style: AppTypography.caption),
              ],
            ),
        ],
      ),
    );
  }
}

// ================================================================== leave ==

final _leavesProvider = FutureProvider.autoDispose<List<LeaveRequest>>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(hrRepositoryProvider)
      .leaves(session, employeeId: session.employee.id);
});

class LeaveListScreen extends ConsumerWidget {
  const LeaveListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_leavesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Leave')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newLeave),
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (leaves) => leaves.isEmpty
            ? EmptyState(
                icon: Icons.event_busy_outlined,
                title: 'No leave requests',
                message: 'Apply for leave and track its approval here.',
                actionLabel: 'Apply for leave',
                onAction: () => context.push(Routes.newLeave),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.screenH,
                  AppSpacing.screenH, AppSpacing.xxxl * 3,
                ),
                itemCount: leaves.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.cardGap),
                itemBuilder: (context, i) => _LeaveCard(leave: leaves[i]),
              ),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave});

  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.leaveDetail(leave.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(leave.type.label, style: AppTypography.titleMd),
              ),
              StatusBadge.approval(leave.status, dense: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.date_range_outlined,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  leave.days == 1
                      ? Fmt.date(leave.fromDate)
                      : Fmt.dateRange(leave.fromDate, leave.toDate),
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('· ${leave.days} day${leave.days == 1 ? '' : 's'}',
                  style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(leave.reason,
              style: AppTypography.bodySm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class LeaveDetailScreen extends ConsumerWidget {
  const LeaveDetailScreen({super.key, required this.leaveId});

  final String leaveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_leavesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Leave Detail')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (_, _) => const ErrorState(),
        data: (leaves) {
          final leave = leaves.where((l) => l.id == leaveId).firstOrNull;
          if (leave == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Leave request not found',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(leave.type.label, style: AppTypography.h3),
                        ),
                        StatusBadge.approval(leave.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    KeyValueRow(label: 'From', value: Fmt.date(leave.fromDate)),
                    KeyValueRow(label: 'To', value: Fmt.date(leave.toDate)),
                    KeyValueRow(label: 'Days', value: '${leave.days}'),
                    KeyValueRow(label: 'Reason', value: leave.reason),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              const SectionHeader(title: 'Approval history'),
              ApprovalTimeline(events: leave.approvalHistory),
            ],
          );
        },
      ),
    );
  }
}

class NewLeaveScreen extends ConsumerStatefulWidget {
  const NewLeaveScreen({super.key});

  @override
  ConsumerState<NewLeaveScreen> createState() => _NewLeaveScreenState();
}

class _NewLeaveScreenState extends ConsumerState<NewLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  LeaveType _type = LeaveType.casual;
  bool _submitting = false;

  int get _days => _to.difference(_from).inDays + 1;
  String? get _rangeError => Validate.dateRange(_from, _to);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _rangeError != null) return;
    setState(() => _submitting = true);

    final session = ref.read(sessionProvider);
    await ref.read(hrRepositoryProvider).applyLeave(
          LeaveRequest(
            id: const Uuid().v4(),
            employeeId: session.employee.id,
            employeeName: session.employee.name,
            fromDate: _from,
            toDate: _to,
            type: _type,
            reason: _reason.text.trim(),
            status: ApprovalStatus.submitted,
            approvalHistory: [],
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    ref.bumpRevision();
    setState(() => _submitting = false);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave request submitted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Apply for Leave')),
      bottomNavigationBar: BottomActionBar(
        children: [
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          PrimaryButton(
            label: 'Submit',
            isLoading: _submitting,
            onPressed: _rangeError == null ? _submit : null,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            DropdownField<LeaveType>(
              label: 'Leave type',
              required: true,
              items: LeaveType.values,
              value: _type,
              itemLabel: (t) => t.label,
              onChanged: (v) => setState(() => _type = v ?? LeaveType.casual),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: DateField(
                    label: 'From',
                    required: true,
                    value: _from,
                    onChanged: (d) => setState(() {
                      _from = d;
                      if (_to.isBefore(d)) _to = d;
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DateField(
                    label: 'To',
                    required: true,
                    value: _to,
                    firstDate: _from,
                    onChanged: (d) => setState(() => _to = d),
                  ),
                ),
              ],
            ),
            if (_rangeError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_rangeError!,
                  style: AppTypography.caption.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: AppColors.brandSoft,
              borderColor: Colors.transparent,
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: AppSizes.iconMd, color: AppColors.brand),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$_days day${_days == 1 ? '' : 's'} of ${_type.label}',
                    style: AppTypography.titleSm
                        .copyWith(color: AppColors.brandDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Reason',
              required: true,
              controller: _reason,
              maxLines: 3,
              validator: (v) => Validate.required(v, 'Reason'),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// =============================================== holidays, payslips, docs ==

class HolidaysScreen extends ConsumerWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_holidaysProvider);
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Holidays')),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (holidays) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          itemCount: holidays.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
          itemBuilder: (context, i) {
            final holiday = holidays[i];
            final isPast = holiday.date.isBefore(today);

            return AppCard(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isPast
                          ? AppColors.surfaceSecondary
                          : AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      children: [
                        Text(Fmt.monthShort(holiday.date).toUpperCase(),
                            style: AppTypography.overline.copyWith(fontSize: 9)),
                        Text('${holiday.date.day}',
                            style: AppTypography.titleMd.copyWith(
                              color: isPast
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(holiday.name,
                            style: AppTypography.titleMd.copyWith(
                              color: isPast
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            )),
                        Text(Fmt.weekday(holiday.date),
                            style: AppTypography.caption),
                      ],
                    ),
                  ),
                  if (holiday.isOptional)
                    const StatusBadge(
                      label: 'Optional',
                      tone: StatusTone.neutral,
                      dense: true,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

final _holidaysProvider = FutureProvider.autoDispose<List<Holiday>>(
  (ref) => ref.watch(hrRepositoryProvider).holidays(DateTime.now().year),
);

class PayslipsScreen extends ConsumerWidget {
  const PayslipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final async = ref.watch(_payslipsProvider(session.employee.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pay Slips')),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (payslips) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          itemCount: payslips.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
          itemBuilder: (context, i) => _PayslipCard(payslip: payslips[i]),
        ),
      ),
    );
  }
}

final _payslipsProvider =
    FutureProvider.autoDispose.family<List<Payslip>, String>(
  (ref, id) => ref.watch(hrRepositoryProvider).payslips(id),
);

class _PayslipCard extends StatefulWidget {
  const _PayslipCard({required this.payslip});

  final Payslip payslip;

  @override
  State<_PayslipCard> createState() => _PayslipCardState();
}

class _PayslipCardState extends State<_PayslipCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.payslip;

    return AppCard(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.monthYear(p.month), style: AppTypography.titleMd),
                    const SizedBox(height: 2),
                    Text('Net pay ${Fmt.money(p.netPay)}',
                        style: AppTypography.caption),
                  ],
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          if (_expanded) ...[
            const AppDivider(),
            Text('EARNINGS',
                style: AppTypography.overline, textAlign: TextAlign.left),
            const SizedBox(height: AppSpacing.sm),
            for (final entry in p.earnings.entries)
              KeyValueRow(
                label: entry.key,
                value: Fmt.money(entry.value),
                dense: true,
                labelWidth: 150,
              ),
            const AppDivider(),
            Text('DEDUCTIONS', style: AppTypography.overline),
            const SizedBox(height: AppSpacing.sm),
            for (final entry in p.deductionBreakup.entries)
              KeyValueRow(
                label: entry.key,
                value: Fmt.money(entry.value),
                dense: true,
                labelWidth: 150,
              ),
            const AppDivider(),
            Row(
              children: [
                Expanded(
                  child: Text('Net pay', style: AppTypography.titleMd),
                ),
                Text(Fmt.money(p.netPay),
                    style: AppTypography.titleMd
                        .copyWith(color: AppColors.brand)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Download PDF',
              icon: Icons.download_outlined,
              small: true,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('PDF download arrives with the backend.')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final async = ref.watch(_documentsProvider(session.employee.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Documents')),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const ErrorState(),
        data: (docs) => docs.isEmpty
            ? const EmptyState(
                icon: Icons.folder_outlined,
                title: 'No documents',
                message: 'Documents shared by HR will appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                itemCount: docs.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.cardGap),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  return AppCard(
                    child: Row(
                      children: [
                        IconTile(
                          icon: doc.type == 'PDF'
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doc.name, style: AppTypography.titleMd),
                              const SizedBox(height: 2),
                              Text(
                                '${doc.category} · ${doc.sizeLabel ?? doc.type}'
                                ' · ${Fmt.date(doc.uploadedAt)}',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_outlined),
                          color: AppColors.brand,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final _documentsProvider =
    FutureProvider.autoDispose.family<List<AppDocument>, String>(
  (ref, id) => ref.watch(hrRepositoryProvider).documents(id),
);
