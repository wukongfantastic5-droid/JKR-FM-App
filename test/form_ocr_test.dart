import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/form_ocr_service.dart';

OcrLine l(String text, double x, double y, double w, [double h = 10]) =>
    OcrLine(text, Rect.fromLTWH(x, y, w, h));

void main() {
  test('parses composite form OCR log (device PID 9424)', () {
    final lines = [
      l('Format Arahan Siasatan dan Penyenggaraan Pembaikan', 86, 19, 330),
      l('A Aduan', 25, 42, 30),
      l('Nama Pengadu', 22, 55, 60),
      l('KAMARIZA FAIRUS', 109, 54, 77),
      l('Tarikh & Masa', 24, 71, 53),
      l('31 Ju 2026 09:16', 115, 70, 61),
      l('No. Telefon', 22, 82, 43),
      l('0197910876', 109, 85, 49),
      l('Keterangan', 25, 96, 93),
      l('ENERIRs', 120, 97, 56),
      l('DUAN E AHAWA LAMPU TANDAS KETIGA', 164, 96, 159),
      l('DALAM', 112, 110, 28),
      l('WANITA TIDAK MENYALA HAMPIR2', 178, 106, 140),
      l('MINGGU - ARAS 13', 112, 120, 75),
      l('No. Aset', 25, 135, 31),
      l('B. Arahan Siasatan', 22, 150, 120),
      l('No. Ruj.', 360, 10, 32),
      l('JKRBG26002742', 421, 13, 65),
      l('Status', 363, 27, 23),
      l('OPEN', 422, 27, 22),
      l('Jenis Kerja', 339, 57, 40),
      l('cORRECTIVE', 426, 54, 55),
      l('Kategori Kerja', 340, 70, 52),
      l('ELECTRICAL', 424, 70, 54),
      l('Keutamaan Kerja', 341, 86, 63),
      l('NORMAL', 427, 84, 34),
      l('Lokasi', 340, 108, 22),
      l('G.15.009- TANDAS', 427, 106, 75),
      l('WANITA', 427, 115, 32),
      l('Nama Aset', 341, 135, 40),
      l('G.15.009- TANDAS', 427, 120, 75),
      l('WANITA', 427, 129, 32),
      l('Ditugaskan Kepada', 25, 163, 70),
      l('MENERIMAADUAN BAHAWA LAMPU TANDAS KETIGA', 106, 203, 230),
      l('DALAM TANDAS WANITA TIDAK MENYALA HAMPIR 2', 106, 213, 230),
      l('MINGGU- ARAS 13', 110, 220, 71),
    ];
    final r = FormOcrService.parseLines(lines);
    // ignore: avoid_print
    print('RESULT: $r');
    expect(r.complainerName, 'KAMARIZA FAIRUS');
    expect(r.phone, '0197910876');
    expect(r.dateTime, contains('2026'));
    expect(r.floor, '13');
    expect(r.issueType, 'CORRECTIVE');
    expect(r.workCategory, 'ELECTRICAL');
    expect(r.priority, 'NORMAL');
    expect(r.noRuj, 'JKRBG26002742');
    expect(r.asset, 'G.15.009- TANDAS WANITA');
    expect(r.description,
        'Menerima aduan bahawa lampu tandas ketiga dalam tandas wanita '
        'tidak menyala hampir 2 minggu - aras 13');
    expect(r.description, isNot(contains('No. Ruj')));
  });

  test('parses CMMS-only screenshot (PID 7821)', () {
    final lines = [
      l('No. Ruj.', 360, 10, 32),
      l('JKRBG26002742', 421, 13, 65),
      l('Status', 363, 27, 23),
      l('OPEN', 422, 27, 22),
      l('Jenis Kerja', 339, 57, 40),
      l('cORRECTIVE', 426, 54, 55),
      l('Kategori Kerja', 340, 70, 52),
      l('ELECTRICAL', 424, 70, 54),
      l('Keutamaan Kerja', 341, 86, 63),
      l('NORMAL', 427, 84, 34),
      l('Lokasi', 340, 108, 22),
      l('G.15.009- TANDAS', 427, 106, 75),
      l('WANITA', 427, 115, 32),
      l('Nama Aset', 341, 135, 40),
      l('G.15.009- TANDAS', 427, 120, 75),
      l('WANITA', 427, 129, 32),
      l('MENERIMAADUAN BAHAWA LAMPU TANDAS KETIGA', 106, 203, 230),
      l('DALAM TANDAS WANITA TIDAK MENYALA HAMPIR 2', 106, 213, 230),
      l('MINGGU- ARAS 13', 110, 220, 71),
    ];
    final r = FormOcrService.parseLines(lines);
    // ignore: avoid_print
    print('RESULT: $r');
    expect(r.issueType, 'CORRECTIVE');
    expect(r.workCategory, 'ELECTRICAL');
    expect(r.priority, 'NORMAL');
    expect(r.noRuj, 'JKRBG26002742');
    expect(r.floor, '13');
    expect(r.description,
        'Menerima aduan bahawa lampu tandas ketiga dalam tandas wanita '
        'tidak menyala hampir 2 minggu - aras 13');
    expect(r.asset, 'G.15.009- TANDAS WANITA');
  });

  test('parses BORANG ARAHAN SIASATAN screenshot (gambar/1.jpeg, PID 23071)', () {
    final lines = [
      l('|A. Aduan', 26, 41, 33),
      l('Nama Pengadu', 28, 57, 56),
      l('Tarikh & Masa', 29, 74, 52),
      l('No Telefon', 28, 87, 41),
      l('Keterangan', 26, 105, 45),
      l('No. Aset', 28, 126, 32),
      l('B. Arahan Siasatarn', 26, 141, 74),
      l('Diterima Oleh', 29, 158, 48),
      l('Keterangan', 28, 200, 43),
      l('Tarikh /Masa', 29, 225, 49),
      l('Format Arahan Siasatan dan Penyenggaraan Pembaikan', 90, 21, 211),
      l('BORANG ARAHAN SIASATAN &', 141, 0, 125),
      l('|CDPK', 113, 58, 26),
      l('30 Ju 2026 15:47', 116, 74, 66),
      l('o00-0000000', 116, 88, 49),
      l('SUIS LAMPU DI TANDAS OKU NAK TERCABUT- ARAS', 116, 103, 213),
      l('31 -ADUAN JKR: PUAN SHAFHAN SHAHIRAH', 116, 109, 180),
      l('BINTI', 148, 154, 17),
      l('Ditugaskan Kepada', 190, 159, 70),
      l('No. Utk Dihubungi', 190, 181, 67),
      l('30 Jul 2026 15:47', 110, 225, 65),
      l("0'", 306, 0, 8),
      l('ADUAN JKR: PUAN SHAFHAN SHAHIRAH', 109, 205, 165),
      l('SUIS LAMPU DI TANDAS OKU NAK TERCABUT-ARAS 31 -', 114, 193, 224),
      l('AAN PEMBAIKAN', 330, 0, 69),
      l('No. Ruj.', 367, 15, 30),
      l('Status', 367, 29, 23),
      l('Jenis Kerja', 344, 58, 41),
      l('Kategori Kerja', 344, 72, 52),
      l('Keutamaan Kerja', 344, 86, 64),
      l('Lokasi', 345, 108, 24),
      l('Nama Aset', 344, 126, 41),
      l('Tarikh / Masa', 351, 162, 49),
      l('Tandatangan', 349, 193, 47),
      l('Pengadu', 351, 205, 33),
      l('Cap Nama &', 351, 220, 47),
      l('Jawatan', 351, 230, 31),
      l('JKRBG26002720', 423, 12, 66),
      l('OPEN', 425, 27, 21),
      l('CORRECTIVE', 432, 59, 54),
      l('ELECTRICAL', 432, 72, 49),
      l('NORMAL', 432, 88, 35),
      l('G.33.008- TANDAS', 431, 102, 74),
      l('OKU', 432, 112, 17),
    ];
    final r = FormOcrService.parseLines(lines);
    // ignore: avoid_print
    print('RESULT: $r');
    expect(r.noRuj, 'JKRBG26002720');
    expect(r.floor, '31');
    expect(r.issueType, 'CORRECTIVE');
    expect(r.workCategory, 'ELECTRICAL');
    expect(r.priority, 'NORMAL');
    expect(r.asset, 'G.33.008- TANDAS OKU');
    expect(r.description,
        'Suis lampu di tandas oku nak tercabut - aras 31 '
        'aduan jkr: puan shafhan shahirah');
  });

  test('parses gambar/3.jpeg: description lines ABOVE the Keterangan label (PID 8321)', () {
    // The "Keterangan" label is at y=137 (x=17) but the FIRST line of the
    // complaint text sits ABOVE it at y=115 (label vertically centred in a
    // tall cell). The band must extend above the label to capture it.
    OcrLine r3(double x, double y, double w, String t) => OcrLine(t, Rect.fromLTWH(x, y, w, 7));
    final lines = [
      r3(19, 45, 32, 'A Aduan'),
      r3(19, 61, 58, 'Nama Pengadu'),
      r3(20, 81, 52, 'Tarikh & Masa'),
      r3(19, 100, 42, 'No. Telefon'),
      r3(17, 137, 45, 'Keterangan'),
      r3(20, 179, 31, 'No. Aset'),
      r3(17, 192, 74, 'B. Arahan Siasatan'),
      r3(17, 211, 53, 'Diterima Oleh'),
      r3(19, 271, 43, 'Keterangan'),
      r3(20, 312, 47, 'Tarikh / Masa'),
      r3(107, 62, 34, 'maisarah'),
      r3(107, 81, 65, '31 Ju 2026 16:01'),
      r3(107, 115, 226, 'KEDUDUKAN ANGLE BLIND SPOT MIRORR TIDAK TEPAT.'),
      r3(107, 125, 221, 'KERETA YANG BERGERAK NAIK TIDAK DAPAT MELIHAT'),
      r3(100, 206, 55, 'INSIYAH BINTI'),
      r3(100, 216, 42, 'MUHAMAD'),
      r3(100, 293, 49, '5, 5A DAN6'),
      r3(302, 0, 88, '0 AAN PEMBAIKAN'),
      r3(178, 210, 75, 'Ditugaskan Kepada'),
      r3(97, 314, 69, '|31 Jul 2026 16:03'),
      r3(111, 133, 201, 'KERETA YANG BERGERAK TURUN. MOHON SEMAK'),
      r3(107, 139, 260, 'UNTUK TINGKAT YANG LAIN KERANA DIDAPATI MASALAH LOasi'),
      r3(107, 152, 229, 'YANG SAMA TERJADI BERMULA DARI RUANG PARKIR 4A,'),
      r3(107, 161, 48, '5, 5A DAN6'),
      r3(181, 233, 67, 'No. Utk Dihubungi'),
      r3(101, 247, 225, 'KEDUDUKAN ANGLE BLIND SPOT MIRORR TIDAK TEPAT.'),
      r3(101, 257, 221, 'KERETA YANG BERGERAK NAIK TIDAK DAPAT MELIHAT'),
      r3(101, 267, 205, 'KERETA YANG BERGERAK TURUN. MOHON SEMAK'),
      r3(101, 276, 229, 'UNTUK TINGKAT YANG LAIN KERANA DIDAPATI MASALAH'),
      r3(101, 286, 230, 'YANG SAMA TERJADI BERMULA DARI RUANG PARKIR 4A,'),
      r3(358, 18, 29, 'No. Ruj.'),
      r3(358, 32, 23, 'Status'),
      r3(343, 60, 43, 'Jenis Kerja'),
      r3(342, 77, 55, 'Kategori Kerja'),
      r3(346, 101, 63, 'Keutamaan Kerja'),
      r3(349, 177, 38, 'Nama Aset'),
      r3(342, 213, 49, 'Tarikh /Masa'),
      r3(342, 267, 48, 'Tandatangan'),
      r3(342, 276, 33, 'Pengadu'),
      r3(342, 306, 45, 'Cap Nama &'),
      r3(344, 320, 26, 'Iasatar'),
      r3(416, 18, 65, 'JKRBG2B002803'),
      r3(416, 32, 23, 'OPEN'),
      r3(430, 59, 56, 'cORRECTIVE'),
      r3(433, 77, 39, 'CIVIL AND'),
      r3(430, 84, 53, 'STRUCTURE'),
      r3(433, 98, 33, 'NORMAL'),
      r3(433, 128, 36, 'G.02.061.'),
      r3(429, 137, 65, 'RUANG PARKIR'),
      r3(430, 147, 18, 'PAA .'),
    ];
    final r = FormOcrService.parseLines(lines);
    // ignore: avoid_print
    print('RESULT 3.jpeg: $r');
    expect(r.noRuj, 'JKRBG2B002803');
    expect(r.dateTime, '31 Ju 2026 16:01');
    expect(r.issueType, 'CORRECTIVE');
    expect(r.workCategory, 'CIVIL');
    expect(r.priority, 'NORMAL');
    // No ARAS field on this form — the floor is inferred from the
    // description ("...BERMULA DARI RUANG PARKIR 4A," → P4A).
    expect(r.floor, 'P4A');
    expect(r.asset, 'G.02.061. RUANG PARKIR');
    // "maisarah" is the value read in the "Nama Pengadu" cell of this form
    // ("INSIYAH BINTI" is the Ditugaskan Kepada person, only a fallback).
    expect(r.complainerName, 'maisarah');
    expect(r.phone, '');
    expect(r.description,
        'Kedudukan angle blind spot mirror tidak tepat. kereta yang bergerak '
        'naik tidak dapat melihat kereta yang bergerak turun. mohon semak '
        'untuk tingkat yang lain kerana didapati masalah yang sama terjadi '
        'bermula dari ruang parkir 4a, 5, 5a dan 6');
    expect(r.description, isNot(contains('LOasi')));
    expect(r.description, isNot(contains('INSIYAH')));
    expect(r.description, isNot(contains('JKRBG')));
  });

  test('parses gambar/3.jpeg variant: Tarikh row MERGED with first description line', () {
    // On some scans OCR reads the date value and the first line of the
    // complaint as ONE line ("31 Ju 2026 16:01 KEDUDUKAN ANGLE ...") — the
    // date part must be stripped and the description kept in full.
    OcrLine r3(double x, double y, double w, String t) => OcrLine(t, Rect.fromLTWH(x, y, w, 7));
    final lines = [
      r3(19, 45, 32, 'A Aduan'),
      r3(19, 61, 58, 'Nama Pengadu'),
      r3(20, 81, 52, 'Tarikh & Masa'),
      r3(19, 100, 42, 'No. Telefon'),
      r3(17, 137, 45, 'Keterangan'),
      r3(20, 179, 31, 'No. Aset'),
      r3(17, 192, 74, 'B. Arahan Siasatan'),
      r3(17, 211, 53, 'Diterima Oleh'),
      r3(19, 271, 43, 'Keterangan'),
      r3(20, 312, 47, 'Tarikh / Masa'),
      r3(107, 62, 34, 'maisarah'),
      OcrLine('31 Ju 2026 16:01 KEDUDUKAN ANGLE BLIND SPOT MIRORR TIDAK TEPAT.',
          Rect.fromLTWH(107, 81, 330, 40)),
      r3(107, 125, 221, 'KERETA YANG BERGERAK NAIK TIDAK DAPAT MELIHAT'),
      r3(100, 206, 55, 'INSIYAH BINTI'),
      r3(100, 216, 42, 'MUHAMAD'),
      r3(178, 210, 75, 'Ditugaskan Kepada'),
      r3(111, 133, 201, 'KERETA YANG BERGERAK TURUN. MOHON SEMAK'),
      r3(107, 139, 260, 'UNTUK TINGKAT YANG LAIN KERANA DIDAPATI MASALAH LOasi'),
      r3(107, 152, 229, 'YANG SAMA TERJADI BERMULA DARI RUANG PARKIR 4A,'),
      r3(107, 161, 48, '5, 5A DAN6'),
      r3(181, 233, 67, 'No. Utk Dihubungi'),
      r3(358, 18, 29, 'No. Ruj.'),
      r3(358, 32, 23, 'Status'),
      r3(343, 60, 43, 'Jenis Kerja'),
      r3(342, 77, 55, 'Kategori Kerja'),
      r3(346, 101, 63, 'Keutamaan Kerja'),
      r3(349, 177, 38, 'Nama Aset'),
      r3(342, 213, 49, 'Tarikh /Masa'),
      r3(342, 267, 48, 'Tandatangan'),
      r3(342, 276, 33, 'Pengadu'),
      r3(342, 306, 45, 'Cap Nama &'),
      r3(344, 320, 26, 'Iasatar'),
      r3(416, 18, 65, 'JKRBG2B002803'),
      r3(416, 32, 23, 'OPEN'),
      r3(430, 59, 56, 'cORRECTIVE'),
      r3(433, 77, 39, 'CIVIL AND'),
      r3(430, 84, 53, 'STRUCTURE'),
      r3(433, 98, 33, 'NORMAL'),
      r3(433, 128, 36, 'G.02.061.'),
      r3(429, 137, 65, 'RUANG PARKIR'),
      r3(430, 147, 18, 'PAA .'),
    ];
    final r = FormOcrService.parseLines(lines);
    // ignore: avoid_print
    print('RESULT 3.jpeg merged: $r');
    expect(r.floor, 'P4A');
    expect(r.asset, 'G.02.061. RUANG PARKIR');
    expect(r.description,
        'Kedudukan angle blind spot mirror tidak tepat. kereta yang bergerak '
        'naik tidak dapat melihat kereta yang bergerak turun. mohon semak '
        'untuk tingkat yang lain kerana didapati masalah yang sama terjadi '
        'bermula dari ruang parkir 4a, 5, 5a dan 6');
    expect(r.description, isNot(contains('2026')));
  });

  test('parses the same form zoomed 2x (resolution/position independent)', () {
    final base = [
      l('|A. Aduan', 26, 41, 33),
      l('Nama Pengadu', 28, 57, 56),
      l('Tarikh & Masa', 29, 74, 52),
      l('No Telefon', 28, 87, 41),
      l('Keterangan', 26, 105, 45),
      l('No. Aset', 28, 126, 32),
      l('B. Arahan Siasatarn', 26, 141, 74),
      l('Diterima Oleh', 29, 158, 48),
      l('Keterangan', 28, 200, 43),
      l('Tarikh /Masa', 29, 225, 49),
      l('Format Arahan Siasatan dan Penyenggaraan Pembaikan', 90, 21, 211),
      l('BORANG ARAHAN SIASATAN &', 141, 0, 125),
      l('|CDPK', 113, 58, 26),
      l('30 Ju 2026 15:47', 116, 74, 66),
      l('o00-0000000', 116, 88, 49),
      l('SUIS LAMPU DI TANDAS OKU NAK TERCABUT- ARAS', 116, 103, 213),
      l('31 -ADUAN JKR: PUAN SHAFHAN SHAHIRAH', 116, 109, 180),
      l('BINTI', 148, 154, 17),
      l('Ditugaskan Kepada', 190, 159, 70),
      l('No. Utk Dihubungi', 190, 181, 67),
      l('30 Jul 2026 15:47', 110, 225, 65),
      l("0'", 306, 0, 8),
      l('ADUAN JKR: PUAN SHAFHAN SHAHIRAH', 109, 205, 165),
      l('SUIS LAMPU DI TANDAS OKU NAK TERCABUT-ARAS 31 -', 114, 193, 224),
      l('AAN PEMBAIKAN', 330, 0, 69),
      l('No. Ruj.', 367, 15, 30),
      l('Status', 367, 29, 23),
      l('Jenis Kerja', 344, 58, 41),
      l('Kategori Kerja', 344, 72, 52),
      l('Keutamaan Kerja', 344, 86, 64),
      l('Lokasi', 345, 108, 24),
      l('Nama Aset', 344, 126, 41),
      l('Tarikh / Masa', 351, 162, 49),
      l('Tandatangan', 349, 193, 47),
      l('Pengadu', 351, 205, 33),
      l('Cap Nama &', 351, 220, 47),
      l('Jawatan', 351, 230, 31),
      l('JKRBG26002720', 423, 12, 66),
      l('OPEN', 425, 27, 21),
      l('CORRECTIVE', 432, 59, 54),
      l('ELECTRICAL', 432, 72, 49),
      l('NORMAL', 432, 88, 35),
      l('G.33.008- TANDAS', 431, 102, 74),
      l('OKU', 432, 112, 17),
    ];
    final zoomed = base
        .map((l0) => OcrLine(l0.text, Rect.fromLTWH(
            l0.box.left * 2, l0.box.top * 2, l0.box.width * 2, l0.box.height * 2)))
        .toList();
    final r = FormOcrService.parseLines(zoomed);
    // ignore: avoid_print
    print('ZOOMED: $r');
    expect(r.noRuj, 'JKRBG26002720');
    expect(r.floor, '31');
    expect(r.asset, 'G.33.008- TANDAS OKU');
    expect(r.description,
        'Suis lampu di tandas oku nak tercabut - aras 31 '
        'aduan jkr: puan shafhan shahirah');
  });
}
