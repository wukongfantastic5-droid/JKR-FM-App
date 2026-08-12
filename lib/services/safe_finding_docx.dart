import 'dart:convert';
import 'dart:typed_data';
import 'safe_finding_service.dart';
import 'repair_docx.dart';

/// Builds the Safe Finding Word report using the shared branded CMSB/JKR
/// document builder (RepairDocxService). No template asset is needed; the
/// layout is generated from scratch like the repair-guide documents.
class SafeFindingDocxService {
  static String _fmt(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-${d.year}';
    } catch (_) {
      return iso;
    }
  }

  static Uint8List? _decode(String p) {
    var data = p.trim();
    if (data.isEmpty) return null;
    final c = data.indexOf(',');
    if (c > 0 && data.substring(0, c).contains('base64')) {
      data = data.substring(c + 1);
    }
    try {
      final bytes = base64Decode(data);
      return bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Builds the full .docx bytes for the given finding, closed on [closedOn].
  static Future<Uint8List> build(SafeFinding f, DateTime closedOn) async {
    final photos = <RepairPhoto>[];
    for (var i = 0; i < f.photos.length; i++) {
      final bytes = _decode(f.photos[i]);
      if (bytes == null) continue;
      photos.add(RepairPhoto(
        bytes,
        'Gambar ${i + 1} / Photo ${i + 1}',
      ));
    }

    final closedStr = '${closedOn.day.toString().padLeft(2, '0')}-'
        '${closedOn.month.toString().padLeft(2, '0')}-${closedOn.year}';

    final fields = <RepairField>[
      RepairField('TARIKH / DATE', _fmt(f.date)),
      RepairField('ARAS / FLOOR', f.floor),
      RepairField('ISU / ISSUE', f.issue),
      if (f.techName.isNotEmpty) RepairField('TEKNISI / TECHNICIAN', f.techName),
      if (f.attendedAt.isNotEmpty) RepairField('DIHADIRI / ATTENDED', _fmt(f.attendedAt)),
      if (f.closedAt.isNotEmpty) RepairField('DITUTUP / CLOSED', _fmt(f.closedAt)),
      if (f.findings.trim().isNotEmpty) RepairField('DAPATAN / FINDINGS', f.findings.trim()),
      if (f.remark.trim().isNotEmpty) RepairField('CATATAN / REMARK', f.remark.trim()),
    ];

    return RepairDocxService.build(
      title: 'LAPORAN PENEMUAN KESELAMATAN',
      titleEn: 'SAFE FINDING REPORT',
      refNo: f.id,
      dateStr: closedStr,
      fields: fields,
      photos: photos,
      preparedBy: f.techName.isEmpty ? 'JURUTEKNIK / TECHNICIAN' : f.techName,
      designation: 'Juruteknik Fasiliti / Facilities Technician',
      reviewer: 'JURUTERA MEKANIKAL (FM)',
    );
  }
}