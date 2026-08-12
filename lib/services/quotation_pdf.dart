import 'dart:convert';
import 'dart:io';

/// Tiny dependency-free PDF text extractor for supplier quotation PDFs.
///
/// Quotations arrive as text PDFs from many exporters (Excel table export,
/// Word/WPS print-to-PDF, LT/LDA "Metafile" exports, …). This extractor
/// walks classic xref tables, inflates FlateDecode content streams and
/// decodes the text-showing operators (Tj/TJ with literal or hex strings)
/// using each font's /ToUnicode CMap when present. The layout classifier in
/// [QuotationPdf.parse] then reconstructs vendor, headers, item table and
/// totals without assuming a specific x-coordinate scale.

/// One positioned text cell in the drawing.
class PdfCell {
  final double x;
  final double y;
  final String text;

  /// 0-based page index; pages are stacked so later pages sort lower.
  final int page;
  const PdfCell(this.x, this.y, this.text, {this.page = 0});

  @override
  String toString() => 'PdfCell($x, $y, "$text")';
}

/// One line item read from the quotation table.
class QuotationItem {
  final int no;
  final String description;
  final int qty;
  final double unitPrice;
  final double subtotal;
  const QuotationItem({
    required this.no,
    required this.description,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
  });
}

/// The structured contents of a supplier quotation.
class Quotation {
  /// Vendor block lines: name then address, in reading order.
  final List<String> vendor;

  /// The "TO:-" party (the buyer, normally CAKRA MAKOTA SDN BHD).
  final String toCompany;

  /// Quotation date as printed, e.g. '10-Aug-26'.
  final String dateText;

  /// Payment terms, e.g. '60 DAYS'.
  final String terms;

  /// "ATTN:-" contact at the vendor.
  final String attn;

  final List<QuotationItem> items;
  final double subTotal;
  final double totalAmount;

  const Quotation({
    required this.vendor,
    required this.toCompany,
    required this.dateText,
    required this.terms,
    required this.attn,
    required this.items,
    required this.subTotal,
    required this.totalAmount,
  });
}

class QuotationPdf {
  /// Returns the raw text lines of the PDF, page by page (reading order).
  static List<String> extractLines(List<int> bytes, {bool debug = false}) {
    return extractCells(bytes, debug: debug).map((c) => c.text).toList();
  }

  /// Returns every drawn text cell with its device coordinates (y-up), in
  /// reading order (top-to-bottom, left-to-right).
  static List<PdfCell> extractCells(List<int> bytes, {bool debug = false}) {
    final raw = latin1.decode(bytes);
    final offsets = _xrefOffsets(raw);
    if (debug) print('DEBUG offsets mapped: ${offsets.length}');
    final pages = <_PageDef>[];
    var pageNo = 0;

    // find /Type /Page objects (not /Pages) in file order
    for (final m in RegExp(r'(\d+) 0 obj').allMatches(raw)) {
      final num = int.parse(m.group(1)!);
      final off = offsets[num];
      if (off == null) continue;
      final head = _at(raw, off);
      final objEnd = head.indexOf('endobj');
      if (objEnd < 0) continue;
      final body = head.substring(0, objEnd);
      if (!body.contains('/Type') || !body.contains('/Page')) continue;
      if (body.contains('/Pages')) continue;
      if (debug) print('DEBUG found page obj $num');

      final cm = RegExp(r'/Contents\s*(\d+)\s+\d+\s+R|/Contents\s*\[([^\]]+)\]')
          .firstMatch(body);
      if (cm == null) continue;
      final refs = <int>[];
      if (cm.group(1) != null) {
        refs.add(int.parse(cm.group(1)!));
      } else {
        for (final r in RegExp(r'(\d+)\s+\d+\s+R')
            .allMatches(cm.group(2)!)) {
          refs.add(int.parse(r.group(1)!));
        }
      }
      pages.add(_PageDef(pageNo: pageNo++, pageObj: num, contentRefs: refs,
          raw: raw, offsets: offsets,
          fontInfo: _FontInfo()..debug = debug));
    }

    // resolve per-page fonts' ToUnicode maps (Type0/Identity-H hex codes)
    for (final p in pages) {
      final res = _resourcesOf(p);
      for (final e in res.entries) {
        final fm = RegExp(r'/(ToUnicode)\s+(\d+)\s+\d+\s+R').firstMatch(e.value);
        if (debug) print('DEBUG font ${e.key}: toUnicodeMatch=${fm?.group(2)}');
        if (fm == null) continue;
        final to = offsets[int.parse(fm.group(2)!)];
        if (to == null) continue;
        final seg = _at(raw, to);
        final st = seg.indexOf('stream');
        if (debug) print('DEBUG font ${e.key}: streamAt=$st endobjAt=${seg.indexOf('endobj')}');
        if (st < 0 || st > seg.indexOf('endobj')) continue;
        final skip = seg.startsWith('stream\r\n', st) ? 2 : 1;
        final data = seg.substring(st + 'stream'.length + skip);
        final len = _streamLength(seg);
        if (debug) print('DEBUG font ${e.key}: rawLen=${data.length} len=$len');
        try {
          final inflated = latin1.decode(
              ZLibDecoder().convert(latin1.encode(data.substring(0, len))));
          p.fontInfo.maps[e.key] = _UniMap.fromCmap(inflated);
          if (debug) {
            final m2 = p.fontInfo.maps[e.key]!;
            print('DEBUG font ${e.key}: ${m2.map.length} codepoints');
          }
        } catch (err) {
          if (debug) print('DEBUG font ${e.key}: decode failed: $err');
        }
      }
      if (debug) print('DEBUG page ${p.pageNo}: contents=${p.contentRefs}');
    }

    final cells = <PdfCell>[];
    for (final p in pages) {
      for (final r in p.contentRefs) {
        final co = offsets[r];
        if (co == null) continue;
        final cBody = _at(raw, co);
        final ce = cBody.indexOf('endobj');
        final streamStart = cBody.indexOf('stream');
        if (streamStart < 0 || streamStart > ce) continue;
        var skip = 1;
        final afterKw = cBody.substring(streamStart + 'stream'.length);
        if (afterKw.startsWith('\r\n')) {
          skip = 2;
        }
        final sd = _StreamDef(
          data: _at(raw, co + streamStart + 'stream'.length + skip),
          length: _streamLength(cBody),
        );
        var data = sd.data;
        if (data.length > sd.length) data = data.substring(0, sd.length);
        try {
          final inflated = latin1.decode(
              ZLibDecoder().convert(latin1.encode(data)));
          if (debug) print('DEBUG page ${p.pageNo} inflated: ${inflated.length}');
          cells.addAll(_extractText(inflated, p, debug));
        } catch (e) {
          if (debug) print('DEBUG inflate fail: $e');
        }
      }
    }
    cells.sort((a, b) {
      if (a.page != b.page) return b.page.compareTo(a.page);
      final byY = b.y.compareTo(a.y);
      return byY != 0 ? byY : a.x.compareTo(b.x);
    });
    // merge explicit space cells (WPS/metafile exports draw ' ' as its own
    // positioned text run) into the following cell on the same row
    final merged = <PdfCell>[];
    for (final c in cells) {
      if (QuotationPdf._isBlank(c.text)) {
        if (merged.isNotEmpty &&
            (merged.last.y - c.y).abs() <= 1.0 &&
            merged.last.x < c.x) {
          merged[merged.length - 1] = PdfCell(
              merged.last.x, merged.last.y, '${merged.last.text} ',
              page: merged.last.page);
        }
        continue;
      }
      merged.add(c);
    }
    return merged;
  }

