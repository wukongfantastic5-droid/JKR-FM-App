import 'dart:convert';
import 'dart:io';

void main() {
  final path = r'C:\Users\zaina\OneDrive\Desktop\Kerja\Cakra Mahkota Sdn Bhd\Gerak Kerja\JKR_FM_Guide\Directory\Purchase Order\001-Quotation.pdf';
  final raw = latin1.decode(File(path).readAsBytesSync());
  final offsets = xrefOffsets(raw);

  // page 3 0 obj contains /Resources
  final seg = at(raw, offsets[3]!);
  final res = seg.indexOf('/Resources');
  print('PAGE RES: ${seg.substring(res, res + 500)}');

  final fm = RegExp(r'/Contents\s*(\d+)\s+\d+\s+R').firstMatch(raw);
  final fobj = fm!.group(1)!;
  // content stream may reference /Resources too; fonts referenced as /F1 etc.
  // find font objects via ToUnicode: scan all objects for /ToUnicode
  for (final e in offsets.entries) {
    final o = at(raw, e.value);
    final ce = o.indexOf('endobj');
    final body = ce < 0 ? o : o.substring(0, ce);
    if (body.contains('/Font')) print('obj ${e.key}: ${body.substring(0, body.length > 220 ? 220 : body.length)}');
  }
  print('--- ToUnicode mentions: ${RegExp('/ToUnicode').allMatches(raw).length}');
}

Map<int, int> xrefOffsets(String raw) {
  final map = <int, int>{};
  final sx = RegExp(r'startxref\s+(\d+)', multiLine: true).firstMatch(raw);
  if (sx == null) return map;
  var off = int.parse(sx.group(1)!);
  var guard = 0;
  while (guard++ < 8) {
    final seg = at(raw, off);
    final m = RegExp(r'xref\s*\n(\d+) (\d+)[\s\S]*?trailer').firstMatch(seg);
    if (m == null) break;
    final start = int.parse(m.group(1)!);
    final count = int.parse(m.group(2)!);
    final rows = RegExp(r'^(\d{10}) \d{5} [nf]', multiLine: true).allMatches(seg);
    final list = rows.toList();
    if (list.length >= count - 1) {
      for (var i = 0; i < count; i++) {
        map[start + i] = int.parse(list[i].group(1)!);
      }
    }
    final prev = RegExp(r'/Prev\s+(\d+)').firstMatch(seg);
    if (prev == null) break;
    off = int.parse(prev.group(1)!);
  }
  return map;
}

String at(String raw, int off) {
  if (off <= 0 || off >= raw.length) return '';
  return raw.substring(off, raw.length > off + 2_000_000 ? off + 2_000_000 : raw.length);
}