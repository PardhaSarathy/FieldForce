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
import '../../../shared/models/organization.dart';
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

/// Whose records the sheets are built from — the signed-in user by default.
///
/// `null` means "me", rather than the employee's own id, so the provider does
/// not have to be seeded from the session before the screen can read it.
final _exportWhoProvider = StateProvider.autoDispose<Employee?>((ref) => null);

/// The people a manager may export for: themselves, then their team.
final _exportTeamProvider = FutureProvider.autoDispose<List<Employee>>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  if (!session.isManager) return const [];
  return ref.watch(employeeRepositoryProvider).teamOf(session);
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
    final session = ref.watch(sessionProvider);
    final who = ref.watch(_exportWhoProvider);
    final team = ref.watch(_exportTeamProvider).valueOrNull ?? const [];
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

          // Whose month. A manager runs a territory and the office asks them
          // for their reps' sheets as often as their own, so the picker holds
          // themselves first and then the team. Reps never see it — there is
          // one answer for them, and a dropdown with one entry is a question
          // with no question in it.
          //
          // The list only *offers* the right people; the repository is what
          // enforces it. A sheet is a copy of somebody's month leaving the
          // app, and a picker is not a permission.
          if (session.isManager && team.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            DropdownField<Employee>(
              label: 'Whose data',
              items: [session.employee, ...team],
              value: who ?? session.employee,
              itemLabel: (e) => e.id == session.employee.id
                  ? 'Me (${e.employeeCode})'
                  : '${e.name} · ${e.employeeCode}',
              onChanged: (e) => ref.read(_exportWhoProvider.notifier).state =
                  (e == null || e.id == session.employee.id) ? null : e,
            ),
          ],

          const SizedBox(height: AppSpacing.section),

          for (var i = 0; i < ExportKind.values.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.cardGap),
            Arrive.staggered(
              index: i + 1,
              child: _ExportRow(
                kind: ExportKind.values[i],
                month: month,
                who: who?.name,
                isBusy: _busy == ExportKind.values[i],
                onExport: () => _export(ExportKind.values[i], month, who),
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

  Future<void> _export(ExportKind kind, DateTime month, Employee? who) async {
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
          .build(session, kind, month, employeeId: who?.id);
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
        who == null
            ? 'Nothing filed for ${Fmt.monthYear(month)}, so there is nothing '
                  'to export.'
            : '${who.name} filed nothing for ${Fmt.monthYear(month)}.',
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
            subject: '${kind.title} — ${who?.name ?? session.employee.name}',
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
    this.who,
  });

  final ExportKind kind;
  final DateTime month;

  /// Named on the row when the sheet is somebody else's, so a manager cannot
  /// send the office a rep's month believing it was their own.
  final String? who;
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
                  [
                    // The client list is not a month of anything. Saying so is
                    // cheaper than a disabled picker beside it.
                    if (kind.isMonthly) Fmt.monthYear(month) else 'Every client',
                    ?who,
                  ].join(' · '),
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
