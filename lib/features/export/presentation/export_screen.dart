import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/export.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inputs.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/primitives.dart';

/// The month every sheet is built for.
///
/// One picker at the top rather than one per row: a rep exports a month, not
/// four unrelated months, and four identical dropdowns is four chances to send
/// the office September's expenses against August's tour plan.
final _exportMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  // Last month, not this one. A month that is still running is a partial
  // sheet, and the office asks for these once the month has closed — the same
  // reason the expense claim will not submit until then.
  final now = DateTime.now();
  return DateTime(now.year, now.month - 1);
});

/// Export Data (§ export).
///
/// Four sheets, taken straight from the workbook the office already keeps:
/// Expenses, Tour Plan, DCR and the Client List. Each is built from records
/// the rep has already filed — nothing here asks him to re-enter anything —
/// and handed to whatever the phone uses to move a file.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  /// Which sheet is being built, if any. One at a time — the button that was
  /// tapped is the one that spins.
  ExportKind? _busy;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(_exportMonthProvider);
    final now = DateTime.now();

    // Twelve months back, and never a month that has not finished.
    final months = [
      for (var i = 1; i <= 12; i++) DateTime(now.year, now.month - i),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Export Data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.xxxl,
        ),
        children: [
          Arrive(
            child: DropdownField<DateTime>(
              label: 'Month',
              items: months,
              value: month,
              itemLabel: Fmt.monthYear,
              onChanged: (m) => ref
                  .read(_exportMonthProvider.notifier)
                  .state = m ?? month,
              helper: 'A month that is still running would be half a sheet.',
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          for (var i = 0; i < ExportKind.values.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.cardGap),
            Arrive.staggered(
              index: i + 1,
              child: _ExportRow(
                kind: ExportKind.values[i],
                month: month,
                isBusy: _busy == ExportKind.values[i],
                onExport: () => _export(ExportKind.values[i], month),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.table_chart_outlined,
                size: AppSizes.iconSm,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Each sheet opens in Excel or Sheets. It is built from what '
                  'you have already filed — nothing here is re-typed.',
                  style: AppTypography.caption.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(ExportKind kind, DateTime month) async {
    setState(() => _busy = kind);
    final session = ref.read(sessionProvider);

    try {
      final sheet = await ref
          .read(exportRepositoryProvider)
          .build(session, kind, month);

      if (!mounted) return;

      // Nothing to send is not an error, and it must not open a share sheet
      // with an empty file in it.
      if (sheet.dataRowCount == 0) {
        AppHaptics.failure();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nothing filed for ${Fmt.monthYear(month)}, so there is nothing '
              'to export.',
            ),
          ),
        );
        return;
      }

      // Bytes, not a path. `XFile.fromData` lets the plugin put the file
      // wherever the platform wants it, which is the one part of this that
      // differs on every platform.
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(sheet.toCsv()),
              name: sheet.fileName,
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: [sheet.fileName],
          subject: '${kind.title} — ${session.employee.name}',
        ),
      );

      if (!mounted) return;
      AppHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${kind.label}: ${Fmt.count(sheet.dataRowCount, 'row')} ready.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppHaptics.failure();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not build the sheet. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }
}

/// One sheet, and the button that builds it.
class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.kind,
    required this.month,
    required this.isBusy,
    required this.onExport,
  });

  final ExportKind kind;
  final DateTime month;
  final bool isBusy;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        children: [
          IconWell(
            icon: switch (kind) {
              ExportKind.expenses => Icons.receipt_long_outlined,
              ExportKind.tourPlan => Icons.map_outlined,
              ExportKind.dcr => Icons.fact_check_outlined,
              ExportKind.clients => Icons.people_outline,
            },
            size: 42,
            color: switch (kind) {
              ExportKind.expenses => ModulePalette.expenses.ink,
              ExportKind.tourPlan => ModulePalette.travel.ink,
              ExportKind.dcr => ModulePalette.activity.ink,
              ExportKind.clients => ModulePalette.clients.ink,
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.label,
                  style: AppTypography.titleSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  // The client list is not a month of anything. Saying so is
                  // cheaper than a disabled picker beside it.
                  kind.isMonthly ? Fmt.monthYear(month) : 'Every client',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PrimaryButton(
            label: 'Export',
            small: true,
            expand: false,
            isLoading: isBusy,
            onPressed: onExport,
          ),
        ],
      ),
    );
  }
}
