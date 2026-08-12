import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/excel_service.dart';

void main() {
  test('xlsx builds a valid zip workbook', () async {
    final bytes = await ExcelService.build([
      ExcelSheet(
        name: 'Complaints',
        headers: const ['No', 'Complainer', 'Floor', 'Issue', 'Status'],
        rows: [
          ['1', 'Zainal', 'Blok G', 'Aircond rosak', 'open'],
          ['2', 'Ahmad', 'Blok B09', 'Lift berhenti', 'closed'],
        ],
      ),
      ExcelSheet(
        name: 'Inventory',
        headers: const ['Item', 'Qty'],
        rows: [
          ['Bearing', '12'],
          ['Price', '1500.50'],
        ],
      ),
    ]);

    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(0, Endian.little), 0x04034B50, reason: 'local header');
    expect(data.getUint32(bytes.length - 22, Endian.little), 0x06054B50, reason: 'EOCD');

    final tmp = File('${Directory.systemTemp.path}\\excel_test.xlsx');
    tmp.writeAsBytesSync(bytes);
    expect(tmp.existsSync(), true);
    // ignore: avoid_print
    print('SAVED ${tmp.path} size=${bytes.length}');
  });
}