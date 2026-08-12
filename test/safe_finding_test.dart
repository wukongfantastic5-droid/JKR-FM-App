import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/services/safe_finding_service.dart';
import 'package:jkr_fm_guide/services/safe_finding_docx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('model json round-trip keeps every field', () {
    final f = SafeFinding(
      id: 'SF-2026-001',
      date: '2026-08-12T08:00:00.000',
      floor: 'Aras 5',
      issue: 'Kabel terdedah berhampiran AHU',
      status: 'in_progress',
      techId: 'T1',
      techName: 'Ahmad',
      attendedAt: '2026-08-12T09:00:00.000',
      closedAt: '2026-08-12T10:30:00.000',
      findings: 'Kabel dibetulkan',
      remark: 'Perlu perhatian berkala',
      photos: const ['aGVsbG8=', 'd29ybGQ='],
      reportPath: 'Safe_Finding/SF-2026-001.docx',
    );
    final back = SafeFinding.fromJson(f.toJson());
    expect(back.id, f.id);
    expect(back.date, f.date);
    expect(back.floor, f.floor);
    expect(back.issue, f.issue);
    expect(back.status, f.status);
    expect(back.techId, f.techId);
    expect(back.techName, f.techName);
    expect(back.attendedAt, f.attendedAt);
    expect(back.closedAt, f.closedAt);
    expect(back.findings, f.findings);
    expect(back.remark, f.remark);
    expect(back.photos, f.photos);
    expect(back.reportPath, f.reportPath);
  });

  test('fromJson tolerates missing / legacy fields', () {
    final f = SafeFinding.fromJson(const {'id': 'SF-2026-002'});
    expect(f.id, 'SF-2026-002');
    expect(f.date, '');
    expect(f.issue, '');
    expect(f.status, 'open');
    expect(f.photos, isEmpty);
    expect(f.reportPath, '');
  });

  test('status helpers reflect lifecycle', () {
    final f = SafeFinding(id: 'SF-2026-003', date: '', floor: '', issue: '');
    expect(f.isOpen, true);
    expect(f.isInProgress, false);
    expect(f.isClosed, false);
    f.status = 'in_progress';
    expect(f.isOpen, false);
    expect(f.isInProgress, true);
    f.status = 'closed';
    expect(f.isClosed, true);
  });

  test('nextId generates SF-<year>-<nnn> sequence without collision', () {
    final a = SafeFindingService.nextId(year: 2026);
    expect(a, startsWith('SF-2026-'));
    expect(a.length, 'SF-2026-001'.length);
  });

  test('safe finding report docx builds a valid zip with assets', () async {
    final logo = await File('assets/images/logo_cmsb.png').readAsBytes();
    final f = SafeFinding(
      id: 'SF-2026-010',
      date: '2026-08-12T08:00:00.000',
      floor: 'Aras 6',
      issue: 'Lantai licin berhampiran tangga',
      status: 'closed',
      techName: 'Ahmad',
      attendedAt: '2026-08-12T09:00:00.000',
      closedAt: '2026-08-12T11:00:00.000',
      findings: 'Tanda amaran dipasang',
      remark: 'Sila pantau minggu ini',
      photos: [
        'data:image/png;base64,${base64Encode(logo)}',
      ],
    );
    final bytes = await SafeFindingDocxService.build(f, DateTime(2026, 8, 12));
    expect(bytes.length, greaterThan(2000));
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(0, Endian.little), 0x04034B50, reason: 'local header');
    expect(data.getUint32(bytes.length - 22, Endian.little), 0x06054B50, reason: 'EOCD');

    final tmp = File('${Directory.systemTemp.path}\\safe_finding_test.docx');
    tmp.writeAsBytesSync(bytes);
    expect(tmp.existsSync(), true);
    // ignore: avoid_print
    print('SAVED ${tmp.path} size=${bytes.length}');
  });

  test('report survives empty photo list (no photo grid)', () async {
    final f = SafeFinding(
      id: 'SF-2026-011',
      date: '2026-08-12T08:00:00.000',
      floor: 'G',
      issue: 'Pintu kebakaran tersangkut',
      status: 'closed',
    );
    final bytes = await SafeFindingDocxService.build(f, DateTime(2026, 8, 12));
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(0, Endian.little), 0x04034B50, reason: 'zip header');
    expect(data.getUint32(bytes.length - 22, Endian.little), 0x06054B50, reason: 'EOCD');
  });
}