  static bool _isBlank(String s) =>
      s.trim().isEmpty ||
      s.codeUnits.every((u) => u < 0x21 && u != 0x03 || u == 0xA0);

  // ------------------------------------------------------------------
  // page resources / fonts
  // ------------------------------------------------------------------

  static Map<String, String> _resourcesOf(_PageDef p) {
    final out = <String, String>{};
    final pagesIdx = p.raw.indexOf('${p.pageObj} 0 obj');
    if (pagesIdx < 0) return out;
    final seg = p.raw.substring(pagesIdx,
        p.raw.length > pagesIdx + 500000 ? pagesIdx + 500000 : p.raw.length);
    final resStart = seg.indexOf('/Resources');
    if (resStart < 0) return out;
    final resBlock = _bracketBlock(seg, seg.indexOf('<<', resStart));
    if (p.fontInfo.debug) {
      print('DEBUG _resourcesOf pageObj=${p.pageObj} resStart=$resStart '
          'resBlockHead=${resBlock.substring(0, resBlock.length > 160 ? 160 : resBlock.length)}');
    }
    if (!resBlock.contains('/Font')) return out;
    final fontBlock = _bracketBlock(resBlock, resBlock.indexOf('/Font') + 5);
    for (final mm in RegExp(r'/([\w\-.+,]+)\s+(\d+)\s+\d+\s+R')
        .allMatches(fontBlock)) {
      out[mm.group(1)!] = _at(p.raw, p.offsets[int.parse(mm.group(2)!)] ?? 0)
          .substring(0, 4000);
    }
    if (p.fontInfo.debug) {
      print('DEBUG _resourcesOf fonts found: ${out.keys}');
    }
    return out;
  }

  /// Returns the text of the dict starting at the '<<' at [openIdx],
  /// including the nesting, up to the matching '>>'.
  static String _bracketBlock(String s, int openIdx) {
    var depth = 0;
    var i = openIdx;
    final sb = StringBuffer();
    while (i < s.length) {
      final c = s[i];
      if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
        i += 2;
        continue;
      }
      if (c == '(') {
        var j = i + 1;
        while (j < s.length && s[j] != ')') {
          if (s[j] == r'\') j++;
          j++;
        }
        sb.write(s.substring(i, j + 1 < s.length ? j + 1 : s.length));
        i = j + 1;
        continue;
      }
      if (c == '<' && i + 1 < s.length && s[i + 1] == '<') {
        depth++;
        sb.write('<<');
        i += 2;
        continue;
      }
      if (c == '>' && i + 1 < s.length && s[i + 1] == '>') {
        depth--;
        sb.write('>>');
        i += 2;
        if (depth == 0) return sb.toString();
        continue;
      }
      sb.write(c);
      i++;
    }
    return sb.toString();
  }

