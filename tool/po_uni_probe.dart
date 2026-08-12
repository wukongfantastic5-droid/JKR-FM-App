import 'dart:convert';
import 'dart:io';

void main() {
  final path = r'C:\Users\zaina\OneDrive\Desktop\Kerja\Cakra Mahkota Sdn Bhd\Gerak Kerja\JKR_FM_Guide\Directory\Purchase Order\001-Quotation.pdf';
  final raw = latin1.decode(File(path).readAsBytesSync());
  final offsets = xrefOffsets(raw);

  void dumpObj(int num, String label) {
    final seg = at(raw, offsets[num]!);
    final st = seg.indexOf('stream');
    final data = seg.substring(st + 7).trim();
    final lenM = RegExp(r'/Length\s+(\d+)').firstMatch(seg);
    final len = lenM == null ? -1 : int.parse(lenM.group(1)!);
    try {
      final inflated = latin1.decode(ZLibDecoder().convert(latin1.encode(data.substring(0, len))));
      print('==== $label (obj $num) ====');
      print(inflated);
    } catch (e) {
      print('$label: inflate fail $e, len=$len');
      print(data.substring(0, 120 < data.length ? 120 : data.length));
    }
  }

  dumpObj(7, 'MS YaHei ToUnicode');
  dumpObj(14, 'TimesNB ToUnicode');
  dumpObj(5, 'PAGE CONTENT (first 4000)');
  print('==== CONTENT hex runs ====');
  final seg5 = at(raw, offsets[5]!);
  final st5 = seg5.indexOf('stream');
  final data5 = seg5.substring(st5 + 7).trim();
  final len5 = int.parse(RegExp(r'/Length\s+(\d+)').firstMatch(seg5)!.group(1)!);
  final inf5 = latin1.decode(ZLibDecoder().convert(latin1.encode(data5.substring(0, len5))));
  final ops = RegExp(r'<([0-9A-F]{4})>\s*Tj|/([\w\-,+]+)\s+[\d.]+\s+Tf').allMatches(inf5).toList();
  final parts = <String>[];
  for (final m in ops.take(60)) {
    parts.add(m.group(1) != null ? '<${m.group(1)}>' : '/${m.group(2)}');
  }
  print(parts.join(' '));
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