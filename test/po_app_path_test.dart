import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/po_service.dart';
import 'package:jkr_fm_guide/services/quotation_pdf.dart';

/// Reproduces the on-device path: template loaded via rootBundle, input
/// exactly as the PoScreen would build it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app path: rootBundle template + screen-shaped PoInput', () async {
    final bytes = await rootBundle.load('assets/po_mechanical_template.xlsx');
    expect(bytes.lengthInBytes, greaterThan(60000),
        reason: 'template must be reachable through rootBundle');

    final pdf =
        File('test/fixtures/quotation_cakra_mekanikal.pdf').readAsBytesSync();
    final q = QuotationPdf.parse(QuotationPdf.extractCells(pdf));
    final input = PoInput.fromQuotation(
      q,
      sheetName: 'PO-0054',
      poNumber: 'CMSB/2026/PO-0054',
      date: DateTime.now(),
    );

    final out = PoService.build(bytes.buffer.asUint8List(), input);
    expect(out.length, greaterThan(100000));
    expect(out.sublist(0, 2), [0x50, 0x4B], reason: 'zip magic PK');
  });
}