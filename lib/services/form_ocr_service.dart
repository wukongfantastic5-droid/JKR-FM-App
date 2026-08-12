import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, visibleForTesting;
import 'dart:ui' show Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class FormOcrResult {
  final String complainerName;
  final String phone;
  final String dateTime;
  final String floor;
  final String issueType;
  final String workCategory;
  final String priority;
  final String noRuj;
  final String asset;
  final String description;
  final List<String> rawLines;

  const FormOcrResult({
    this.complainerName = '',
    this.phone = '',
    this.dateTime = '',
    this.floor = '',
    this.issueType = '',
    this.workCategory = '',
    this.priority = '',
    this.noRuj = '',
    this.asset = '',
    this.description = '',
    this.rawLines = const [],
  });

  int get filledCount => [
        complainerName,
        phone,
        dateTime,
        floor,
        issueType,
        workCategory,
        priority,
        noRuj,
        asset,
        description,
      ].where((v) => v.isNotEmpty).length;

  @override
  String toString() => 'FormOcrResult(name=$complainerName, phone=$phone, '
      'dateTime=$dateTime, floor=$floor, issue=$issueType, '
      'category=$workCategory, priority=$priority, noRuj=$noRuj, asset=$asset, '
      'desc=$description)';
}

/// Parses a CMMS "Front Desk Siasatan dan Perbaikan" complaint screenshot
/// (or similar JKR complaint form) into structured fields.
class FormOcrService {
  static bool get isSupported => true;