  // ------------------------------------------------------------------
  // content stream text extraction
  // ------------------------------------------------------------------

  /// Lexes the content stream and emits one [PdfCell] per shown text run,
  /// honoring CTM (cm/q/Q), text matrices (Tm/Td/TD/T*), Tf font selection
  /// and hex-string decoding through the font's ToUnicode map.
  static List<PdfCell> _extractText(String stream, _PageDef page, bool debug) {
    final out = <PdfCell>[];
    final toks = _lex(stream, debug);
    // graphics state
    double cA = 1, cB = 0, cC = 0, cD = 1, cE = 0, cF = 0;
    final ctmStack = <List<double>>[];
    // text state
    double tA = 1, tB = 0, tC = 0, tD = 1, tE = 0, tF = 0;
    double lA = 1, lB = 0, lC = 0, lD = 1, lE = 0, lF = 0;
    var tfs = 12.0;
    var tl = 0.0;
    var font = '';
    var inText = false;

    final stack = <String>[];
    for (final t in toks) {
      final isOp = _ops.contains(t);
      if (isOp) {
        switch (t) {
          case 'q':
            ctmStack.add([cA, cB, cC, cD, cE, cF]);
          case 'Q':
            if (ctmStack.isNotEmpty) {
              final s = ctmStack.removeLast();
              cA = s[0]; cB = s[1]; cC = s[2]; cD = s[3]; cE = s[4]; cF = s[5];
            }
          case 'cm':
            final a = _n(stack, 6);
            if (a != null) {
              final m = a.map(double.parse).toList();
              final na = cA * m[0] + cC * m[1];
              final nb = cB * m[0] + cD * m[1];
              final nc = cA * m[2] + cC * m[3];
              final nd = cB * m[2] + cD * m[3];
              final ne = cA * m[4] + cC * m[5] + cE;
              final nf = cB * m[4] + cD * m[5] + cF;
              cA = na; cB = nb; cC = nc; cD = nd; cE = ne; cF = nf;
            }
          case 'BT':
            inText = true;
            tA = 1; tB = 0; tC = 0; tD = 1; tE = 0; tF = 0;
            lA = 1; lB = 0; lC = 0; lD = 1; lE = 0; lF = 0;
            tl = 0;
          case 'ET':
            inText = false;
          case 'Tf':
            if (stack.length >= 2) {
              final size = stack.removeLast();
              font = stack.removeLast();
              tfs = double.tryParse(size) ?? tfs;
            }
          case 'Td':
            final p = _n(stack, 2);
            if (p != null) {
              final tx = double.parse(p[0]);
              final ty = double.parse(p[1]);
              lE += lA * tx + lC * ty;
              lF += lB * tx + lD * ty;
              tE = lE; tF = lF;
            }
          case 'TD':
            final p = _n(stack, 2);
            if (p != null) {
              final tx = double.parse(p[0]);
              final ty = double.parse(p[1]);
              lE += lA * tx + lC * ty;
              lF += lB * tx + lD * ty;
              tE = lE; tF = lF;
              tl = -double.parse(p[1]);
            }
          case 'T*':
            lE += lC * -tl;
            lF += lD * -tl;
            tE = lE; tF = lF;
          case 'TL':
            tl = double.tryParse(stack.isEmpty ? '' : stack.removeLast()) ?? tl;
          case 'Tm':
            final p = _n(stack, 6);
            if (p != null) {
              final a = p.map(double.parse).toList();
              tA = a[0]; tB = a[1]; tC = a[2]; tD = a[3]; tE = a[4]; tF = a[5];
              lA = a[0]; lB = a[1]; lC = a[2]; lD = a[3]; lE = a[4]; lF = a[5];
            }
          case 'Tj':
            if (inText && stack.isNotEmpty) {
              final s = stack.removeLast();
              final text = _decodeString(s, font, page);
              _addRun(out, cA * tE + cC * tF + cE, cB * tE + cD * tF + cF,
                  text, page.pageNo);
            }
          case "'":
            if (inText && stack.isNotEmpty) {
              lE += lC * -tl;
              lF += lD * -tl;
              tE = lE; tF = lF;
              final s = stack.removeLast();
              final text = _decodeString(s, font, page);
              _addRun(out, cA * tE + cC * tF + cE, cB * tE + cD * tF + cF,
                  text, page.pageNo);
            }
          case '"':
            if (inText && stack.isNotEmpty) {
              lE += lC * -tl;
              lF += lD * -tl;
              tE = lE; tF = lF;
              final s = stack.removeLast();
              final text = _decodeString(s, font, page);
              _addRun(out, cA * tE + cC * tF + cE, cB * tE + cD * tF + cF,
                  text, page.pageNo);
            }
          case 'TJ':
            if (inText && stack.isNotEmpty) {
              final arr = stack.removeLast();
              final parts = RegExp(r'\((.*?)\)', dotAll: true)
                  .allMatches(arr)
                  .map((m) => m.group(1)!)
                  .toList();
              final hexes = RegExp(r'<([0-9A-Fa-f]+)>')
                  .allMatches(arr)
                  .map((m) => m.group(1)!)
                  .toList();
              var text = '';
              for (final s in parts) {
                text += unescapeLiteral(s);
              }
              for (final h in hexes) {
                text += _decodeHex(h, font, page);
              }
              _addRun(out, cA * tE + cC * tF + cE, cB * tE + cD * tF + cF,
                  text, page.pageNo);
            }
          default:
            stack.clear();
        }
        stack.clear();
      } else {
        stack.add(t);
      }
    }
    return out;
  }

