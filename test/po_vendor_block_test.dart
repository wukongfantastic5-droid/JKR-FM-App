import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/po_service.dart';
import 'package:jkr_fm_guide/services/quotation_pdf.dart';

void main() {
  final tpl = File('assets/po_mechanical_template.xlsx').readAsBytesSync();

  test('vendor block B9-B12, C17, C19 are written', () {
    final input = PoInput(
      sheetName: 'PO-0054',
      poNumber: 'CMSB/2026/PO-0054',
      term: '60 DAYS',
      attnCakra: 'ZAINALABIDIN BIN CHE HASSAN',
      date: DateTime(2026, 8, 12),
      items: const [PoItem('R22 GAS', 3, 288)],
      vendorLines: const [
        'TWO ADVANCED SDN BHD',
        '27, JALAN 2, TAMAN GEMBIRA,',
        '43500 SEMENYIH,',
        'SELANGOR.',
        'Tel : 012-3839073       FAX : 03-87235911',
      ],
      vendorTel: '012-3839073',
      vendorAttn: 'YH.WONG',
    );
    final out = PoService.build(tpl, input);
    File('${Platform.environment['TEMP']}\\opencode\\repro_po.xlsx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(out);
    final zip = ZipDecoder().decodeBytes(out);
    final strings = _sharedStrings(zip);
    final sheet = utf8.decode(zip.files
        .firstWhere((f) => f.name.endsWith('worksheets/sheet1.xml')).content
        as List<int>);
    String cell(String ref) {
      final m = RegExp('<c r="$ref"[^>]*?(?:/>|>(?:<v>([^<]*)</v>)?</c>)',
              dotAll: true)
          .firstMatch(sheet);
      if (m == null) return '<missing>';
      if (m.group(1) == null) return '<empty>';
      return strings[int.parse(m.group(1)!)];
    }

    print('B9  = ${cell('B9')}');
    print('B10 = ${cell('B10')}');
    print('B11 = ${cell('B11')}');
    print('B12 = ${cell('B12')}');
    print('C17 = ${cell('C17')}');
    print('C19 = ${cell('C19')}');
    expect(cell('B9'), 'TWO ADVANCED SDN BHD');
    expect(cell('B10'), '27, JALAN 2, TAMAN GEMBIRA,');
    expect(cell('B11'), '43500 SEMENYIH,');
    expect(cell('B12'), 'SELANGOR.');
    expect(cell('C17'), '012-3839073');
    expect(cell('C19'), 'YH.WONG');
  });

  test('quotation2 (MEWALITE) -> PO writes vendor, tel and attn', () {
    final pdf = File(
            r'Directory\Purchase Order\quotation2.pdf')
        .readAsBytesSync();
    final q = QuotationPdf.parse(QuotationPdf.extractCells(pdf));
    expect(q.vendor.length, greaterThanOrEqualTo(3));
    expect(q.items.length, 3);
    final tel = PoInput.vendorTelFrom(q.vendor);
    expect(tel, '03-9222 2131/3131');
    final input = PoInput.fromQuotation(
      q,
      sheetName: 'PO-0055',
      poNumber: 'CMSB/2026/PO-0055',
      date: DateTime(2026, 8, 12),
    );
    expect(input.vendorTel, '03-9222 2131/3131');
    final out = PoService.build(tpl, input);
    final zip = ZipDecoder().decodeBytes(out);
    final strings = _sharedStrings(zip);
    final sheet = utf8.decode(zip.files
        .firstWhere((f) => f.name.endsWith('worksheets/sheet1.xml')).content
        as List<int>);
    String cell(String ref) {
      final m = RegExp('<c r="$ref"[^>]*?(?:/>|>(?:<v>([^<]*)</v>)?</c>)',
              dotAll: true)
          .firstMatch(sheet);
      if (m == null) return '<missing>';
      if (m.group(1) == null) return '<empty>';
      return strings[int.parse(m.group(1)!)];
    }

    print('B9  = ${cell('B9')}');
    print('B10 = ${cell('B10')}');
    print('B11 = ${cell('B11')}');
    print('C17 = ${cell('C17')}');
    expect(cell('B9'), '美樺電器有限公司');
    expect(cell('B10'), contains('MEWALITE'));
    expect(cell('B11'), contains('Kuala Lumpur'));
    expect(cell('C17'), '03-9222 2131/3131');
  });
}

List<String> _sharedStrings(Archive zip) {
  final f = zip.files.firstWhere((f) => f.name.endsWith('sharedStrings.xml'));
  final ss = utf8.decode(f.content as List<int>);
  final m = RegExp(r'<sst[^>]*>(.*)</sst>', dotAll: true).firstMatch(ss)!;
  return RegExp(r'<si>(.*?)</si>', dotAll: true)
      .allMatches(m.group(1)!)
      .map((si) => RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
          .allMatches(si.group(1)!)
          .map((m) => m.group(1)!)
          .join()
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>'))
      .toList();
}
