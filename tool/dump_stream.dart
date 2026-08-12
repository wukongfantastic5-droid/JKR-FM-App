import 'dart:convert';
import 'dart:io';

/// Dumps the raw (inflated) content stream of the first page of a PDF,
/// so we can see exactly how text is drawn (Tj/TJ runs, Td moves, fonts).
void main(List<String> args) {
  final path =
      args.isNotEmpty ? args[0] : r'Directory\Purchase Order\quotation2.pdf';
  final bytes = File(path).readAsBytesSync();
  final raw = String.fromCharCodes(bytes);
  final offsets = xrefOffsets(raw);
  for (final m in RegExp(r'(\d+) 0 obj').allMatches(raw)) {
    final num = int.parse(m.group(1)!);
    final off = offsets[num];
    if (off == null) continue;
    final seg = at(raw, off);
    final e = seg.indexOf('endobj');
    final body = e < 0 ? seg : seg.substring(0, e);
    if (!body.contains('/Type') || !body.contains('/Page')) continue;
    if (body.contains('/Pages')) continue;
    final cm = RegExp(r'/Contents\s*(\d+)\s+\d+\s+R').firstMatch(body);
    if (cm == null) continue;
    final co = offsets[int.parse(cm.group(1)!)];
    if (co == null) continue;
    final cBody = at(raw, co);
    final ss = cBody.indexOf('stream');
    if (ss < 0) continue;
    final after = cBody.substring(ss + 'stream'.length);
    final skip = after.startsWith('\r\n') ? 2 : 1;
    final lenM = RegExp(r'/Length\s+(\d+)').firstMatch(cBody);
    final len = lenM == null ? 1 << 30 : int.parse(lenM.group(1)!);
    var data = after.substring(skip);
    if (data.length > len) data = data.substring(0, len);
    try {
      final inf = String.fromCharCodes(ZLibDecoder().convert(data.codeUnits));
      stdout.writeln('=== page obj $num content (${inf.length} chars) ===');
      stdout.writeln(inf);
    } catch (e) {
      stdout.writeln('inflate fail: $e');
    }
  }
}

String at(String raw, int off) {
  if (off <= 0 || off >= raw.length) return '';
  return raw.substring(
      off, raw.length > off + 2000000 ? off + 2000000 : raw.length);
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
    final rows = RegExp(r'^(\d{10}) \d{5} [nf]', multiLine: true)
        .allMatches(seg)
        .toList();
    if (rows.length >= count - 1) {
      for (var i = 0; i < count; i++) {
        map[start + i] = int.parse(rows[i].group(1)!);
      }
    }
    final prev = RegExp(r'/Prev\s+(\d+)').firstMatch(seg);
    if (prev == null) break;
    off = int.parse(prev.group(1)!);
  }
  return map;
}