  static List<String>? _n(List<String> stack, int count) {
    if (stack.length < count) return null;
    final start = stack.length - count;
    final args = stack.sublist(start);
    stack.removeRange(start, stack.length);
    return args;
  }

  static const _ops = {
    'q', 'Q', 'cm', 'BT', 'ET', 'Tf', 'Td', 'TD', 'T*', 'TL', 'Tm',
    'Tj', 'TJ', "'", '"', 'Tz', 'Tr', 'Ts', 'Tc', 'Tw', 'do', 'Do',
    're', 'f', 'F', 'f*', 'S', 's', 'cl', 'c', 'v', 'y', 'h', 'n',
    'm', 'l', 'w', 'J', 'j', 'M', 'd', 'gs', 'sh', 'BI', 'ID', 'EI',
    'BMC', 'BDC', 'EMC', 'MP', 'DP', 'i', 'RG', 'rg', 'G', 'g', 'K', 'k',
  };

  static String _decodeString(String tok, String font, _PageDef page) {
    if (tok.startsWith('<') && tok.endsWith('>')) {
      return _decodeHex(tok.substring(1, tok.length - 1), font, page);
    }
    return unescapeLiteral(tok);
  }

  /// Adds a positioned text run, keeping word separation for
  /// whitespace-only runs: exporters draw ' ' as its own positioned glyph,
  /// so a blank run is recorded as a single space cell (merged into the
  /// preceding cell on the same row by [extractCells]).
  static void _addRun(
      List<PdfCell> out, double x, double y, String text, int page) {
    final t = text.trim();
    if (t.isNotEmpty) {
      out.add(PdfCell(x, y, t, page: page));
    } else if (text.isNotEmpty) {
      out.add(PdfCell(x, y, ' ', page: page));
    }
  }

  static String _decodeHex(String hex, String font, _PageDef page) {
    final uni = page.fontInfo.maps[_stripSlash(font)];
    if (page.fontInfo.debug && hex.length >= 4) {
      print('DEBUG decode font=[$font] strip=[${_stripSlash(font)}] '
          'hasMap=${uni != null} code0=${hex.substring(0, 4)}');
    }
    if (uni != null) {
      final sb = StringBuffer();
      var i = 0;
      while (i + 4 <= hex.length) {
        final code = int.parse(hex.substring(i, i + 4), radix: 16);
        sb.write(uni.map[code] ?? _utf16fallbackHex(hex, i));
        i += 4;
      }
      return sb.toString();
    }
    // one code unit per 4 hex digits is the identity-H/UTF-16BE convention
    if (hex.length % 4 == 0) {
      try {
        final buf = <int>[];
        for (var i = 0; i < hex.length; i += 4) {
          buf.add(int.parse(hex.substring(i, i + 4), radix: 16));
        }
        final s = String.fromCharCodes(buf);
        if (!s.contains('\uFFFD') && s.isNotEmpty) return s;
      } catch (_) {}
    }
    final latin = StringBuffer();
    for (var i = 0; i + 1 < hex.length; i += 2) {
      latin.writeCharCode(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return latin.toString();
  }

  static String _stripSlash(String font) =>
      font.startsWith('/') ? font.substring(1) : font;

  static String _utf16fallbackHex(String hex, int i) {
    if (i + 4 <= hex.length) {
      return String.fromCharCode(int.parse(hex.substring(i, i + 4), radix: 16));
    }
    return '';
  }

  /// Splits the stream into operators and their operand tokens; arrays in
  /// TJ operands are captured as one token.
  static List<String> _lex(String s, bool debug) {
    final out = <String>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == '(') {
        final j = _literalEnd(s, i);
        out.add(s.substring(i, j + 1 < s.length ? j + 1 : s.length));
        i = j + 1;
      } else if (c == '<') {
        if (i + 1 < s.length && s[i + 1] == '<') {
          final e = s.indexOf('>>', i + 2);
          out.add(s.substring(i, e < 0 ? s.length : e + 2));
          i = e < 0 ? s.length : e + 2;
        } else {
          final e = s.indexOf('>', i + 1);
          out.add(s.substring(i, e < 0 ? s.length : e + 1));
          i = e < 0 ? s.length : e + 1;
        }
      } else if (c == '[') {
        var depth = 1;
        var j = i + 1;
        while (j < s.length && depth > 0) {
          if (s[j] == '[') {
            depth++;
          } else if (s[j] == ']') {
            depth--;
          } else if (s[j] == '(') {
            j = _literalEnd(s, j) + 1;
            continue;
          }
          j++;
        }
        out.add(s.substring(i, j < s.length ? j + 1 : s.length));
        i = j + 1;
      } else if (c == '/') {
        var j = i + 1;
        while (j < s.length && !' \t\r\n()<>[]{}/%'.contains(s[j])) {
          j++;
        }
        out.add(s.substring(i, j));
        i = j;
      } else if (c == '%') {
        final e = s.indexOf('\n', i);
        i = e < 0 ? s.length : e + 1;
      } else if (c == ']') {
        out.add(']');
        i++;
      } else if (' \t\r\n'.contains(c)) {
        i++;
      } else {
        var j = i;
        while (j < s.length && !' \t\r\n()<>[]{}/%'.contains(s[j])) {
          j++;
        }
        out.add(s.substring(i, j));
        i = j;
      }
    }
    return out;
  }

