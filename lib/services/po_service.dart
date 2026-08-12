import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'quotation_pdf.dart';
import 'zip_writer.dart';

/// One line item on the purchase order.
class PoItem {
  final String description;
  final int qty;
  final double price;
  const PoItem(this.description, this.qty, this.price);
}

/// Everything the generator needs to fill the template PO form.
class PoInput {
  /// New sheet / PO identity, e.g. 'PO-0054' (also replaces the workbook
  /// print-area name). Must not contain quote characters.
  final String sheetName;

  /// Full PO number shown in G5, e.g. 'CMSB/2026/PO-0054'.
  final String poNumber;

  /// Payment term shown in G6, e.g. '60 DAYS'.
  final String term;

  /// CAKRA contact shown in G19.
  final String attnCakra;

  final DateTime date;

  final List<PoItem> items;

  /// Vendor name/address shown in column B (rows 9-12).
  final List<String> vendorLines;

  /// Vendor phone shown in C17 (next to the template's 'Tel' label).
  final String vendorTel;

  /// Vendor attention contact shown in C19 (next to 'Attn :'). Empty clears
  /// the template's hardcoded value.
  final String vendorAttn;

  const PoInput({
    required this.sheetName,
    required this.poNumber,
    required this.term,
    required this.attnCakra,
    required this.date,
    required this.items,
    this.vendorLines = const [],
    this.vendorTel = '',
    this.vendorAttn = '',
  });

  /// Builds a PO from a parsed quotation. Quotation defaults: payment term,
  /// date. [attnCakra] stays the CAKRA-side contact printed in G19.
  factory PoInput.fromQuotation(
    Quotation q, {
    required String sheetName,
    required String poNumber,
    String? term,
    DateTime? date,
    String attnCakra = 'ZAINALABIDIN BIN CHE HASSAN',
  }) {
    return PoInput(
      sheetName: sheetName,
      poNumber: poNumber,
      term: term ?? q.terms,
      attnCakra: attnCakra,
      date: date ?? DateTime.now(),
      items: [
        for (final i in q.items) PoItem(i.description, i.qty, i.unitPrice),
      ],
      vendorLines: q.vendor,
      vendorTel: vendorTelFrom(q.vendor),
      vendorAttn: q.attn,
    );
  }

  /// Extracts the vendor phone: the value of a 'Tel ...:' line in the vendor
  /// block, else the last line that is itself a phone number.
  static String vendorTelFrom(List<String> lines) {
    for (final l in lines) {
      final m = RegExp(r'^\s*(tel(?:ephone)?(?: no\.?)?|phone(?: no\.?)?)\s*[:.\-]?\s*(.+)$',
              caseSensitive: false)
          .firstMatch(l.trim());
      if (m != null) {
        final v = m.group(2)!.trim();
        return RegExp(r'[0-9][\d\s().+\-/]*[0-9]')
                .firstMatch(v)
                ?.group(0)
                ?.trim() ??
            v;
      }
    }
    for (final l in lines.reversed) {
      final t = l.trim();
      if (RegExp(r'^[\d\s().+\-/]{5,}$').hasMatch(t)) {
        return RegExp(r'[0-9][\d\s().+\-/]*[0-9]')
                .firstMatch(t)
                ?.group(0)
                ?.trim() ??
            t;
      }
    }
    return '';
  }
}

/// Fills the boss-approved `PO MEKANIKAL Template.xlsx` (assets) with the
/// given purchase-order data and returns a complete, Excel-valid .xlsx.
///
/// The whole transformation below is the direct Dart port of the Python
/// prototype that was bisected against real Excel: every step was verified
/// (open + values) through Excel COM, and the rules that must hold are:
///   1. the sheetData row numbers (and every `r=` cell ref) must be shifted
///      together BEFORE inserting the new item rows;
///   2. merged ranges whose start row is inside the shifted zone must move
///      with it, and the `<dimension>` hint must be refreshed;
///   3. `image1.png` is referenced from sheet1's rels (rId4) and must be
///      KEPT while dropping sheets 2/3 / drawings 2/3 / printerSettings 2/3;
///   4. the calcChain part must be removed everywhere it is referenced
///      (parts, [Content_Types].xml override, workbook rels);
///   5. the workbook `_xlnm.Print_Area` definedName must be renamed to the
///      new sheet name (a stale '046' name makes Excel refuse to open);
///   6. sharedStrings entries appended must be ONE `<si>` deep and the
///      sst `count`/`uniqueCount` attributes must match the real contents;
///   7. docProps/app.xml HeadingPairs + TitlesOfParts vector sizes must
///      equal the number of lpstr entries actually present.
class PoService {
  /// Loads the bundled template and builds the PO workbook.
  static Future<Uint8List> buildFromAsset(PoInput input) async {
    final data = await rootBundle.load('assets/po_mechanical_template.xlsx');
    return build(data.buffer.asUint8List(), input);
  }

