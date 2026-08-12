import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/cm_docx.dart';
import 'package:jkr_fm_guide/services/cm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1x1 valid images
  const pngB64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  const jpgB64 =
      '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwg'
      'JC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAA'
      'AAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AVN//2Q==';

  CmWorkOrder wo(String id, String floor, List<String> b, List<String> d,
          List<String> a) =>
      CmWorkOrder(
        id: id,
        date: '2026-08-10',
        floor: floor,
        defect: 'AC rosak',
        status: 'closed',
        photosBefore: b,
        photosDuring: d,
        photosAfter: a,
      );

  String part(Archive zip, String name) =>
      utf8.decode(zip.findFile(name)!.content as List<int>);

  test('template report builds with WO details, 3 photos and red date stamps',
      () async {
    final bytes = await CmDocxService.build(
      wo('JKRBG200050023', 'Aras 6', [pngB64], [jpgB64], [pngB64]),
      DateTime(2026, 8, 10),
    );

    expect(bytes.length, greaterThan(2000));
    final head = ByteData.sublistView(bytes);
    expect(head.getUint32(0, Endian.little), 0x04034B50, reason: 'zip header');
    expect(head.getUint32(bytes.length - 22, Endian.little), 0x06054B50,
        reason: 'EOCD');

    final zip = ZipDecoder().decodeBytes(bytes);
    final xml = part(zip, 'word/document.xml');
    final rels = part(zip, 'word/_rels/document.xml.rels');

    // Text fills
    expect(xml, contains('<w:t>JKRBG200050023</w:t>'));
    expect(xml, contains('<w:t>Aras 6</w:t>'));
    expect(xml, contains('<w:t>10/8/2026</w:t>'));
    expect(xml, isNot(contains('JKRBG26002582')));
    expect(xml, isNot(contains('ARAS Aras')));
    expect(xml, isNot(contains('ARAS 23')));

    // Photos: 1 original slot + 2 cloned floating pictures
    expect(xml, contains('r:embed="rId8"'));
    expect(xml, contains('r:embed="rId9"'));
    expect(xml, contains('r:embed="rId10"'));
    expect(xml, contains('name="Picture 5"'));
    expect(xml, contains('name="Picture 6"'));
    expect('r:embed="rId5"'.allMatches(xml).length, 0,
        reason: 'sample photo must be repointed');
    expect('name="Picture 3"'.allMatches(xml).length, 1,
        reason: 'SEBELUM keeps docPr id 3');

    // Red bold date stamps replace every template example date
    expect(xml, isNot(contains('29/07/2026')));
    expect('w:color w:val="C00000"'.allMatches(xml).length, 6,
        reason: '2 stamps (Choice+Fallback) x 3 columns');

    // Media + relationships
    expect(zip.findFile('word/media/image8.png'), isNotNull);
    expect(zip.findFile('word/media/image9.jpeg'), isNotNull);
    expect(zip.findFile('word/media/image10.png'), isNotNull);
    expect(rels, contains('Id="rId8"'));
    expect(rels, contains('Id="rId9"'));
    expect(rels, contains('Id="rId10"'));
    expect(rels, contains('Target="media/image8.png"'));

    final tmp = File('${Directory.systemTemp.path}\\cm_template_test.docx');
    tmp.writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('SAVED ${tmp.path} size=${bytes.length}');
  });

  test('no photos -> template left untouched, no new parts', () async {
    final bytes = await CmDocxService.build(
      wo('JKRBG26002582', '23', const [], const [], const []),
      DateTime(2026, 8, 10),
    );
    final zip = ZipDecoder().decodeBytes(bytes);
    final xml = part(zip, 'word/document.xml');

    expect('29/07/2026'.allMatches(xml).length, 6,
        reason: 'template defaults preserved');
    expect(xml, contains('r:embed="rId5"'));
    expect(xml, isNot(contains('rId8')));
    expect(zip.findFile('word/media/image8.png'), isNull);
    expect(zip.findFile('word/_rels/document.xml.rels'), isNotNull);
  });

  test('demo report with real photos for manual inspection', () async {
    final png = await File('assets/images/logo_cmsb.png').readAsBytes();
    final jpg = await File('assets/images/logo_jkr.jpg').readAsBytes();
    final bytes = await CmDocxService.build(
      wo('JKRBG26002582', 'Aras 6',
          [base64Encode(png)], [base64Encode(jpg)], [base64Encode(png)]),
      DateTime(2026, 8, 10),
    );
    final out = Directory('Directory/CM')..createSync(recursive: true);
    final f = File('${out.path}\\SAMPLE_TEMPLATE_REPORT.docx');
    f.writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('SAVED ${f.path} size=${bytes.length}');
  });
}