  static int _literalEnd(String s, int open) {
    var i = open + 1;
    while (i < s.length) {
      if (s[i] == r'\') {
        i += 2;
        continue;
      }
      if (s[i] == ')') return i;
      i++;
    }
    return s.length - 1;
  }

  // ------------------------------------------------------------------
  // document-level parsing of positioned cells
  // ------------------------------------------------------------------

  /// Reconstructs the quotation document structure from positioned cells.
  ///
  /// Rows cluster on y (per page), columns on x. Two strategies are tried:
  /// the fixed bands of Excel-style table exports, then a scale-independent
  /// column clustering for arbitrary layouts.
  static Quotation parse(List<PdfCell> cells, {bool debug = false}) {
    final rows = <List<PdfCell>>[];
    var cur = <PdfCell>[];
    var cy = 0.0;
    var cp = 0;
    for (final c in cells) {
      if (cur.isNotEmpty &&
          (c.page != cp || (cy - c.y).abs() > 1.0)) {
        rows.add(cur);
        cur = [];
      }
      cp = c.page;
      cy = c.y;
      cur.add(c);
    }
    if (cur.isNotEmpty) rows.add(cur);

    var q = _parseWithBands(rows);
    if (q.items.length < 3) {
      q = _parseByColumns(rows);
    }
    return q;
  }

  static const _sk = {'NO', 'No.', ':', '-'};
  static final _colonRe = RegExp(r'^:\s*$');

  static Quotation _parseWithBands(List<List<PdfCell>> rows) {
    final sip = <String>[];
    String? toCompany, dateText, terms, attn;
    final items = <QuotationItem>[];
    double? subTotal, totalAmount;

    for (final row in rows) {
      final rowY = row.first.y;
      String band(double lo, double hi) => _runText(row
          .where((c) =>
              c.x >= lo &&
              c.x < hi &&
              !_sk.contains(c.text) &&
              !_colonRe.hasMatch(c.text))
          .toList());
      final noT = band(0, 120);
      final descT = band(120, 360);
      final qtyT = band(360, 410);
      final priceT = band(410, 470);
      final amtT = band(470, 1e9);

      if (rowY > 765 && items.isEmpty) {
        sip.add(_join(row));
        continue;
      }

      final no = int.tryParse(noT);
      if (no != null && descT.isNotEmpty) {
        items.add(_mkItem(no, descT, qtyT, priceT, amtT));
        continue;
      }
      final upp = _join(row).toUpperCase();
      if (upp.contains('SUB TOTAL') || upp.contains('SUBTOTAL')) {
        final v = _rightNum(row) ?? double.tryParse(amtT.replaceAll(',', ''));
        if (v != null) subTotal = v;
        continue;
      }
      if (upp.contains('TOTAL AMOUNT')) {
        final v = _rightNum(row) ?? double.tryParse(amtT.replaceAll(',', ''));
        if (v != null) totalAmount = v;
        continue;
      }
      if (upp.contains('TOTAL') && !upp.contains('TOTALLY')) {
        final v = _rightNum(row);
        if (v != null) totalAmount = v;
        continue;
      }
      if (!upp.contains('TOTAL')) {
        final h = _parseHeader(row, joined: _join(row));
        if (h != null) {
          switch (h.$1) {
            case 'to':
              toCompany ??= h.$2;
            case 'date':
              dateText ??= h.$2;
            case 'terms':
              terms ??= h.$2;
            case 'attn':
              attn ??= h.$2;
          }
        }
      }
    }

    return Quotation(
      vendor: sip,
      toCompany: toCompany ?? '',
      dateText: dateText ?? '',
      terms: terms ?? '',
      attn: attn ?? '',
      items: items,
      subTotal: subTotal ?? items.fold(0.0, (a, i) => a + i.subtotal),
      totalAmount: totalAmount ?? subTotal ?? 0,
    );
  }