  /// Pure transform: [templateBytes] are the raw template .xlsx bytes.
  static Uint8List build(List<int> templateBytes, PoInput input) {
    if (input.sheetName.contains("'")) {
      throw ArgumentError('sheetName must not contain quotes');
    }
    if (input.items.length > 15) {
      throw ArgumentError('max 15 items per PO (rows 26..40)');
    }
    final archive = ZipDecoder().decodeBytes(templateBytes);
    final files = <String, List<int>>{};
    for (final f in archive) {
      if (f.isFile) files[f.name] = f.content as List<int>;
    }

    // ---------- sharedStrings ----------
    final ss = utf8.decode(files['xl/sharedStrings.xml']!);
    final sstMatch =
        RegExp(r'<sst[^>]*>(.*)</sst>', dotAll: true).firstMatch(ss)!;
    final sis = <String>[]; // raw inner XML of each <si>
    final siMap = <String, int>{};
    for (final si in RegExp(r'<si>(.*?)</si>', dotAll: true)
        .allMatches(sstMatch.group(1)!)) {
      final inner = si.group(1)!;
      final txt = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
          .allMatches(inner)
          .map((m) => m.group(1)!)
          .join()
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
      sis.add(inner);
      siMap.putIfAbsent(txt, () => sis.length - 1);
    }
    final origCount = int.parse(
        RegExp(r'<sst[^>]* count="(\d+)"').firstMatch(ss)!.group(1)!);
    final origUnique = int.parse(
        RegExp(r'uniqueCount="(\d+)"').firstMatch(ss)!.group(1)!);

    int sharedIndex(String text) {
      final existing = siMap[text];
      if (existing != null) return existing;
      final idx = sis.length;
      sis.add('<t>${esc(text)}</t>');
      siMap[text] = idx;
      return idx;
    }

    final sPo = sharedIndex(input.poNumber);
    final sTerm = sharedIndex(input.term);
    final sAttn = sharedIndex(input.attnCakra);
    final numIdx = <int>[
      0,
      for (var n = 1; n <= 15; n++) sharedIndex('$n'),
    ];
    final descIdx =
        input.items.map((it) => sharedIndex(it.description)).toList();

    // NOTE: the sst XML must NOT be serialized here — vendor writes below
    // (B9..B12/C17/C19) call sharedIndex() again and would produce indexes
    // past the serialized table (Excel shows those cells as empty/broken).
    // The sst is serialized after all setsi() writes, just before the sheet.

    // ---------- sheet1.xml ----------
    var xml = utf8.decode(files['xl/worksheets/sheet1.xml']!);

    void setsi(String cell, int sidx) {
      xml = xml.replaceFirstMapped(
          RegExp('(<c r="$cell"[^>]*t="s"><v>)\\d+(</v></c>)'),
          (m) => '${m.group(1)}$sidx${m.group(2)}');
    }

    // date serial (Excel 1900 system, same epoch as the template's own dates)
    final serial = input.date.difference(DateTime(1899, 12, 30)).inDays;
    xml = xml.replaceFirstMapped(
        RegExp(r'(<c r="G4"[^>]*>)(<v>)\d+(</v></c>)'),
        (m) => '${m.group(1)}${m.group(2)}$serial${m.group(3)}');

    // 1) renumber original rows 40..71 -> 41..72 (item 15 fills new row 40)
    xml = xml.replaceAllMapped(RegExp('<row r="(4[0-9]|5[0-9]|6[0-9]|7[01])"'),
        (m) => '<row r="${int.parse(m.group(1)!) + 1}"');
    xml = xml.replaceAllMapped(
        RegExp(r'<c r="([A-Z]+)(4[0-9]|5[0-9]|6[0-9]|7[01])"'),
        (m) => '<c r="${m.group(1)}${int.parse(m.group(2)!) + 1}"');

    // 2) totals formulas follow the DISCOUNT row down one row
    xml = xml.replaceAll('SUM(I26:I39)', 'SUM(I26:I40)');
    xml = xml.replaceAll('SUM(I40)', 'SUM(I41)');

    // 3) merged ranges whose start row is in the shifted zone move with it
    xml = xml.replaceAllMapped(RegExp(r'<mergeCell ref="([A-Z]+\d+):([A-Z]+\d+)"/>'),
        (m) {
      final a = m.group(1)!;
      final b = m.group(2)!;
      String bump(String cell) {
        final lm = RegExp(r'([A-Z]+)(\d+)').firstMatch(cell)!;
        return '${lm.group(1)}${int.parse(lm.group(2)!) + 1}';
      }
      final aRow = int.parse(RegExp(r'\d+').firstMatch(a)!.group(0)!);
      return aRow >= 40
          ? '<mergeCell ref="${bump(a)}:${bump(b)}"/>'
          : m.group(0)!;
    });

    // 4) dimension hint refresh
    xml = xml.replaceAll('<dimension ref="A2:K71"/>', '<dimension ref="A2:K72"/>');

    // 5) header patches
    setsi('G5', sPo);
    setsi('G6', sTerm);
    setsi('G19', sAttn);
    // 5b) vendor: name/address fill B9..B12 (contact lines like
    //     'Tel ...'/'Email ...' are handled by C17/C19 instead), tel in
    //     C17 and attn in C19. Empty values clear the template's
    //     hardcoded TWO ADVANCED data.
    final vLines = input.vendorLines
        .where((l) =>
            !RegExp(r'^\s*(tel|email|fax|attn|tin)', caseSensitive: false)
                .hasMatch(l.trim()))
        .toList();
    var vendorRow = 9;
    for (var i = 0; i < 4; i++) {
      final text = i < vLines.length ? vLines[i] : '';
      setsi('B$vendorRow', sharedIndex(text));
      vendorRow++;
    }
    setsi('C17', sharedIndex(input.vendorTel));
    setsi('C19', sharedIndex(input.vendorAttn));

    // serialize the sst AFTER every sharedIndex() call (see note above)
    final sst =
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'count="${origCount + (sis.length - origUnique)}" '
        'uniqueCount="${sis.length}">'
        '${sis.map((si) => '<si>$si</si>').join()}</sst>';
    files['xl/sharedStrings.xml'] = utf8.encode(sst);

    // 6) replace the 14 blank template rows 26..39 with the 15 item slots
    //    rows 26..40 (missing items stay blank with B-number, like the
    //    template's own empty rows — keeps the sheet row numbers contiguous
    //    and the DISCOUNT/amount rows fixed at 41/43 with SUM(I26:I40)).
    final itBuf = StringBuffer();
    for (var n = 26; n <= 40; n++) {
      final itemIdx = n - 26;
      if (itemIdx < input.items.length) {
        final it = input.items[itemIdx];
        final total = it.qty * it.price;
        final f = '<f>SUM(G$n*H$n)</f><v>$total</v>';
        itBuf.write('<row r="$n" spans="2:11" ht="20.25" customHeight="1" x14ac:dyDescent="0.25">'
            '<c r="B$n" s="44" t="s"><v>${numIdx[n - 25]}</v></c>'
            '<c r="C$n" s="77" t="s"><v>${descIdx[itemIdx]}</v></c>'
            '<c r="D$n" s="79"/><c r="E$n" s="79"/><c r="F$n" s="80"/>'
            '<c r="G$n" s="55"><v>${it.qty}</v></c>'
            '<c r="H$n" s="67"><v>${it.price}</v></c>'
            '<c r="I$n" s="46">$f</c></row>');
      } else {
        itBuf.write('<row r="$n" spans="2:11" ht="20.25" customHeight="1" x14ac:dyDescent="0.25">'
            '<c r="B$n" s="44" t="s"><v>${numIdx[n - 25]}</v></c>'
            '<c r="C$n" s="77"/><c r="D$n" s="79"/><c r="E$n" s="79"/><c r="F$n" s="80"/>'
            '<c r="G$n" s="55"/><c r="H$n" s="67"/><c r="I$n" s="46"/></row>');
      }
    }
    final itemsXml = itBuf.toString();
    xml = xml.replaceFirst(
        RegExp(r'<row r="26"[^>]*>.*?<row r="39"[^>]*>.*?</row>',
            dotAll: true),
        itemsXml);

    files['xl/worksheets/sheet1.xml'] = utf8.encode(xml);

    // ---------- workbook.xml ----------
    var wb = utf8.decode(files['xl/workbook.xml']!);
    wb = wb.replaceAll(RegExp('<sheet name="[^"]+" sheetId="\\d+" r:id="rId[23]"/>'), '');
    wb = wb.replaceFirstMapped(
        RegExp(r'<sheet name="046" sheetId="(5)" r:id="(rId1)"/>'),
        (m) => '<sheet name="${input.sheetName}" sheetId="${m.group(1)}" r:id="${m.group(2)}"/>');
    wb = wb.replaceAll(
        RegExp('<definedName[^>]*localSheetId="[12]">.*?</definedName>'), '');
    wb = wb.replaceAllMapped(
        RegExp(r'''(<definedName name="_xlnm.Print_Area" localSheetId="0">)'046'!(\$[A-Z]+\$[0-9]+:\$[A-Z]+\$[0-9]+)(</definedName>)'''),
        (m) => "<definedName name=\"_xlnm.Print_Area\" localSheetId=\"0\">'${input.sheetName}'!${m.group(2)}</definedName>");
    wb = wb.replaceAll(r'$A$1:$J$71', r'$A$1:$J$72');
    wb = wb.replaceAll('activeTab="2"', 'activeTab="0"');
    wb = wb.replaceAll('<calcPr calcId="191029"/>',
        '<calcPr calcId="191029" fullCalcOnLoad="1"/>');
    files['xl/workbook.xml'] = utf8.encode(wb);

    // ---------- workbook rels: drop sheet2/3 + calcChain ----------
    var wr = utf8.decode(files['xl/_rels/workbook.xml.rels']!);
    wr = wr.replaceAll(RegExp('<Relationship Id="rId[237]"[^>]*/>'), '');
    files['xl/_rels/workbook.xml.rels'] = utf8.encode(wr);

    // ---------- content types: drop sheet2/3, drawing2/3, calcChain ----------
    var ct = utf8.decode(files['[Content_Types].xml']!);
    ct = ct.replaceAll(
        RegExp('<Override PartName="/xl/worksheets/sheet[23]\\.xml"[^>]*/>'), '');
    ct = ct.replaceAll(
        RegExp('<Override PartName="/xl/drawings/drawing[23]\\.xml"[^>]*/>'), '');
    ct = ct.replaceAll(
        RegExp('<Override PartName="/xl/calcChain\\.xml"[^>]*/>'), '');
    files['[Content_Types].xml'] = utf8.encode(ct);

    // ---------- app.xml (1 worksheet + 1 named range) ----------
    var app = utf8.decode(files['docProps/app.xml']!);
    app = app.replaceFirstMapped(
        RegExp(r'<vt:vector size="\d+" baseType="variant">.*?</vt:vector>',
            dotAll: true),
        (_) => '<vt:vector size="4" baseType="variant">'
            '<vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>'
            '<vt:variant><vt:i4>1</vt:i4></vt:variant>'
            '<vt:variant><vt:lpstr>Named Ranges</vt:lpstr></vt:variant>'
            '<vt:variant><vt:i4>1</vt:i4></vt:variant></vt:vector>');
    app = app.replaceFirstMapped(
        RegExp(r'<vt:vector size="\d+" baseType="lpstr">.*?</vt:vector>',
            dotAll: true),
        (_) => '<vt:vector size="2" baseType="lpstr">'
            '<vt:lpstr>${input.sheetName}</vt:lpstr>'
            "<vt:lpstr>'${input.sheetName}'!Print_Area</vt:lpstr></vt:vector>");
    files['docProps/app.xml'] = utf8.encode(app);

    // ---------- drop parts (KEEP image1.png + image2.png: both are
    // referenced from sheet1) ----------
    for (final n in const [
      'xl/worksheets/sheet2.xml',
      'xl/worksheets/sheet3.xml',
      'xl/worksheets/_rels/sheet2.xml.rels',
      'xl/worksheets/_rels/sheet3.xml.rels',
      'xl/drawings/drawing2.xml',
      'xl/drawings/drawing3.xml',
      'xl/drawings/_rels/drawing2.xml.rels',
      'xl/drawings/_rels/drawing3.xml.rels',
      'xl/printerSettings/printerSettings2.bin',
      'xl/printerSettings/printerSettings3.bin',
      'xl/calcChain.xml',
    ]) {
      files.remove(n);
    }

    return ZipWriter.store(files);
  }

  static String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}