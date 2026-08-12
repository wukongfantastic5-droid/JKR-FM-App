import 'dart:io';

/// Dumps the ToUnicode CMap + Widths of the font objects used in a PDF.
void main(List<String> args) {
  final path =
      args.isNotEmpty ? args[0] : r'Directory\Purchase Order\quotation2.pdf';
  final raw = String.fromCharCodes(File(path).readAsBytesSync());
  final offsets = xrefOffsets(raw);
  final fontObjs = <String, String>{};
  for (final m in RegExp(r'(\d+) 0 obj').allMatches(raw)) {
    final num = int.parse(m.group(1)!);
    final off = offsets[num];
    if (off == null) continue;
    final seg = at(raw, off);
    final e = seg.indexOf('endobj');
    final body = e < 0 ? seg : seg.substring(0, e);
    if (body.contains('/ToUnicode') || body.contains('/Widths')) {
      final bf = RegExp(r'/BaseFont\s*/([\w\-,+]+)').firstMatch(body);
      fontObjs[bf?.group(1) ?? 'obj$num'] = body;
    }
  }
  for (final e in fontObjs.entries) {
    final key = e.key;
    final tu = RegExp(r'/ToUnicode\s+(\d+)\s+\d+\s+R').firstMatch(e.value);
    if (tu != null) {
      final to = offsets[int.parse(tu.group(1)!)];
      if (to != null) {
        final seg = at(raw, to);
        final ss = seg.indexOf('stream');
        if (ss >= 0) {
          final after = seg.substring(ss + 6);
          final skip = after.startsWith('\r\n') ? 2 : 1;
          final lenM = RegExp(r'/Length\s+(\d+)').firstMatch(seg);
          final len = lenM == null ? 1 << 30 : int.parse(lenM.group(1)!);
          var data = after.substring(skip);
          if (data.length > len) data = data.substring(0, len);
          try {
            final inf = String.fromCharCodes(inflate(data));
            stdout.writeln('=== ToUnicode map of $key ===');
            final m3 = RegExp(r'beginbfchar([\s\S]*?)endbfchar').firstMatch(inf);
            if (m3 != null) {
              for (final l in m3.group(1)!.trim().split('\n')) {
                final mm = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
                    .firstMatch(l.trim());
                if (mm == null) continue;
                final code = int.parse(mm.group(1)!, radix: 16);
                if (code <= 0x20 || code == 0x0003 || code > 0x0100) {
                  final u = mm.group(2)!;
                  stdout.writeln('  0x${code.toRadixString(16).padLeft(4, '0')} -> '
                      '0x$u ($_u16(u))');
                }
              }
            } else {
              stdout.writeln('  (no beginbfchar block; full cmap:)');
              stdout.writeln(inf);
            }
          } catch (_) {}
        }
      }
    }
    final w = RegExp(r'/FirstChar\s+(\d+)[\s\S]*?/Widths\s*\[([^\]]*)\]')
        .firstMatch(e.value);
    if (w != null) {
      final first = int.parse(w.group(1)!);
      final ws = w.group(2)!.trim().split(RegExp(r'\s+'));
      final codes = [0x20, 0x28, 0x30, 0x33, 0x34, 0x38, 0x41, 0x42, 0x43,
        0x44, 0x45, 0x48, 0x49, 0x4C, 0x4D, 0x4E, 0x52, 0x53, 0x54, 0x57];
      stdout.writeln('=== Widths of $key (FirstChar=$first) ===');
      for (final c in codes) {
        final idx = c - first;
        if (idx >= 0 && idx < ws.length) {
          stdout.writeln('  0x${c.toRadixString(16).padLeft(4, '0')} '
              "('${String.fromCharCode(c)}') -> ${ws[idx]}");
        }
      }
    }
  }
}

String _u16(String hex) {
  final b = <int>[];
  for (var i = 0; i + 4 <= hex.length; i += 4) {
    b.add(int.parse(hex.substring(i, i + 4), radix: 16));
  }
  return String.fromCharCodes(b);
}

List<int> inflate(String data) => ZLibDecoder().convert(data.codeUnits);

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