  /// Scale-independent layout: cluster x values into columns, then assign
  /// roles right-to-left (amount, unit price, qty, description, item#).
  static Quotation _parseByColumns(List<List<PdfCell>> rows) {
    final all = <PdfCell>[for (final r in rows) ...r];
    var minX = double.infinity, maxX = -double.infinity;
    for (final c in all) {
      if (c.text.trim().isEmpty) continue;
      if (c.x < minX) minX = c.x;
      if (c.x > maxX) maxX = c.x;
    }
    final width = maxX - minX;

    // find candidate itemNo x positions (left half, plain integers)
    final noCandidates = <double>{};
    for (final r in rows) {
      final left = r.where((c) =>
          c.x < minX + width * 0.5 &&
          RegExp(r'^\d+$').hasMatch(c.text.trim()));
      for (final c in left) {
        noCandidates.add(c.x);
      }
    }
    if (noCandidates.isEmpty) {
      return Quotation(
        vendor: const [],
        toCompany: '',
        dateText: '',
        terms: '',
        attn: '',
        items: const [],
        subTotal: 0,
        totalAmount: 0,
      );
    }
    final noCol = _clusterX(noCandidates.toList()).first;

    // column roles: find for each candidate row its right-most numeric cell
    final items = <QuotationItem>[];
    final sip = <String>[];
    var firstItemY = double.infinity;
    for (final r in rows) {
      final noC = r.where((c) =>
          c.x <= noCol.max + (noCol.max - noCol.min) +
              ((noCol.max - noCol.min) / 2) &&
          c.x >= noCol.min - 1 &&
          RegExp(r'^\d+$').hasMatch(c.text.trim()));
      if (noC.isEmpty) continue;
      final no = int.parse(noC.first.text.trim());
      if (firstItemY == double.infinity) firstItemY = r.first.y;
      final rest = r
          .where((c) => c.x > noCol.max && !_sk.contains(c.text))
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      if (rest.isEmpty) continue;
      String money(String s) =>
          double.tryParse(s.replaceAll(',', '').trim())?.toStringAsFixed(2) ??
          '';
      double? moneyD(String s) => double.tryParse(s.replaceAll(',', '').trim());

      // [desc... num...]; numbers after description get role by order
      final descParts = <String>[];
      final nums = <double>[];
      const descWords = {
        '', 'no', 'no.', 'item', 'description', 'pc', 'pcs', 'set', 'sets',
        'unit', 'units', 'ea', 'each', 'lot', 'lump', 'sum', 'dr', 'nos', 'pkt'
      };
      for (final c in rest) {
        final t = c.text.trim();
        final n = moneyD(t);
        if (n != null && !RegExp(r'^[a-zA-Z]').hasMatch(t)) {
          nums.add(n);
        } else if (!descWords.contains(t.toLowerCase())) {
          descParts.add(t);
        }
      }
      // drop a stray 'NO'/'qty' unit column textual tokens already filtered
      double qtyV = 1, priceV = 0, amtV = 0;
      if (nums.isEmpty) continue;
      amtV = nums.last;
      priceV = nums.length >= 2 ? nums[nums.length - 2] : amtV;
      qtyV = nums.length >= 3 ? nums[nums.length - 3] : 1;
      if (qtyV == 0) qtyV = 1;
      final qty = qtyV.round();
      // sanity: amount must be a plausible table total
      if ((amtV - qty * priceV).abs() > 0.005 && nums.length >= 4) {
        // keep the right-most as subtotal, the rest tries stay as given
        amtV = nums.last;
      }
      items.add(QuotationItem(
        no: no,
        description: descParts.isEmpty
            ? rowWhereDesc(rest, no) ?? ''
            : descParts.join(' '),
        qty: qty,
        unitPrice: priceV,
        subtotal: amtV,
      ));
    }
    // vendor: rows above the table
    for (final r in rows) {
      if (r.first.y > firstItemY && r.first.y > 700) {
        final j = _join(r);
        final jUp = j.toUpperCase();
        if (j.isEmpty ||
            j.contains('OFFICIAL QUOTATION') ||
            jUp.contains('QUOTATION') ||
            RegExp(r'^(YOUR REF|OUR REF|C\.?\s*C\.?|PAGE|DATE|VALIDITY)[\s:.()\-]*')
                .hasMatch(jUp) ||
            RegExp(r'^[\d\s().+\-/]+$').hasMatch(j.trim())) {
          continue;
        }
        // drop label-only rows ('TEL :', 'EMAIL :', 'Attn :') but keep
        // value rows ('Tel No. : 03-92221313/3131')
        final labelOnly = RegExp(r'^[A-Za-z .:()\-/]+$').hasMatch(j.trim());
        if (labelOnly && !RegExp(r'[0-9\u2E80-\u9FFF]').hasMatch(j)) {
          continue;
        }
        sip.add(j);
      }
    }

    String? toCompany, dateText, terms, attn;
    double? subTotal, totalAmount;
    for (final r in rows) {
      final joined = _join(r);
      final upp = joined.toUpperCase();
      if (upp.contains('SUB TOTAL') || upp.contains('SUBTOTAL')) {
        final v = _rightNum(r);
        if (v != null) subTotal = v;
      } else if (upp.contains('TOTAL') && !upp.contains('TOTALLY')) {
        final v = _rightNum(r);
        if (v != null) totalAmount = v;
      }
    }
    for (final r in rows) {
      final joined = _join(r);
      final h = _parseHeader(r, joined: joined);
      if (h == null) continue;
      switch (h.$1) {
        case 'to':
          toCompany ??= h.$2;
        case 'date':
          dateText ??= h.$2;
        case 'terms':
          terms ??= h.$2;
        case 'attn':
          attn ??= h.$2;
      }
    }
    return Quotation(
      vendor: sip,
      toCompany: toCompany ?? '',
      dateText: dateText ?? '',
      terms: terms ?? '',
      attn: attn ?? '',
      items: items,
      subTotal: subTotal ?? items.fold(0.0, (a, i) => a + i.subtotal),
      totalAmount: totalAmount ?? subTotal ?? 0,
    );
  }

