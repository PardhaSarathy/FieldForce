import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

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
/// and nothing else, so the same sheet can be written as a workbook or as CSV
/// from one source — and so the contents can be asserted on in a test without
/// opening either.
class ExportSheet {
  const ExportSheet({
    required this.kind,
    required this.fileName,
    required this.rows,
    this.headerIndex = 6,
  });

  final ExportKind kind;

  /// Without an extension. The writer adds one, because the extension is a
  /// fact about the format and the format is chosen at the moment of saving.
  final String fileName;

  /// Every line of the sheet, header block included, as raw cells.
  final List<List<String>> rows;

  /// Which row is the table's header.
  ///
  /// Held, not searched for. It was found by looking for a cell reading
  /// 'Date' or 'Sr.No.', which is a string match against a column name — the
  /// first sheet to rename a column would have silently reported zero rows.
  final int headerIndex;

  /// Data rows — everything below the header line. What "31 rows" means to a
  /// rep, which is not what `rows.length` means.
  int get dataRowCount {
    final n = rows.length - headerIndex - 1;
    return n > 0 ? n : 0;
  }

  // ------------------------------------------------------------------- csv

  /// The same table as text, for anywhere a workbook cannot go.
  String toCsv() => rows.map(_line).join('\r\n');

  static String _line(List<String> cells) => cells.map(_cell).join(',');

  static String _cell(String value) {
    // A client called "Sharma, R." and a remark with a newline in it both
    // break a naive join, and both are ordinary here.
    if (!value.contains(RegExp(r'[",\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  // ------------------------------------------------------------------ xlsx

  /// A real Excel workbook.
  ///
  /// CSV was here first and it was the wrong answer: the office opens these in
  /// Excel, and a CSV arrives with every column as text — the amounts will not
  /// sum, the dates will not sort, and the header does not freeze. This writes
  /// the minimum OOXML that gives all three: dates as real dates, figures as
  /// real numbers, the header row bold and frozen.
  ///
  /// Written by hand rather than with a spreadsheet package, because the parts
  /// below are the whole format for a sheet with no formulas in it, and a
  /// library for this would be a dependency that only ever writes one shape.
  Uint8List toXlsx() {
    final archive = Archive();
    void add(String path, String xml) {
      final bytes = utf8.encode(xml);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes);
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook);
    add('xl/_rels/workbook.xml.rels', _workbookRels);
    add('xl/styles.xml', _styles);
    add('xl/worksheets/sheet1.xml', _sheetXml());

    // Deflate: Excel accepts stored entries, but a month of rows compresses to
    // about a tenth, and these travel over WhatsApp on a rep's data plan.
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// The widest each column needs to be, in Excel's character units.
  ///
  /// Measured off the content rather than fixed, because the same writer draws
  /// a client list of twelve columns and an expense sheet of seven. Without
  /// this every column is 8.43 wide and every name in the sheet reads as
  /// `#######` or spills over its neighbour.
  List<double> get _columnWidths {
    final widths = <double>[];
    // Indexed, not `for (final row in rows)` with `indexOf` — two blank rows
    // are equal, so `indexOf` would answer with the first one's position and
    // the heading test would be wrong for every row after it.
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        // The title and the name block are not columns — they are two cells
        // on their own rows, and letting a 30-character title set column A
        // would push the whole table sideways.
        final isHeading = r < headerIndex && c == 0;
        final w = (isHeading ? 12 : row[c].length + 2).toDouble();
        if (c >= widths.length) {
          widths.add(w);
        } else if (w > widths[c]) {
          widths[c] = w;
        }
      }
    }
    return [for (final w in widths) w.clamp(9.0, 42.0)];
  }

  String _sheetXml() {
    final b = StringBuffer()
      ..write(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      )
      // The header row stays put while the office scrolls a month of days.
      ..write(
        '<sheetViews><sheetView workbookViewId="0" tabSelected="1">'
        '<pane ySplit="${headerIndex + 1}" topLeftCell="A${headerIndex + 2}" '
        'activePane="bottomLeft" state="frozen"/>'
        '</sheetView></sheetViews>',
      );

    final widths = _columnWidths;
    if (widths.isNotEmpty) {
      b.write('<cols>');
      for (var i = 0; i < widths.length; i++) {
        b.write(
          '<col min="${i + 1}" max="${i + 1}" '
          'width="${widths[i].toStringAsFixed(1)}" customWidth="1"/>',
        );
      }
      b.write('</cols>');
    }

    b.write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) {
        b.write('<row r="${r + 1}"/>');
        continue;
      }
      b.write('<row r="${r + 1}">');
      for (var c = 0; c < row.length; c++) {
        b.write(_cellXml(row[c], _ref(c, r + 1), _styleFor(r, c)));
      }
      b.write('</row>');
    }
    b.write('</sheetData>');

    // Filter buttons on the header row: the office's first act on any of
    // these is to look at one station or one status.
    final lastCol = _ref(
      (widths.isEmpty ? 1 : widths.length) - 1,
      0,
    ).replaceAll(RegExp(r'\d'), '');
    b
      ..write(
        '<autoFilter ref="A${headerIndex + 1}:$lastCol${rows.length}"/>',
      )
      ..write('</worksheet>');
    return b.toString();
  }

