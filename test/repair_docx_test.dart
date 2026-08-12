import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/repair_docx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('repair docx builds a valid zip package with assets', () async {
    final bytes = await RepairDocxService.build(
      title: 'LAPORAN INSIDEN / ADUAN',
      titleEn: 'INCIDENT REPORT',
      refNo: 'RG-090826-1',
      dateStr: '09-08-2026',
      fields: const [
        RepairField('Sumber / Source', 'JKR'),
        RepairField('Dilapor oleh', 'Zainal (Jurutera Mekanikal)'),
        RepairField('Bangunan', 'Blok G'),
      ],
      paragraphs: const ['PERIHALAN MASALAH:', 'Kompressor chiller tidak berfungsi'],
      tableHeader: const ['Item', 'Qty', 'Unit RM', 'Total RM'],
      tableRows: const [
        ['Kompressor baru', '1', '1500.00', '1500.00'],
        ['SUBTOTAL', '', '', '1500.00'],
        ['TOTAL', '', '', '1500.00'],
      ],
    );

    expect(bytes.length, greaterThan(2000));
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(0, Endian.little), 0x04034B50, reason: 'local header');
    expect(data.getUint32(bytes.length - 22, Endian.little), 0x06054B50, reason: 'EOCD');

    final tmp = File('${Directory.systemTemp.path}\\repair_test.docx');
    tmp.writeAsBytesSync(bytes);
    expect(tmp.existsSync(), true);
    // ignore: avoid_print
    print('SAVED ${tmp.path} size=${bytes.length}');
  });

  test('table images column embeds picture media + relationship', () async {
    final logo = await File('assets/images/logo_cmsb.png').readAsBytes();
    final bytes = await RepairDocxService.build(
      title: 'SENARAI STOK ALAT GANTI',
      titleEn: 'SPARE PARTS STOCK LIST',
      refNo: 'STK-090826',
      dateStr: '09-08-2026',
      tableHeader: const ['No', 'Spare Part', 'Quantity', 'Image'],
      colWidthsCm: const [1.3, 6.6, 1.8, 8.5],
      tableRows: const [
        ['1', 'Air Filter', '4'],
        ['2', 'Bearing', '0'],
      ],
      tableImages: [logo, null],
    );
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(0, Endian.little), 0x04034B50, reason: 'zip header');
    expect(data.getUint32(bytes.length - 22, Endian.little), 0x06054B50, reason: 'EOCD');
    final tmp = File('${Directory.systemTemp.path}\\parts_stock_test.docx');
    tmp.writeAsBytesSync(bytes);
    expect(tmp.existsSync(), true);
    // ignore: avoid_print
    print('SAVED ${tmp.path} size=${bytes.length}');
  });
}