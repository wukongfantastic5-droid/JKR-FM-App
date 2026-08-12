import 'package:flutter_test/flutter_test.dart';

import 'package:jkr_fm_guide/screens/qr_scan_screen.dart';

void main() {
  test('parses asset QR payload', () {
    final r = QrScanResult.parse(
        'JKR FM ASSET\nFloor: L5\nSystem: 1.0\nType: Lift Motor\nQty: 2');
    expect(r, isNotNull);
    expect(r!.floor, 'L5');
    expect(r.system, '1.0');
    expect(r.type, 'Lift Motor');
    expect(r.qty, 2);
  });

  test('tolerates missing fields', () {
    final r = QrScanResult.parse('JKR FM ASSET\nType: AHU-01');
    expect(r, isNotNull);
    expect(r!.type, 'AHU-01');
    expect(r.floor, '');
    expect(r.qty, 0);
  });

  test('rejects non-sticker codes', () {
    expect(QrScanResult.parse('https://example.com/foo'), isNull);
  });
}