  /// 0 body · 1 title · 2 the name block's labels · 3 the header row.
  int _styleFor(int row, int col) {
    if (row == 0) return 1;
    if (row < headerIndex) return col == 0 ? 2 : 0;
    if (row == headerIndex) return 3;
    return 0;
  }

  static String _ref(int col, int row) {
    var c = col;
    var name = '';
    do {
      name = String.fromCharCode(65 + c % 26) + name;
      c = c ~/ 26 - 1;
    } while (c >= 0);
    return '$name$row';
  }

  static final _isNumber = RegExp(r'^-?\d+(\.\d+)?$');
  static final _isDate = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

  /// Excel counts days from 1899-12-30. A date written as text is a date the
  /// office cannot sort a month by, which is the first thing they do.
  static num? _serial(String value) {
    final m = _isDate.firstMatch(value);
    if (m == null) return null;
    final d = DateTime.utc(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
    return d.difference(DateTime.utc(1899, 12, 30)).inDays;
  }

  static String _cellXml(String value, String ref, int style) {
    if (value.isEmpty) return '<c r="$ref" s="$style"/>';

    final serial = _serial(value);
    if (serial != null) {
      // Style 4 is the same body cell wearing a date format.
      return '<c r="$ref" s="${style == 0 ? 4 : style}"><v>$serial</v></c>';
    }
    if (_isNumber.hasMatch(value)) {
      return '<c r="$ref" s="$style"><v>$value</v></c>';
    }
    return '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">'
        '${_escape(value)}</t></is></c>';
  }

  static String _escape(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  // The six parts a workbook needs and not one more. No sharedStrings — the
  // cells carry their own text — and no theme, which Excel supplies itself.
  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbook =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  static const _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  /// The header row wears the app's own brand blue, so a sheet that arrives by
  /// mail still looks like it came from this app.
  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="1"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/></numFmts>'
      '<fonts count="4">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="14"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="3">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF1E5BD7"/>'
      '<bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="5">'
      '<xf xfId="0" numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
      '<xf xfId="0" numFmtId="0" fontId="1" fillId="0" borderId="0" applyFont="1"/>'
      '<xf xfId="0" numFmtId="0" fontId="2" fillId="0" borderId="0" applyFont="1"/>'
      '<xf xfId="0" numFmtId="0" fontId="3" fillId="2" borderId="0" applyFont="1" applyFill="1"/>'
      '<xf xfId="0" numFmtId="164" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}

/// The date format the sheets use.
///
/// Not the app's own `Fmt.date` — the writer turns `05/09/2026` into a real
/// Excel date, and `5 Sep 2026` would stay text in the cell.
String exportDate(DateTime d) => Fmt.slashDate(d);
