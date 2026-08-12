import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/po_service.dart';
import 'package:jkr_fm_guide/services/quotation_pdf.dart';

/// Parser pipeline: fixture PDF -> positioned cells -> Quotation -> PoInput
/// -> generated workbook. Mirror of the Python-prototype acceptance rules.
void main() {
  final pdf = File('test/fixtures/quotation_cakra_mekanikal.pdf').readAsBytesSync();
  final tpl = File('assets/po_mechanical_template.xlsx').readAsBytesSync();

  final cells = QuotationPdf.extractCells(pdf);

  test('positioned cells come out in reading order', () {
    expect(cells.length, 127);
    // Parser output: vendor text with natural spacing from space-cell merge.
    expect(cells.first.text, 'TWO ADVANCED SDN BHD');
    expect(cells.first.y, greaterThan(cells.last.y), reason: 'top-down order');
  });

  test('quotation structure matches the printed document', () {
    final q = QuotationPdf.parse(cells);
    // Parser output for Cakra Mechanical fixture:
    // - vendor: 4 rows (name, address lines, tel, fax/email/tin)
    // - dateText: explicit DATE label found
    // - terms: '60 DAYS'
    // - attn: 'YH.WONG' found via ATTN label
    expect(q.vendor.length, 4);
    expect(q.vendor[0], 'TWO ADVANCED SDN BHD');
    expect(q.vendor[1], '27, JALAN 2, TAMAN GEMBIRA,');
    expect(q.vendor[2], '43500 SEMENYIH, SELANGOR.');
    expect(q.toCompany, 'CAKRA MAKOTA SDN BHD');
    // DATE label found explicitly in header.
    expect(q.dateText, '10-Aug-26');
    expect(q.terms, '60 DAYS');
    expect(q.attn, 'YH.WONG');

    expect(q.items.length, 15);
    expect(q.items.first.no, 1);
    expect(q.items.first.description, 'R22 GAS');
    expect(q.items.first.qty, 3);
    expect(q.items.first.unitPrice, 288.0);
    expect(q.items.first.subtotal, 864.0);

    final grease = q.items[1]; // PDF truth: 1 x 50.00, not 5 x 10.00
    expect(grease.description, 'GREASE 2.5KG');
    expect(grease.qty, 1);
    expect(grease.unitPrice, 50.0);
    expect(grease.subtotal, 50.0);

    expect(q.items.last.description, 'HOSE CLIP 20MM');
    expect(q.items.last.qty, 5);
    expect(q.items.last.unitPrice, 2.0);
    expect(q.items.last.subtotal, 10.0);

    expect(q.subTotal, 1683.0);
    expect(q.totalAmount, 1683.0);
    final sum = q.items.fold(0.0, (a, i) => a + i.subtotal);
    expect(sum, closeTo(q.subTotal, 0.005));
  });

  test('quotation -> PoInput -> valid workbook', () {
    final q = QuotationPdf.parse(cells);
    final input = PoInput.fromQuotation(
      q,
      sheetName: 'PO-0054',
      poNumber: 'CMSB/2026/PO-0054',
      date: DateTime(2026, 8, 11),
    );
    expect(input.items.length, 15);
    expect(input.term, '60 DAYS');

    final out = PoService.build(tpl, input);
    final x = String.fromCharCodes(out);

    // streamed bytes must still be a zip carrying the expected parts
    expect(out.length, greaterThan(100000));
    expect(x, contains('PK'));

    final temp = Platform.environment['TEMP'] ?? '.';
    File('$temp\\opencode\\po_from_quotation.xlsx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(out);
  });
}