  static Future<FormOcrResult> scan(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(input);
      final lines = text.blocks
          .expand((b) => b.lines)
          .map((l) => OcrLine(l.text, l.boundingBox))
          .toList();
      if (kDebugMode) {
        for (final l in lines) {
          debugPrint('[OCR] x=${l.box.left} y=${l.box.top} w=${l.box.width} | ${l.text}');
        }
      }
      return _parse(lines);
    } finally {
      recognizer.close();
    }
  }

  /// Test hook: runs the parser over OCR lines without an image file.
  @visibleForTesting
  static FormOcrResult parseLines(List<OcrLine> lines) => _parse(lines);

  static FormOcrResult _parse(List<OcrLine> lines) {
    final normalized = lines
        .map((l) => l.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9&\s]'), ' '))
        .toList();

    String? name = _valueAfterLabel(lines, normalized, RegExp(r'\bNAMA\s*PENGADU\b'))
        ?? _valueAfterLabel(lines, normalized, RegExp(r'\bNAMA\s*PENG\w{2,5}\b'));
    String? phone = _valueAfterLabel(lines, normalized, RegExp(r'\bNO\s*\.?\s*(?:TELEFON|TEL)\b'));
    String? dateTime = _valueAfterLabel(lines, normalized, RegExp(r'\bTARIKH\s*[&f]?\s*MASA\b'));
    String? noRuj = _valueAfterLabel(lines, normalized, RegExp(r'\bNO\s*\.?\s*RUJ\b'));

    // Fallbacks: pure-pattern scans anywhere on the page.
    phone ??= _scanPhone(lines);
    dateTime ??= _scanDateTime(lines);
    noRuj ??= _scanNoRuj(lines);

    // Description: prefer the "MENERIMA ADUAN BAHAWA ..." (receipt) block.
    // If that yields nothing usable (e.g. the "BORANG ARAHAN SIASATAN"
    // layout where the complaint text sits under the left-side
    // "Keterangan" label and the page only contains a bare "ADUAN JKR:"
    // line or a title "dan ..."), fall back to reading the Aduan row.
    var description = _scanDescription(lines);
    if (!_isGoodDescription(description)) {
      final rowDesc = _scanRowDescription(lines);
      if (rowDesc.isNotEmpty) description = rowDesc;
    }
    name ??= _scanName(lines, skipDescription: description);

    // Floor: "ARAS 13" / "ARAS G" / "ARAS B1" — scan the whole page since
    // the trailing " - ARAS 13" clause is stripped from the description.
    final floor = _extractFloor(lines.map((l) => l.text).join(' '));

    // Jenis Kerja = CORRECTIVE / PREVENTIVE / ...; Katagori Kerja =
    // ELECTRICAL / MECHANICAL / ...; Keutamaan = NORMAL / URGENT / ...
    final issueType = _findKeyword(lines, _categories);
    final workCategory = _findKeyword(lines, _issueTypes);
    final priority = _findKeyword(lines, _priorities);
    final asset = _findAsset(lines, issueType.isNotEmpty ? issueType : null);

    return FormOcrResult(
      complainerName: name ?? '',
      phone: phone ?? '',
      dateTime: dateTime ?? '',
      floor: floor,
      issueType: issueType,
      workCategory: workCategory,
      priority: priority,
      noRuj: noRuj ?? '',
      asset: asset,
      description: description,
      rawLines: lines.map((l) => l.text).toList(),
    );
  }

  /// Finds a value that sits to the RIGHT of the label on the same line,
  /// on the same ROW (OCR splits label & value into separate lines), or
  /// on the line directly below the label.
  static String? _valueAfterLabel(List<OcrLine> lines, List<String> normalized, RegExp label) {
    final idx = normalized.indexWhere((n) => label.hasMatch(n));
    if (idx == -1) return null;
    final line = lines[idx];
    final box = line.box;
    // Locate the label end inside the ORIGINAL text (normalized indexes
    // don't map 1:1 because OCR noise is stripped).
    final words = matchWords(line.text, normalized[idx]);
    if (words == null) return null;
    final reOrig = RegExp(words.map((w) => RegExp.escape(w)).join(r'[^A-Za-z0-9]*'), caseSensitive: false);
    final mOrig = reOrig.firstMatch(line.text);
    final labelEnd = mOrig?.end ?? line.text.length;
    // 1) Same OCR line, to the right of the label.
    final sameLine = line.text.substring(labelEnd).trim();
    // Only treat as a value if it actually contains letters/digits —
    // OCR noise like a trailing "." after "No. Ruj." must fall through
    // to the same-row scan below.
    if (_looksLikeValue(sameLine) && !_isKnownLabel(sameLine)) return sameLine;
    // 2) Same row, separate OCR line (value sits to the right of the label).
    // Left-column labels must not reach into the right CMMS column.
    final rightCol = _rightColumnX(lines);
    final maxRight = box.right < rightCol ? rightCol : double.infinity;
    OcrLine? rowBest;
    for (final l in lines) {
      if (identical(l, line)) continue;
      final b = l.box;
      final verticalOverlap = b.top < box.bottom && b.bottom > box.top;
      final toRight = b.left >= box.right - 8 && b.left < maxRight;
      if (verticalOverlap && toRight && _looksLikeValue(l.text.trim()) && !_isKnownLabel(l.text.trim())) {
        if (rowBest == null || b.left < rowBest.box.left) rowBest = l;
      }
    }
    if (rowBest != null) return rowBest.text.trim();
    // 3) Below: the next non-empty, non-label line is the value.
    for (int i = idx + 1; i < lines.length; i++) {
      final t = lines[i].text.trim();
      if (t.isEmpty) continue;
      if (_isKnownLabel(t)) break;
      if (_looksLikeValue(t)) return t;
      return null;
    }
    return null;
  }

  /// OCR noise lines (e.g. "|CDPK" watermark fragments in an empty cell)
  /// must never be picked up as field values.
  static bool _looksLikeValue(String t) {
    if (t.isEmpty || t.trimLeft().startsWith('|')) return false;
    return RegExp(r'[A-Za-z0-9]').hasMatch(t);
  }

  /// Splits the label match (from the NORMALIZED line) into words, or
  /// null if it can't be determined.
  static List<String>? matchWords(String original, String normalized) {
    // Re-locate the label inside the normalized text.
    for (final candidate in _labelCandidates) {
      final m = candidate.firstMatch(normalized);
      if (m != null) {
        final words = m.group(0)!.split(RegExp(r'[^A-Z0-9]+')).where((w) => w.isNotEmpty).toList();
        if (words.isNotEmpty) return words;
      }
    }
    return null;
  }

  static final List<RegExp> _labelCandidates = [
    RegExp(r'\bNAMA\s*PENGADU\b'),
    RegExp(r'\bNAMA\s*PENG\w{2,5}\b'),
    RegExp(r'\bNO\s*\.?\s*(?:TELEFON|TEL)\b'),
    RegExp(r'\bNO\s*\.?\s*RUJ\b'),
    RegExp(r'\bTARIKH\s*[&f]?\s*MASA\b'),
  ];

  static final RegExp _knownLabelRe = RegExp(
    r'^(NAMA\s*PENGADU|TARIKH\s*&\s*MASA|TARIKH\s+MASA|NO\.?\s*TELEFON|NO\.?\s*ASET|BAHAGIAN|JENIS\s*KERJA|KATAGORI\s*KERJA|KATEGORI\s*KERJA|KEUTAMAAN(?:\s*KERJA)?|LOKASI|ASET|NAMA\s*ASET|KETERANGAN|TANDATANGAN(?:\s*PENGADU)?|PENGADU|CAP\s*NAMA\s*&?|STATUS|NO\.?\s*RUJ|SEKSYEN)$');

  static bool _isKnownLabel(String t) {
    final u = t.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9&\s]'), ' ').trim();
    if (_knownLabelRe.hasMatch(u)) return true;
    // A line consisting ONLY of a short known label word (<=3 words).
    final words = u.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isNotEmpty && words.length <= 3 && RegExp(r'^(NAMA|TARIKH|MASA|TELEFON|ASET|JENIS|KERJA|KATEGORI|KATAGORI|KEUTAMAAN|LOKASI|STATUS|BAHAGIAN)$').hasMatch(words.join(' '))) {
      return true;
    }
    return false;
  }

  static String? _scanNoRuj(List<OcrLine> lines) {
    final re = RegExp(r'\bJKRBG\d{4,}\b', caseSensitive: false);
    for (final l in lines) {
      final m = re.firstMatch(l.text);
      if (m != null) return m.group(0)!.toUpperCase();
    }
    return null;
  }

  static String? _scanPhone(List<OcrLine> lines) {
    final re = RegExp(r'(?<!\d)(01[0-9])[- ]?(\d{7,8})(?!\d)');
    for (final l in lines) {
      final m = re.firstMatch(l.text.replaceAll('O', '0').replaceAll('o', '0'));
      if (m != null) return '${m.group(1)}${m.group(2)}';
    }
    return null;
  }

  static String? _scanDateTime(List<OcrLine> lines) {
    final re = RegExp(r'\b\d{1,2}[\/\-. ]+\d{1,2}[\/\-. ]+\d{4}\b\s*(?:\d{1,2}[:.]\d{2})?');
    for (final l in lines) {
      final m = re.firstMatch(l.text);
      if (m != null) return m.group(0)!.trim();
    }
    // Malay month format: "31 Julai 2026 09:16" (OCR may read "Ju", "Jul").
    final re2 = RegExp(r'\b\d{1,2}\s+[A-Za-z]{2,}\s+\d{4}\b\s*\d{1,2}:\d{2}');
    for (final l in lines) {
      final m = re2.firstMatch(l.text);
      if (m != null) return m.group(0)!.trim();
    }
    return null;
  }

  static String? _scanName(List<OcrLine> lines, {String? skipDescription}) {
    // A name line is typically uppercase words that are NOT labels/values
    // we already know. Best effort: line with >= 2 words, all letters.
    final labelPattern = RegExp(r'\b(NAMA|TARIKH|NO\b|JENIS|KATAGORI|KEUTAMAAN|LOKASI|ASET|STATUS|TANDATANGAN|CAP|BAHAGIAN|ADUAN|ARAS|ARAHAN|BLOK|SEKSYEN|WARGA|KERJA|BAHAWA|DITERIMA|DITUGASKAN|KEPADA|DIHUBUNGI|BORANG|FORMAT|SIASATAN|PENYENGGARAAN|PEMBAIKAN)\b');
    // Description lines (e.g. "KEDUDUKAN ANGLE BLIND SPOT MIRROR ...") are
    // not names — skip any line whose words mostly come from the captured
    // complaint text (word overlap, so OCR clean-ups like MIRORR->MIRROR
    // don't break the comparison).
    final descWords = (skipDescription ?? '')
        .toUpperCase()
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((w) => w.length >= 3)
        .toSet();
    for (final l in lines) {
      final t = l.text.trim();
      final lineWords = t.toUpperCase().split(RegExp(r'[^A-Z0-9]+')).where((w) => w.length >= 3).toList();
      if (descWords.isNotEmpty && lineWords.isNotEmpty) {
        final overlap = lineWords.where(descWords.contains).length;
        if (overlap * 3 >= lineWords.length * 2) continue;
      }
      final words = t.split(RegExp(r'\s+'));
      if (words.length >= 2 &&
          RegExp(r"^[A-Z][A-Za-z'\-\. ]+$").hasMatch(t) &&
          !labelPattern.hasMatch(t.toUpperCase()) &&
          !t.contains('ADUAN')) {
        return t;
      }
    }
    return null;
  }

  static String _scanDescription(List<OcrLine> lines) {
    // Join the whole page so OCR line-splitting doesn't break capture.
    final full = lines.map((l) => l.text).join(' ');
    final re = RegExp(
      r'\b(?:MENERIMA\s*)?(?:A\s*)?DUAN\b[^.]*?'
      r'(?=\s+(?:NAMA\s+PENGADU|TARIKH\s*&\s*MASA|NO\.?\s+TELEFON|NO\.?\s+ASET|NO\.?\s+RUJ|'
      r'KATEGORI|KATAGORI|JENIS\s+KERJA|KEUTAMAAN|TANDATANGAN|CAP\s+NAMA|STATUS|'
      r'CORRECTIVE|PREVENTIVE|ELECTRICAL|MECHANICAL|NORMAL|URGENT|OPEN|CLOSE|'
      r'ARAHAN\s+SIASATAN|DITUGASKAN|DISIARKAN|B\s+ARAHAN|'
      r'\d{1,2}[-/.]\s*\d{1,2}[-/.]\d{4}|\d{1,2}\s+[A-Za-z]{2,}\s+\d{4})|$)',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = re.allMatches(full).toList();
    if (matches.isEmpty) return '';
    String? best;
    for (final m in matches) {
      final s = m.group(0)!;
      final u = s.toUpperCase();
      // Prefer a block with the "MENERIMA" receipt prefix; fall back to one
      // with "TIDAK MENYALA" (both beat a bare section header like "A Aduan").
      // Otherwise keep the LONGEST block — page titles like "dan ..." match
      // the "DUAN" pattern and are short, so the real complaint text wins.
      if (u.contains('MENERIMA')) {
        best = s;
        break;
      }
      if (u.contains('TIDAK MENYALA')) {
        best = s;
        continue;
      }
      if (best == null || s.length > best.length) best = s;
    }
    if (best == null) return '';
    return _finalizeDescription(_cleanText(best.trim()));
  }

  /// X where the right-hand CMMS column starts (smallest left edge among the
  /// right-side labels). Falls back to 340 px if no right labels are seen.
  /// Used so the scan stays resolution-relative: zooming the same form in or
  /// out scales the label positions together with the values.
  /// NOTE: "Tarikh / Masa" is deliberately NOT included — that label appears
  /// on both sides, and the left-side one would poison the minimum.
  static double _rightColumnX(List<OcrLine> lines) {
    final re = RegExp(
        r'\b(?:NO\.?\s*RUJ|STATUS|JENIS\s*KERJA|KATAGORI|KATEGORI|KEUTAMAAN|'
        r'LOKASI|NAMA\s*ASET|TANDATANGAN|CAP\s*NAMA)\b',
        caseSensitive: false);
    double? min;
    for (final l in lines) {
      if (re.hasMatch(l.text)) {
        if (min == null || l.box.left < min) min = l.box.left;
      }
    }
    return min ?? 340;
  }

  /// X where the right-hand CMMS VALUE column starts (values like
  /// "JKRBG2B002803", "OPEN", "CORRECTIVE" sit further right than their
  /// labels, e.g. labels ~342px vs values ~416px). Falls back to
  /// `rightCol + 60`. Left-column text cells (like a long Keterangan
  /// paragraph) can be wide enough to cross the label x-range, so the
  /// VALUE column is the correct right bound for them.
  static double _rightValueColumnX(List<OcrLine> lines, double rightCol) {
    double? min;
    for (final l in lines) {
      if (l.box.left <= rightCol + 20) continue;
      if (_looksLikeValue(l.text.trim()) && !_isKnownLabel(l.text.trim())) {
        if (min == null || l.box.left < min) min = l.box.left;
      }
    }
    return min ?? rightCol + 60;
  }

  /// Reads the complaint text that sits in the Aduan row to the RIGHT of the
  /// left-side "Keterangan" label ("BORANG ARAHAN SIASATAN" style layout).
  /// Stops at the next left-side label ("Ditugaskan Kepada" etc.) and ignores
  /// the right-hand CMMS column entirely. If the "Keterangan" label itself
  /// was not OCR-read, falls back to a structural scan of the band between
  /// the "Tarikh : ..." row and the "Ditugaskan Kepada" row — height-agnostic,
  /// so short and long complaint texts are both captured.
  static String _scanRowDescription(List<OcrLine> lines) {
    final rightCol = _rightColumnX(lines);
    final leftLimit = rightCol - 150;
    final valueCol = _rightValueColumnX(lines, rightCol);
    OcrLine? label;
    for (final l in lines) {
      if (l.box.left < leftLimit && l.text.trim().toUpperCase().startsWith('KETERANGAN')) {
        label = l;
        break;
      }
    }
    if (label == null) {
      return _scanUnlabelledDescription(lines, rightCol, leftLimit, valueCol);
    }
    double? nextTop;
    for (final l in lines) {
      if (identical(l, label)) continue;
      if (l.box.left >= leftLimit) continue;
      if (l.box.top < label.box.bottom - 2) continue;
      final t = l.text.trim();
      if (t.isEmpty) continue;
      if (_isKnownLabel(t) || RegExp(r'^B[\s.]+', caseSensitive: false).hasMatch(t)) {
        if (nextTop == null || l.box.top < nextTop) nextTop = l.box.top;
      }
    }
    final top = label.box.top - 12;
    // The first description line can sit ABOVE the "Keterangan" label itself
    // (label vertically centred in a tall cell). Scan up to 60px above it;
    // noise rows up there (date, phone, watermark) are removed by pattern.
    final extTop = label.box.top - 60;
    final bottom = (nextTop ?? label.box.top + 60) - 5;
    final leftEdge = label.box.right - 10;
    final dateRe = RegExp(
        r'\d{1,2}\s+[A-Za-z]{2,}\s+\d{4}(?:\s*\d{1,2}:\d{2})?|\d{1,2}[-/.\s]+\d{1,2}[-/.\s]+\d{4}');
    final nameRe = RegExp(r'\b(BINTI|BIN|BT\.?)\b', caseSensitive: false);
    final hits = <OcrLine>[];
    for (final l in lines) {
      if (identical(l, label)) continue;
      final b = l.box;
      if (b.top < extTop || b.top > bottom) continue;
      if (b.left < leftEdge || b.left >= valueCol - 4) continue;
      var t = l.text.trim();
      if (t.isEmpty || t.startsWith('|')) continue;
      // OCR sometimes merges the Tarikh value with the first description
      // line ("31 Ju 2026 16:01 KEDUDUKAN ANGLE ...") — strip the date
      // part and keep the rest instead of dropping the whole line.
      if (dateRe.hasMatch(t)) {
        t = t.replaceFirst(dateRe, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
        if (t.isEmpty) continue;
      }
      if (_isKnownLabel(t) || nameRe.hasMatch(t)) continue;
      // Above the label, only multi-word lines count (single tokens there
      // are phone numbers / stray words, not complaint text).
      if (b.top < top && t.split(RegExp(r'\s+')).length < 2) continue;
      hits.add(OcrLine(t, b));
    }
    if (hits.isEmpty) return '';
    hits.sort((a, b) => a.box.top != b.box.top
        ? a.box.top.compareTo(b.box.top)
        : a.box.left.compareTo(b.box.left));
    return _finalizeDescription(_cleanText(hits.map((l) => l.text.trim()).join(' ')));
  }

  /// The "Keterangan" label itself was not OCR-read (blank cell, merged cell
  /// or scan noise). Reconstruct the row structurally: the description is the
  /// left-column text band between the last "Tarikh : ..." row above and the
  /// next left-side section below ("Ditugaskan Kepada" / "No. Utk Dihubungi" /
  /// "Diserahkan oleh"). Named rows (e.g. "INSIYAH BINTI MUHAMAD") and
  /// right-column labels/values are excluded.
  static String _scanUnlabelledDescription(List<OcrLine> lines, double rightCol, double leftLimit, double valueCol) {
    // Bottom anchor: nearest left-side section label below the description.
    final bottomRe = RegExp(r'\b(DITUGASKAN|DIHUBUNGI|DISERAHKAN)\b', caseSensitive: false);
    OcrLine? bottom;
    for (final l in lines) {
      if (l.box.left >= leftLimit) continue;
      if (bottomRe.hasMatch(l.text)) {
        if (bottom == null || l.box.top < bottom.box.top) bottom = l;
      }
    }
    if (bottom == null) return '';
    // Top anchor: nearest left-side row above the description that is a
    // known label or a "Tarikh : 31 Jul 2026 16:01" value line.
    final dateRe = RegExp(
        r'\d{1,2}\s+[A-Za-z]{2,}\s+\d{4}(?:\s*\d{1,2}:\d{2})?|\d{1,2}[-/.\s]+\d{1,2}[-/.\s]+\d{4}');
    OcrLine? top;
    for (final l in lines) {
      if (identical(l, bottom) || l.box.left >= leftLimit) continue;
      if (l.box.top >= bottom.box.top) continue;
      if (_isKnownLabel(l.text.trim()) || dateRe.hasMatch(l.text)) {
        if (top == null || l.box.top > top.box.top) top = l;
      }
    }
    if (top == null) return '';
    // The band starts at the TOP of the anchor row, not its bottom: OCR
    // bounding boxes for the date row can be much taller than the glyphs
    // (the box swallows the line below), which would silently cut the first
    // description line. Anchor rows themselves are excluded by pattern.
    final topEdge = top.box.top;
    final bottomEdge = bottom.box.top + 2;
    // "X BINTI Y" / "X BIN Y" / "X BT Y" rows are the names of the next
    // sections — they never belong to the complaint text.
    final nameRe = RegExp(r'\b(BINTI|BIN|BT\.?)\b', caseSensitive: false);
    final hits = <OcrLine>[];
    for (final l in lines) {
      if (identical(l, bottom)) continue;
      final b = l.box;
      if (b.top < topEdge || b.top > bottomEdge) continue;
      if (b.left >= valueCol - 4) continue;
      var t = l.text.trim();
      if (t.isEmpty || t.startsWith('|')) continue;
      // OCR sometimes merges the Tarikh value with the first description
      // line ("31 Ju 2026 16:01 KEDUDUKAN ANGLE ...") — strip the date
      // part and keep the rest instead of dropping the whole line.
      if (dateRe.hasMatch(t)) {
        t = t.replaceFirst(dateRe, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
        if (t.isEmpty) continue;
      }
      if (_isKnownLabel(t) || nameRe.hasMatch(t)) continue;
      if (t.split(RegExp(r'\s+')).length < 2) continue;
      hits.add(OcrLine(t, b));
    }
    if (hits.isEmpty) return '';
    hits.sort((a, b) => a.box.top != b.box.top
        ? a.box.top.compareTo(b.box.top)
        : a.box.left.compareTo(b.box.left));
    return _finalizeDescription(_cleanText(hits.map((l) => l.text.trim()).join(' ')));
  }

  static bool _isGoodDescription(String s) {
    final u = s.toUpperCase();
    return u.contains('MENERIMA') || u.contains('TIDAK MENYALA') || u.contains('BAHAWA');
  }

  /// Shared tail: keep the trailing "ARAS 13" clause, drop trailing date
  /// noise, and apply sentence case ("Menerima aduan ... - aras 13").
  static String _finalizeDescription(String desc) {
    String? floorClause;
    final floorM = RegExp(r'\s*[-–]?\s*ARAS\s+[A-Z0-9]+\s*$', caseSensitive: false).firstMatch(desc);
    if (floorM != null) {
      floorClause = floorM.group(0)!.trim();
      desc = desc.substring(0, floorM.start).trimRight();
    }
    // Drop trailing date noise like "31 -U 2026 09:16" or "31 Jul 2026".
    desc = desc.replaceFirst(RegExp(r'\s*\d{1,2}\s*[-/.\s]\s*[A-Za-z0-9]{2,}\s*\d{2,4}\s*$'), '').trim();
    if (floorClause != null) {
      desc = '$desc - ${floorClause.replaceFirst(RegExp(r'^[-–]\s*'), '').toUpperCase()}';
    }
    // Sentence case: "Menerima aduan bahawa ... - aras 13".
    desc = desc.toLowerCase();
    if (desc.isNotEmpty) desc = desc[0].toUpperCase() + desc.substring(1);
    return desc;
  }

  /// Fixes common OCR misreads on this form (noise letters, common typos).
  static String _cleanText(String text) {
    var t = text;
    t = t.replaceAll('OALAM', 'DALAM').replaceAll('DALAU', 'DALAM').replaceAll('DALAW', 'DALAM');
    t = t.replaceAll('TANOAS', 'TANDAS').replaceAll('TANAS', 'TANDAS');
    t = t.replaceAll('TIOAK', 'TIDAK').replaceAll('TIDAI', 'TIDAK');
    t = t.replaceAll('KAMPIR', 'HAMPIR').replaceAll('HAUPtR', 'HAMPIR').replaceAll('HAUPIR', 'HAMPIR');
    t = t.replaceAll('KET)GA', 'KETIGA').replaceAll('KETlGA', 'KETIGA');
    t = t.replaceAll('ME NYALA', 'MENYALA');
    t = t.replaceAll('MIRORR', 'MIRROR').replaceAll('MIRRORR', 'MIRROR');
    t = t.replaceAll('DAN6', 'DAN 6');
    t = t.replaceAll('MENERIMA ADI-JAN', 'MENERIMA ADUAN').replaceAll('MENERIMA ADU-JAN', 'MENERIMA ADUAN');
    t = t.replaceAll('ADU-JAN', 'ADUAN').replaceAll('ADI-JAN', 'ADUAN');
    t = t.replaceAll('MENERIMAADUAN', 'MENERIMA ADUAN').replaceAll('ENERIRs', 'MENERIMA');
    t = t.replaceAll('HAHPIR', 'HAMPIR').replaceAll('MINGGU -', 'MINGGU -');
    t = t.replaceAllMapped(RegExp(r'\bHAMPIR(\d)', caseSensitive: false), (m) => 'HAMPIR ${m.group(1)}');
    // "TERCABUT- ARAS 31" / "MINGGU- ARAS 13" -> "TERCABUT - ARAS 31".
    t = t.replaceAllMapped(
        RegExp(r'([A-Za-z0-9])\s*-\s*(ARAS)\b', caseSensitive: false),
        (m) => '${m.group(1)} - ${m.group(2)}');
    // "31 -ADUAN JKR:" -> "31 ADUAN JKR:".
    t = t.replaceAllMapped(RegExp(r'\s*-\s*ADUAN', caseSensitive: false), (_) => ' ADUAN');
    // "DUAN BAHAWA" = "ADUAN BAHAWA" with the leading A lost — but never
    // re-add it when an A is already there ("ADUAN BAHAWA" contains
    // "DUAN BAHAWA" starting at the D).
    t = t.replaceAllMapped(RegExp(r'(?<![A-Z])DUAN\s+BAHAWA', caseSensitive: false), (_) => 'ADUAN BAHAWA');
    t = t.replaceAllMapped(RegExp(r'(?<![A-Z])DUAN\s+E\s+AHAWA', caseSensitive: false), (_) => 'ADUAN BAHAWA');
    t = t.replaceAllMapped(RegExp(r'(?<!TIDAK\s)MENYALA\s+HAMPIR', caseSensitive: false), (_) => 'TIDAK MENYALA HAMPIR');
    // OCR sometimes hallucinates garbage tokens inside an otherwise-clean
    // complaint (e.g. "MASALAH LOasi YANG SAMA"). Only drop tokens that
    // start with 2+ uppercase letters followed by lowercase — real form text
    // uses normal capitalization ("Kedudukan", "Angle"), so those survive.
    t = t.split(' ').map((w) {
      if (RegExp(r'^[A-Z]{2,}[a-z]').hasMatch(w)) return '';
      return w;
    }).where((w) => w.isNotEmpty).join(' ');
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
    return t.trim();
  }

  static String _extractFloor(String text) {
    final re = RegExp(r'\bARAS\s*[-–: ]*\s*([A-Z]{0,3}\d{1,2}|G|B[12]|M|P[0-9A]?)', caseSensitive: false);
    final m = re.firstMatch(text);
    if (m != null) {
      final f = m.group(1)!.toUpperCase();
      if (f == 'G' || f == 'M' || RegExp(r'^B[12]$').hasMatch(f) || RegExp(r'^P\d?[A]?$').hasMatch(f)) {
        return f;
      }
      return f.replaceFirst(RegExp(r'^0+'), '');
    }
    // No ARAS field on the form: infer a parking level from the asset or
    // description (e.g. "RUANG PARKIR 4A" → P4A). Restricted to the
    // building's actual parking floors so a stray number never invents one.
    const validParking = {'P1', 'P2', 'P4A', 'P5', 'P5A', 'P6'};
    final pm = RegExp(r'PARKIR\s+(\d{1,2})\s*([A-Z]?)', caseSensitive: false).firstMatch(text);
    if (pm != null) {
      final f = 'P${pm.group(1)}${(pm.group(2) ?? '').toUpperCase()}';
      if (validParking.contains(f)) return f;
    }
    return '';
  }

  static String _findKeyword(List<OcrLine> lines, List<String> keywords) {
    for (final l in lines) {
      final u = l.text.toUpperCase();
      for (final k in keywords) {
        if (RegExp(r'\b' + RegExp.escape(k) + r'\b').hasMatch(u)) {
          return k;
        }
      }
    }
    return '';
  }

  static String _findAsset(List<OcrLine> lines, String? issueType) {
    // Asset line looks like "G.15.009- TANDAS WANITA", "G.1509 TANDAS WANITA"
    // or "JKRBG26002742 G.15.009" — ID prefix (dotted or alphanumeric)
    // followed by a short uppercase description. OCR sometimes splits the
    // ID and its description across lines ("G.02.061." / "RUANG PARKIR"),
    // so bare ID lines are joined with the lines below.
    final re = RegExp(r'\b([A-Z]\.[A-Z0-9.\-]+|[A-Z]{2}\d{3,})\s+[A-Z].{3,}$');
    final reBare = RegExp(r'^[A-Z]\.[A-Z0-9.\-]+\s*$');
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].text.trim();
      final u = t.toUpperCase();
      if (t.length < 6) continue;
      final m = re.firstMatch(t);
      final bare = m == null && reBare.hasMatch(t);
      if ((m != null || bare) && !u.contains('ARAS') && !_isDescriptionLine(u)) {
        final result = _joinAssetLines(lines, i);
        if (bare && re.firstMatch(result) == null) continue;
        return result;
      }
    }
    // Fallback: line mentioning known asset keywords.
    final assetWords = RegExp(r'\b(TANDAS|LAMPU|LIF|AHU|FCU|PAM|PANEL|TANGKI|PINTU|TINGKAP)\b');
    for (final l in lines) {
      final u = l.text.toUpperCase();
      if (assetWords.hasMatch(u) && !u.contains('ARAS') && !_isDescriptionLine(u) && u.length < 40) {
        return l.text.trim();
      }
    }
    return '';
  }

  /// Joins the line at [i] with the 1-2 lines directly below it while they
  /// look like a continuation of the same text (height-relative so zoomed
  /// photos still join) and aren't labels or complaint text.
  static String _joinAssetLines(List<OcrLine> lines, int i) {
    var result = lines[i].text.trim();
    for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
      final n = lines[j];
      final cand = lines[i];
      if (n.box.top - cand.box.top <= cand.box.height * 2 &&
          (n.box.left - cand.box.left).abs() <= cand.box.height * 1.2 &&
          !_isKnownLabel(n.text.trim()) &&
          !_isDescriptionLine(n.text.toUpperCase())) {
        result = '$result ${n.text.trim()}';
      } else {
        break;
      }
    }
    return result;
  }

  static bool _isDescriptionLine(String u) {
    return u.contains('ADUAN') || u.contains('DUAN') || u.contains('BAHAWA')
        || u.contains('MENERIMA') || u.contains('MINGGU') || u.contains('MENYALA');
  }

  static const List<String> _issueTypes = [
    'ELECTRICAL', 'MECHANICAL', 'CIVIL', 'LANDSCAPE', 'ARCHITECTURAL',
  ];

  static const List<String> _categories = [
    'CORRECTIVE', 'PREVENTIVE', 'PREDICTIVE', 'EMERGENCY', 'ROUTINE',
  ];

  static const List<String> _priorities = [
    'URGENT', 'NORMAL', 'HIGH', 'MEDIUM', 'LOW', 'CRITICAL',
  ];

  /// Maps the app's issue-type dropdown keys to keyword hints.
  static const Map<String, List<String>> issueHints = {
    'lift': ['LIF', 'LIFT'],
    'chiller': ['CHILLER'],
    'ahu': ['AHU', 'AIR HANDLING'],
    'pump': ['PAM', 'PUMP'],
    'fcu': ['FCU'],
    'cooling_tower': ['COOLING TOWER', 'MENARA PENYEJUK'],
    'tank': ['TANGKI', 'TANK'],
    'panel': ['PANEL'],
    'toilet': ['TANDAS', 'TANDAS WANITA', 'TANDAS LELAKI', 'TOILET'],
    'pantry': ['PANTRY'],
    'escalator': ['ESCALATOR'],
    'door': ['PINTU', 'DOOR'],
    'window': ['TINGKAP', 'WINDOW'],
    'lighting': ['LAMPU', 'LIGHTING', 'CAHAYA'],
    'plumbing': ['PAIP', 'PLUMBING', 'PIPA'],
  };

  static String matchIssueType(String text, {String? ocrIssueType}) {
    if (ocrIssueType != null && ocrIssueType.isNotEmpty) {
      final u = ocrIssueType.toUpperCase();
      if (u == 'MECHANICAL') {
        for (final entry in issueHints.entries) {
          if (entry.value.any((h) => text.toUpperCase().contains(h))) {
            return entry.key;
          }
        }
        return 'other';
      }
      if (u == 'ELECTRICAL') {
        for (final entry in issueHints.entries) {
          if (entry.value.any((h) => text.toUpperCase().contains(h))) {
            return entry.key;
          }
        }
        return 'lighting';
      }
      if (u == 'CIVIL') {
        for (final entry in {'door': ['PINTU', 'DOOR'], 'window': ['TINGKAP', 'WINDOW']}.entries) {
          if (entry.value.any((h) => text.toUpperCase().contains(h))) {
            return entry.key;
          }
        }
        return 'other';
      }
    }
    for (final entry in issueHints.entries) {
      if (entry.value.any((h) => text.toUpperCase().contains(h))) {
        return entry.key;
      }
    }
    return 'other';
  }
}

class OcrLine {
  final String text;
  final Rect box;
  const OcrLine(this.text, this.box);
}