  static String? rowWhereDesc(List<PdfCell> rest, int no) {
    for (final c in rest) {
      final t = c.text.trim();
      if (t.toLowerCase() == 'no') continue;
      if (RegExp(r'^\d').hasMatch(t) && t.length < 6) continue;
      return t;
    }
    return null;
  }

  /// Clusters distinct x values into columns (gap > 3% of page width).
  static List<_XCluster> _clusterX(List<double> xs) {
    final list = xs.toList()..sort();
    final out = <_XCluster>[];
    for (final x in list) {
      if (out.isEmpty || x - out.last.max > 0.06 * (out.last.min + 400 < 800 ? 700 : 700)) {
        out.add(_XCluster(x, x));
      } else {
        out.last.max = x;
      }
    }
    return out;
  }

  static String _join(List<PdfCell> row) => _runText(List.of(row));

  /// CJK ideographs/wide forms: never insert a space between two of these.
  static final _cjkRe = RegExp(r'[\u2E80-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF]');

  /// Joins the cells of one row into a line of text. A single space is
  /// inserted when a real gap separates the runs or when a run carries a
  /// visible space (WPS/metafile exports draw ' ' as its own positioned
  /// glyph, which [extractCells] merges into the preceding cell as a
  /// trailing space). Spaces between two CJK characters are dropped.
  static String _runText(List<PdfCell> cells) {
    final sb = StringBuffer();
    var prevX = double.negativeInfinity;
    var prevEndedSpace = false;
    for (final c in cells) {
      final t = c.text.trim();
      if (t.isEmpty) continue;
      var needSpace = sb.isNotEmpty && (c.x - prevX > 16 || prevEndedSpace);
      if (needSpace) {
        final last = sb.toString();
        final lastCh = last.codeUnitAt(last.length - 1);
        final curCh = t.codeUnitAt(0);
        final bothCjk = _cjkRe.hasMatch(String.fromCharCode(lastCh)) &&
            _cjkRe.hasMatch(String.fromCharCode(curCh));
        if (!bothCjk && lastCh != 0x20) sb.write(' ');
      }
      sb.write(t);
      prevX = c.x;
      prevEndedSpace = c.text.endsWith(' ');
    }
    return sb.toString();
  }

  static double? _rightNum(List<PdfCell> row) {
    for (final c in row.reversed) {
      final v = double.tryParse(c.text.trim().replaceAll(',', ''));
      if (v != null) return v;
    }
    return null;
  }

  static QuotationItem _mkItem(
      int no, String desc, String qtyT, String priceT, String amtT) {
    int qty = 1;
    final qm = RegExp(r'-?\d+(\.\d+)?').firstMatch(qtyT.trim());
    if (qm != null) {
      final d = double.tryParse(qm.group(0)!);
      if (d != null && d > 0) qty = d.round();
    }
    double money(String s) {
      final n = double.tryParse(s.replaceAll(',', ''));
      return n ?? double.tryParse(s.replaceAll(',', '').replaceAll('-', '0')) ?? 0;
    }

    final price = money(priceT);
    final amt = amtT.isNotEmpty ? money(amtT) : price * qty;
    return QuotationItem(
        no: no, description: desc, qty: qty, unitPrice: price, subtotal: amt);
  }

  /// Header/info rows. Labels may come before or after their value
  /// ('DATE : 10-Aug-26' or '10-Aug-26 : DATE'). Matching is case-insensitive.
  static (String, String)? _parseHeader(List<PdfCell> row,
      {required String joined}) {
    final upp = joined.toUpperCase();
    String? after(String label) {
      final labelUp = label.toUpperCase();
      final ix = upp.indexOf(labelUp);
      if (ix < 0) return null;
      var rest = joined.substring(ix + label.length).trim();
      while (rest.startsWith(':') || rest.startsWith('-')) {
        rest = rest.substring(1).trim();
      }
      if (rest.isNotEmpty) return rest;
      final pre = joined.substring(0, ix).trim();
      var v = pre;
      while (v.endsWith(':') || v.endsWith('-')) {
        v = v.substring(0, v.length - 1).trim();
      }
      return v.isEmpty ? null : v;
    }

    if (upp.contains('ATTN')) {
      final v = row
          .where((c) => c.x >= 410 && !_colonRe.hasMatch(c.text))
          .map((c) => c.text)
          .join(' ')
          .trim();
      if (v.isNotEmpty) return ('attn', v);
      return null;
    }
    if (upp.trimLeft().startsWith('TO')) {
      final to = after('TO');
      if (to != null &&
          !to.startsWith('PAGE') &&
          !to.toUpperCase().startsWith('TAL') &&
          !to.startsWith(':') &&
          !to.contains('QUOTATION') &&
          // value must look like a company name (not a sentence word)
          !RegExp(r'^[a-z]').hasMatch(to) &&
          RegExp(r'[A-Za-z]').hasMatch(to)) {
        return ('to', to);
      }
    }
    final dm = after('DATE');
    if (dm != null) return ('date', dm);
    final tm = after('TERMS');
    if (tm != null) return ('terms', tm);
    final pm = after('PAYMENT TERM');
    if (pm != null) return ('terms', pm);
    return null;
  }

