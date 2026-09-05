import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_saver/file_saver.dart';
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

    // Building and saving are two acts with two failures, and they were
    // wrapped in one `try` that blamed the first for both. A file that will
    // not save is not a sheet that would not build — telling a rep his month
    // failed to generate when it generated perfectly sends him looking in the
    // wrong place.
    final ExportSheet sheet;
    try {
      sheet = await ref
          .read(exportRepositoryProvider)
          .build(session, kind, month);
    } catch (_) {
      _finish();
      if (!mounted) return;
      AppHaptics.failure();
      _say('Could not build the ${kind.label} sheet. Try again.');
      return;
    }

    if (!mounted) return _finish();

    // Nothing to send is not an error, and it must not download an empty
    // workbook that the office then has to ask about.
    if (sheet.dataRowCount == 0) {
      _finish();
      AppHaptics.failure();
      _say(
        'Nothing filed for ${Fmt.monthYear(month)}, so there is nothing to '
        'export.',
      );
      return;
    }

    final rows = Fmt.count(sheet.dataRowCount, 'row');

    try {
      // Downloads, rather than opening a share sheet.
      //
      // Share was the first answer and it was the wrong one: the office asks
      // for a file, and a share sheet asks the rep to pick an app before he
      // has one. This writes it where the phone keeps downloads — no
      // permission prompt on any Android this app supports, because it goes
      // through the media store rather than the filesystem.
      await FileSaver.instance.saveFile(
        name: sheet.fileName,
        bytes: sheet.toXlsx(),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      _finish();
      if (!mounted) return;
      AppHaptics.success();
      _say('${sheet.fileName}.xlsx saved to Downloads — $rows.');
    } catch (_) {
      // No downloads folder to write to: a desktop build, a locked-down
      // device. The workbook exists and the rep should still be able to get
      // it out, so it goes to the share sheet instead of nowhere. A control
      // that cannot act must still answer.
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                sheet.toXlsx(),
                name: '${sheet.fileName}.xlsx',
                mimeType: _xlsxMime,
              ),
            ],
            fileNameOverrides: ['${sheet.fileName}.xlsx'],
            subject: '${kind.title} — ${session.employee.name}',
          ),
        );
        _finish();
        if (!mounted) return;
        AppHaptics.success();
        _say('${kind.label} — $rows.');
      } catch (_) {
        _finish();
        if (!mounted) return;
        AppHaptics.failure();
        _say('Could not save the file. Check the app has storage access.');
      }
    }
  }

  void _finish() {
    if (mounted) setState(() => _busy = null);
  }

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

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
