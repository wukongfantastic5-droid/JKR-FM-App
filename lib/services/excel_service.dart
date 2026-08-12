import 'dart:convert';
import 'dart:typed_data';

import 'zip_writer.dart';

/// A sheet in the Excel workbook.
class ExcelSheet {
  final String name;
  final List<String> headers;
  final List<List<String>> rows;

  const ExcelSheet({
    required this.name,
    required this.headers,
    this.rows = const [],
  });
}

/// Minimal hand-rolled XLSX (SpreadsheetML 2007) generator: STORE-only zip,
/// inline strings, no external dependencies. Verified to open in Excel.
class ExcelService {
  static Future<Uint8List> build(List<ExcelSheet> sheets) async {
    final files = <String, List<int>>{};

    final cts = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '${List.generate(sheets.length, (i) => '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}'
        '</Types>';
    files['[Content_Types].xml'] = utf8.encode(cts);

    final rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>';
    files['_rels/.rels'] = utf8.encode(rootRels);

    final workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${List.generate(sheets.length, (i) => '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>').join()}'
        '</Relationships>';
    files['xl/_rels/workbook.xml.rels'] = utf8.encode(workbookRels);

    final workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets>'
        '${List.generate(sheets.length, (i) {
          final name = _safeSheetName(sheets[i].name.isEmpty ? 'Sheet${i + 1}' : sheets[i].name);
          return '<sheet name="$name" sheetId="${i + 1}" r:id="rId${i + 1}"/>';
        }).join()}'
        '</sheets></workbook>';
    files['xl/workbook.xml'] = utf8.encode(workbook);

    for (var si = 0; si < sheets.length; si++) {
      final s = sheets[si];
      final buf = StringBuffer();
      buf.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      buf.write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
      buf.write('<sheetData>');
      if (s.headers.isNotEmpty) {
        buf.write(_rowXml(1, s.headers, header: true));
      }
      for (var ri = 0; ri < s.rows.length; ri++) {
        buf.write(_rowXml(ri + 2, s.rows[ri]));
      }
      buf.write('</sheetData></worksheet>');
      files['xl/worksheets/sheet${si + 1}.xml'] = utf8.encode(buf.toString());
    }

    return ZipWriter.store(files);
  }

  static String _safeSheetName(String name) {
    var s = name.trim();
    s = s.replaceAll(RegExp(r'[\\/?*\[\]:]'), '_');
    if (s.length > 31) s = s.substring(0, 31);
    return s.isEmpty ? 'Sheet' : s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  }

  static String _rowXml(int row, List<String> values, {bool header = false}) {
    final cells = StringBuffer();
    for (var ci = 0; ci < values.length; ci++) {
      final v = values[ci];
      final ref = _colRef(ci) + '$row';
      if (_isNumeric(v)) {
        cells.write('<c r="$ref"><v>${v.trim()}</v></c>');
      } else {
        cells.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc(v)}</t></is></c>');
      }
    }
    return '<row r="$row">$cells</row>';
  }

  static String _colRef(int i) {
    var s = '';
    var n = i + 1;
    while (n > 0) {
      final m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static bool _isNumeric(String v) =>
      RegExp(r'^-?\d+(\.\d+)?$').hasMatch(v.trim());

  static String _esc(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;')
      .replaceAll('\n', '&#10;');
}