  static String _at(String raw, int off) {
    if (off <= 0 || off >= raw.length) return '';
    return raw.substring(
        off, raw.length > off + 2000000 ? off + 2000000 : raw.length);
  }

  static int _streamLength(String body) {
    final m = RegExp(r'/Length\s+(\d+)').firstMatch(body);
    return m == null ? 1 << 30 : int.parse(m.group(1)!);
  }

  /// Classic xref table: objNum -> byte offset.
  static Map<int, int> _xrefOffsets(String raw) {
    final map = <int, int>{};
    final sx = RegExp(r'startxref\s+(\d+)', multiLine: true).firstMatch(raw);
    if (sx == null) return map;
    var off = int.parse(sx.group(1)!);
    var guard = 0;
    while (guard++ < 8) {
      final seg = _at(raw, off);
      final m = RegExp(r'xref\s*\n(\d+) (\d+)[\s\S]*?trailer').firstMatch(seg);
      if (m == null) break;
      final start = int.parse(m.group(1)!);
      final count = int.parse(m.group(2)!);
      final rows =
          RegExp(r'^(\d{10}) \d{5} [nf]', multiLine: true).allMatches(seg);
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

  static String unescapeLiteral(String s) {
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == r'\') {
        if (i + 1 >= s.length) {
          i++;
          continue;
        }
        final n = s[i + 1];
        if (n == 'n') {
          b.write('\n');
          i += 2;
        } else if (n == 'r') {
          i += 2;
        } else if (n == 't') {
          b.write(' ');
          i += 2;
        } else if (n == '(' || n == ')' || n == r'\') {
          b.write(n);
          i += 2;
        } else if (RegExp(r'[0-7]').hasMatch(n)) {
          var oct = s.substring(i + 1, i + 4);
          if (oct.length > 1 && RegExp(r'[0-7]{2,3}').hasMatch(oct)) {
            b.write(String.fromCharCode(int.parse(oct, radix: 8)));
            i += 1 + oct.length;
          } else {
            b.write(n);
            i += 2;
          }
        } else {
          b.write(n);
          i += 2;
        }
      } else {
        b.write(c);
        i++;
      }
    }
    return b.toString();
  }
}

class _StreamDef {
  final String data;
  final int length;
  const _StreamDef({required this.data, required this.length});
}

/// Per-page fonts (name -> font object body) plus ToUnicode maps.
class _FontInfo {
  final Map<String, _UniMap> maps = {};
  bool debug = false;
}

class _UniMap {
  final Map<int, String> map;
  _UniMap(this.map);

  /// Parses a ToUnicode CMap: beginbfchar/beginbfrange code->unicode.
  static _UniMap fromCmap(String cmap) {
    final out = <int, String>{};
    for (final blk in RegExp(r'beginbfchar([\s\S]*?)endbfchar')
        .allMatches(cmap)) {
      for (final m in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
          .allMatches(blk.group(1)!)) {
        final code = int.parse(m.group(1)!, radix: 16);
        out[code] = _u16(m.group(2)!);
      }
    }
    for (final blk in RegExp(r'beginbfrange([\s\S]*?)endbfrange')
        .allMatches(cmap)) {
      // beginbfrange lines: either <s> <e> <dst>   (sequential unicode)
      // or:                     <s> <e> [ <d1> <d2> ... ]  (explicit list)
      for (final line in blk.group(1)!.split('\n')) {
        final m = RegExp(
                r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<([0-9A-Fa-f]+)>|\[([^\]]*)\])')
            .firstMatch(line);
        if (m == null) continue;
        final start = int.parse(m.group(1)!, radix: 16);
        final end = int.parse(m.group(2)!, radix: 16);
        if (m.group(4) != null) {
          final u = int.parse(m.group(4)!, radix: 16);
          for (var i = 0; i <= end - start; i++) {
            out[start + i] = String.fromCharCode(u + i);
          }
        } else {
          final codes = RegExp(r'<([0-9A-Fa-f]+)>')
              .allMatches(m.group(5)!)
              .map((mm) => _u16(mm.group(1)!))
              .toList();
          for (var i = 0; i <= end - start && i < codes.length; i++) {
            out[start + i] = codes[i];
          }
        }
      }
    }
    return _UniMap(out);
  }

  static String _u16(String hex) {
    final buf = <int>[];
    for (var i = 0; i + 4 <= hex.length; i += 4) {
      buf.add(int.parse(hex.substring(i, i + 4), radix: 16));
    }
    return String.fromCharCodes(buf);
  }
}

class _PageDef {
  final int pageNo;
  final int pageObj;
  final List<int> contentRefs;
  final String raw;
  final Map<int, int> offsets;
  final _FontInfo fontInfo;
  _PageDef({
    required this.pageNo,
    required this.pageObj,
    required this.contentRefs,
    required this.raw,
    required this.offsets,
    required this.fontInfo,
  });
}

class _XCluster {
  double min;
  double max;
  _XCluster(this.min, this.max);
}
