import '../../core/utils/formatters.dart';

/// One of the four sheets a rep can hand to the office.
///
/// The four came from the client's own workbook — Expenses, Tour Plan, DCR and
/// the Client List — and each keeps that sheet's shape: a title, the rep's
/// name, code, designation and area, a blank line, then the table.
enum ExportKind {
  expenses('Expenses', 'EXPENSES'),
  tourPlan('Tour Plan', 'TOUR PLAN'),
  dcr('DCR', 'DCR DETAILS'),
  clients('Client List', 'CLIENT LIST');

  const ExportKind(this.label, this.title);

  /// What the tile calls it.
  final String label;

  /// The banner across the top of the sheet.
  final String title;

  /// The client list is the whole list — it is not a month of anything, and
  /// offering a month picker beside it would be asking a question that changes
  /// nothing about the file.
  bool get isMonthly => this != ExportKind.clients;
}

/// A generated sheet: a filename and the rows that go in it.
///
/// **Rows of strings, not a formatted file.** The repository builds the table
/// and nothing else, so the same sheet can be written as CSV today and as a
/// real workbook the day a backend does it — and so the contents can be
/// asserted on in a test without opening a file.
class ExportSheet {
  const ExportSheet({
    required this.kind,
    required this.fileName,
    required this.rows,
  });

  final ExportKind kind;
  final String fileName;

  /// Every line of the sheet, header block included, as raw cells.
  final List<List<String>> rows;

  /// Data rows — everything below the header line. What "12 rows" means to a
  /// rep, which is not what `rows.length` means.
  int get dataRowCount {
    final header = rows.indexWhere((r) => r.length > 1 && r.first == 'Date');
    final start = header >= 0 ? header : rows.indexWhere(
      (r) => r.isNotEmpty && r.first == 'Sr.No.',
    );
    return start < 0 ? 0 : rows.length - start - 1;
  }

  /// CSV, because it opens in Excel and in Sheets without anything installed
  /// and needs no dependency to write. A real `.xlsx` is a zip of XML parts;
  /// building one by hand is a lot of code to own for a file the office opens
  /// and immediately re-saves.
  String toCsv() => rows.map(_line).join('\r\n');

  static String _line(List<String> cells) => cells.map(_cell).join(',');

  static String _cell(String value) {
    // A client called "Sharma, R." and a remark with a newline in it both
    // break a naive join, and both are ordinary here.
    if (!value.contains(RegExp(r'[",\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}

/// The date format the sheets use.
///
/// Not the app's own `Fmt.date` — a sheet is read in Excel, where `5 Sep 2026`
/// is text and `05/09/2026` is a date.
String exportDate(DateTime d) => Fmt.slashDate(d);
