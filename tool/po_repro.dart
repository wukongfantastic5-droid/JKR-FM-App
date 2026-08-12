import 'dart:convert';
import 'dart:io';
import 'package:jkr_fm_guide/services/po_service.dart';

/// Reproduces PoService.build with the asset template and a quotation1-like
/// PoInput, then dumps the vendor block of the result.
void main() {
  final tpl = File('assets/po_mechanical_template.xlsx').readAsBytesSync();
  final input = PoInput(
    sheetName: 'PO-0054',
    poNumber: 'CMSB/2026/PO-0054',
    term: '60 DAYS',
    attnCakra: 'ZAINALABIDIN BIN CHE HASSAN',
    date: DateTime(2026, 8, 12),
    items: const [
      PoItem('R22 GAS', 3, 288),
      PoItem('GREASE 2.5KG', 1, 50),
      PoItem('WELDING ROD', 4, 3.5),
    ],
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
  File(r'C:\Users\zaina\AppData\Local\Temp\opencode\repro_po.xlsx')
      .writeAsBytesSync(out);
  print('built OK, ${out.length} bytes');
}
