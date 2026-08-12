import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/po_service.dart';

/// Structural verification of the Dart port against the Python prototype
/// rules (the file itself was additionally validated in Excel COM).
void main() {
  final tpl = File('assets/po_mechanical_template.xlsx').readAsBytesSync();

  const items = [
    PoItem('R22 GAS', 3, 288.0),
    PoItem('GREASE 2.5KG', 5, 10.0),
    PoItem('WELDING ROD', 4, 3.5),
    PoItem('MAPP GAS', 2, 26.0),
    PoItem('INSULATION 1/2"X3/8"', 4, 3.2),
    PoItem('COPPER 1/4"X0.61X15M', 1, 131.0),
    PoItem('COPPER 3/8"X0.61X15M', 1, 190.0),
    PoItem('PVC CABLE 4.0MM RED', 1, 11.0),
    PoItem('PVC CABLE 4.0MM YELLOW', 1, 3.2),
    PoItem('PVC CABLE 4.0MM BLUE', 1, 3.0),
    PoItem('ACSON DRAIN PUMP EASI FLO55', 1, 240.0),
    PoItem('WD 40', 3, 19.0),
    PoItem('ABS GUM 500GM', 1, 25.0),
    PoItem('PVC GUM 500GM', 1, 20.0),
    PoItem('HOSE CLIP 20MM', 5, 2.0),
  ];

  final input = PoInput(
    sheetName: 'PO-0054',
    poNumber: 'CMSB/2026/PO-0054',
    term: '60 DAYS',
    attnCakra: 'ZAINALABIDIN BIN CHE HASSAN',
    date: DateTime(2026, 8, 11),
    items: items,
  );

  test('generated workbook matches the verified prototype shape', () {
    final out = PoService.build(tpl, input);
    final z = ZipDecoder().decodeBytes(out);

    // parts that must exist / not exist
    expect(z.findFile('xl/worksheets/sheet1.xml'), isNotNull);
    expect(z.findFile('xl/worksheets/sheet2.xml'), isNull);
    expect(z.findFile('xl/worksheets/sheet3.xml'), isNull);
    expect(z.findFile('xl/calcChain.xml'), isNull);
    expect(z.findFile('xl/drawings/drawing2.xml'), isNull);
    expect(z.findFile('xl/media/image1.png'), isNotNull,
        reason: 'image1.png is referenced from sheet1 rels rId4');
    expect(z.findFile('xl/media/image2.png'), isNotNull);

    // workbook: single sheet PO-0054 + print area renamed + no stale refs
    final wb = utf8.decode(z.findFile('xl/workbook.xml')!.content as List<int>);
    expect(wb, contains('<sheet name="PO-0054" sheetId="5" r:id="rId1"/>'));
    expect(wb, isNot(contains('rId2')), reason: 'sheet2/3 rels removed');
    expect(wb, isNot(contains('rId3')));
    expect(wb, isNot(contains('047')));
    expect(wb, isNot(contains('051')));
    expect(wb, contains("localSheetId=\"0\">'PO-0054'!\$A\$1:\$J\$72"));
    expect(wb, contains('activeTab="0"'));
    expect(wb, contains('fullCalcOnLoad="1"'));

    final wbRels =
        utf8.decode(z.findFile('xl/_rels/workbook.xml.rels')!.content as List<int>);
    expect(wbRels, isNot(contains('rId2')));
    expect(wbRels, isNot(contains('rId3')));
    expect(wbRels, isNot(contains('rId7')));

    final ct = utf8.decode(z.findFile('[Content_Types].xml')!.content as List<int>);
    expect(ct, isNot(contains('sheet2.xml')));
    expect(ct, isNot(contains('sheet3.xml')));
    expect(ct, isNot(contains('calcChain')));

    // sheet1: rows 2..72 contiguous, dimensions/fonts/formulas correct
    final x = utf8.decode(z.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(x, contains('<dimension ref="A2:K72"/>'));
    expect(x, contains('<v>46245</v>'), reason: '11/08/2026 serial');
    expect(x, contains('<f>SUM(I26:I40)</f>'));
    expect(x, contains('<f>SUM(I41)</f>'));
    expect(x, isNot(contains('SUM(I26:I39)')));
    for (var r = 2; r <= 72; r++) {
      expect(x.contains('<row r="$r"'), isTrue, reason: 'row $r must exist');
    }
    // 15 filled items + shared string refs
    expect(x, contains('<c r="C26" s="77" t="s">'));
    expect(x, contains('<c r="C40" s="77" t="s">'));
    expect(RegExp('<c r="H[0-9]+" s="67"><v>').allMatches(x).length, greaterThanOrEqualTo(15));
    for (final it in items) {
      expect(x, isNot(contains('${poesc(it.description)}<')), reason: 'descriptions must be shared-string idx');
    }

    // sharedStrings: exactly one <si> wrapper, attributes consistent
    final sst = utf8.decode(z.findFile('xl/sharedStrings.xml')!.content as List<int>);
    expect(sst, isNot(contains('<si><si>')));
    final countAttr = int.parse(RegExp(r'count="(\d+)"').firstMatch(sst)!.group(1)!);
    final uniqueAttr =
        int.parse(RegExp(r'uniqueCount="(\d+)"').firstMatch(sst)!.group(1)!);
    final siCount = RegExp('<si>').allMatches(sst).length;
    expect(uniqueAttr, siCount);
    expect(countAttr, greaterThanOrEqualTo(uniqueAttr));
    expect(sst, contains('<t>CMSB/2026/PO-0054</t>'));
    expect(sst, contains('<t>60 DAYS</t>'));
    expect(sst, contains('<t>ZAINALABIDIN BIN CHE HASSAN</t>'));
    expect(sst, contains('<t>HOSE CLIP 20MM</t>'));

    // app.xml vectors sized to their contents
    final app = utf8.decode(z.findFile('docProps/app.xml')!.content as List<int>);
    expect(app, contains('<vt:vector size="4" baseType="variant">'));
    expect(app, contains('<vt:i4>1</vt:i4>'));
    expect(app, contains('<vt:vector size="2" baseType="lpstr">'));
    expect(app, contains('<vt:lpstr>PO-0054</vt:lpstr>'));

    // dump for the Excel COM check
    final temp = Platform.environment['TEMP'] ?? '.';
    File('$temp\\opencode\\po_dart.xlsx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(out);
  });
}

String poesc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');