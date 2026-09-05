import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/models/export.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// The four sheets the office asks for, and the rules they obey.
///
/// A render test cannot see any of this: the screen is four rows and a
/// dropdown whether the file behind them is right or empty.
void main() {
  final store = MockStore.instance;
  final employee =
      store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
  final session = Session(employee: employee, loginAt: DateTime(2026, 9));
  final today = store.seed.today;
  final month = DateTime(today.year, today.month - 1);

  final repo = MockExportRepository();

  Future<ExportSheet> sheet(ExportKind kind) =>
      repo.build(session, kind, month);

  group('every sheet carries the block the office reads first', () {
    test('title, name, code, designation, area — then a blank line', () async {
      for (final kind in ExportKind.values) {
        final s = await sheet(kind);
        expect(s.rows[0].first, kind.title, reason: kind.name);
        expect(s.rows[1], ['Name', employee.name]);
        expect(s.rows[2], ['Emp Code', employee.employeeCode]);
        expect(s.rows[3], ['Designation', employee.designation]);
        expect(s.rows[5], isEmpty, reason: 'the blank line before the table');
      }
    });

    test('the filename says which sheet, whose, and for when', () async {
      final s = await sheet(ExportKind.expenses);
      expect(s.fileName, contains('Expenses'));
      expect(s.fileName, contains(employee.employeeCode));
      expect(s.fileName, endsWith('.csv'));
    });
  });

  group('a month sheet has a row per day, worked or not', () {
    test('expenses covers the whole month and writes the day off by name',
        () async {
      final s = await sheet(ExportKind.expenses);
      final last = DateTime(month.year, month.month + 1, 0).day;
      expect(s.dataRowCount, last,
          reason: 'the office reads down the dates; a gap is a question');

      // Sundays are written into the station column with zeroes beside them,
      // exactly as the workbook does, rather than left out.
      final sundays = s.rows.where((r) => r.length > 1 && r[1] == 'SUNDAY');
      expect(sundays, isNotEmpty);
      for (final r in sundays) {
        expect(r[4], '0', reason: 'nothing is owed for a Sunday');
      }
    });

    test('the tour plan covers the whole month too', () async {
      final s = await sheet(ExportKind.tourPlan);
      expect(s.dataRowCount, DateTime(month.year, month.month + 1, 0).day);
    });

    test('the DCR counts calls, and splits listed from unlisted', () async {
      final s = await sheet(ExportKind.dcr);
      final header = s.rows.firstWhere((r) => r.isNotEmpty && r.first == 'Date');
      expect(header, contains('Clients Visited'));
      expect(header, contains('Listed'));
      expect(header, contains('Unlisted'));
      // Unplanned is ours, not theirs: the app knows which calls came off a
      // plan, and that is the question a manager asks about a DCR.
      expect(header, contains('Unplanned'));

      for (final r in s.rows.skip(7)) {
        if (r.length < 6) continue;
        final total = int.tryParse(r[2]);
        final listed = int.tryParse(r[3]);
        final unlisted = int.tryParse(r[4]);
        if (total == null || listed == null || unlisted == null) continue;
        expect(listed + unlisted, total,
            reason: 'every visited client is one or the other');
      }
    });
  });

  group('the client list is the list, not a month', () {
    test('it ignores the month and numbers every client', () async {
      final clients = await MockClientRepository().list(session);
      final s = await sheet(ExportKind.clients);

      expect(ExportKind.clients.isMonthly, isFalse);
      expect(s.dataRowCount, clients.length);
      expect(s.rows.last.first, '${clients.length}',
          reason: 'Sr.No. runs to the end');
    });

    test('a client with no special date says so rather than leaving a hole',
        () async {
      final s = await sheet(ExportKind.clients);
      for (final r in s.rows.skip(7)) {
        for (final cell in r) {
          expect(cell, isNotEmpty,
              reason: 'a blank cell in a client row reads as lost data');
        }
      }
    });
  });

  group('the file is one Excel will open', () {
    test('a comma, a quote and a newline all survive the round trip', () {
      const s = ExportSheet(
        kind: ExportKind.clients,
        fileName: 'x.csv',
        rows: [
          ['Sr.No.', 'Client Name'],
          ['1', 'Sharma, R.'],
          ['2', 'The "City" Clinic'],
          ['3', 'Line one\nline two'],
        ],
      );
      final csv = s.toCsv();
      expect(csv, contains('"Sharma, R."'));
      expect(csv, contains('"The ""City"" Clinic"'));
      expect(csv, contains('"Line one\nline two"'));
      expect(csv.split('\r\n').first, 'Sr.No.,Client Name');
    });

    test('dates are written the way Excel reads them', () {
      expect(exportDate(DateTime(2026, 9, 5)), '05/09/2026');
    });
  });

  group('what the sheets deliberately do not carry', () {
    test('no joint-work column, on either sheet that had one', () async {
      // Removed from this app outright — the field, both pickers and both
      // display rows — because "who rode along" was nobody's question.
      // Printing a column of "No" would be inventing data to fill a shape.
      for (final kind in [ExportKind.dcr, ExportKind.tourPlan]) {
        final s = await sheet(kind);
        final header =
            s.rows.firstWhere((r) => r.isNotEmpty && r.first == 'Date');
        for (final cell in header) {
          expect(cell.toLowerCase(), isNot(contains('jointwork')),
              reason: kind.name);
        }
      }
    });
  });

  group('an empty month is not an error', () {
    test('a month before the app had any records yields no data rows',
        () async {
      final s = await repo.build(session, ExportKind.expenses, DateTime(2019, 1));
      expect(s.dataRowCount, 0,
          reason: 'the screen says "nothing to export" rather than sharing '
              'an empty file');
    });
  });

  group('the sheet is derived, never stored', () {
    test('confirming a day changes the next sheet built', () async {
      final days = await MockExpenseRepository().claimMonth(
        session,
        DateTime(today.year, today.month),
      );
      final open = days.where((d) => d.isOpen).toList();
      if (open.isEmpty) return;

      final before = await repo.build(
        session,
        ExportKind.expenses,
        DateTime(today.year, today.month),
      );
      String? amountOf(ExportSheet s, DateTime d) => s.rows
          .firstWhere(
            (r) => r.isNotEmpty && r.first == exportDate(d),
            orElse: () => const [],
          )
          .elementAtOrNull(4);

      expect(amountOf(before, open.first.date), '0');

      await MockExpenseRepository().confirmStandardDays(session, open);

      final after = await repo.build(
        session,
        ExportKind.expenses,
        DateTime(today.year, today.month),
      );
      expect(amountOf(after, open.first.date), isNot('0'),
          reason: 'a sheet built from a stored copy would still read 0');
    });
  });
}
