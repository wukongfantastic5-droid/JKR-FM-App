import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'cm_service.dart';
import 'zip_writer.dart';

/// Builds the CM report .docx from the boss-approved Word template
/// (TEMPLATE GAMBAR ADUAN MEKANIKAL.docx, bundled as an asset).
///
/// The template layout is preserved byte-for-byte; only these are patched:
///   - NO. RUJUKAN example "JKRBG26002582" -> the actual WO id
///   - TARIKH example date runs            -> closing date (d/M/yyyy)
///   - "ARAS 23"                           -> `ARAS <floor>`
///   - the SEBELUM sample photo            -> before photo (same box size)
///   - SEMASA / SELEPAS photo cells        -> cloned floating picture for
///     the during / after photos (identical size + position)
///   - the three bottom-right date stamps  -> closing date, bold + red
///
/// Columns without a photo are left exactly as the template (nothing is
/// invented). The floating date rectangles keep a higher z-order than the
/// photos so the date always renders on top of the image.
class CmDocxService {
  static String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static const String _arialBold =
      '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:b/><w:bCs/></w:rPr>';

  // Template example NO. RUJUKAN / TARIKH / ARAS tokens (analysis dump:
  // %TEMP%\opencode\cm_tpl\doc_pretty.xml).
  static const String _tplRefTag = '<w:t>JKRBG26002582</w:t>';
  static const String _tplArasTag = '<w:t>ARAS 23</w:t>';
  static const String _tplDateRun = '<w:r><w:t>29/07/2026</w:t></w:r>';
  static const String _tplTarikhRuns = '<w:r>$_arialBold<w:t>24/</w:t></w:r>'
      '<w:r w:rsidRPr="0082682A">$_arialBold<w:t>0</w:t></w:r>'
      '<w:r>$_arialBold<w:t>7</w:t></w:r>'
      '<w:r w:rsidRPr="0082682A">$_arialBold<w:t>/2026</w:t></w:r>';
  static const String _redStampRpr =
      '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>'
      '<w:b/><w:bCs/><w:color w:val="C00000"/></w:rPr>';

  // Date rectangles per photo column and the z-order (relativeHeight) the
  // photos must stay BELOW so the red date stamps remain visible.
  static const int _sesudahRelH = 251660180;
  static const int _semasaRelH = 251661180;
  static const int _selepasRelH = 251662180;

  /// Builds the full .docx bytes for the given work order.
  static Future<Uint8List> build(CmWorkOrder wo, DateTime closedOn) async {
    final tpl = await rootBundle.load('assets/cm_report_template.docx');
    final archive = ZipDecoder().decodeBytes(tpl.buffer.asUint8List());
    final docF = archive.findFile('word/document.xml');
    final relsF = archive.findFile('word/_rels/document.xml.rels');
    if (docF == null || relsF == null) {
      throw StateError('template missing word/document.xml');
    }
    var xml = utf8.decode(docF.content as List<int>);
    var rels = utf8.decode(relsF.content as List<int>);

    final media = <String, Uint8List>{};
    final mediaIds = <String, String>{};
    var nextRid = 8;
    String embed(Uint8List bytes) {
      final ext = bytes.isNotEmpty && bytes[0] == 0x89 ? 'png' : 'jpeg';
      final id = 'rId$nextRid';
      final path = 'word/media/image$nextRid.$ext';
      media[path] = bytes;
      mediaIds[path] = id;
      nextRid++;
      return id;
    }

    Uint8List? firstPhoto(List<String> list) {
      for (final p in list) {
        try {
          var data = p.trim();
          if (data.isEmpty) continue;
          final c = data.indexOf(',');
          if (c > 0 && data.substring(0, c).contains('base64')) {
            data = data.substring(c + 1);
          }
          final bytes = base64Decode(data);
          if (bytes.isNotEmpty) return Uint8List.fromList(bytes);
        } catch (_) {}
      }
      return null;
    }

    final photos = [
      firstPhoto(wo.photosBefore),
      firstPhoto(wo.photosDuring),
      firstPhoto(wo.photosAfter),
    ];

    // ---------- text fills (index-independent) ----------
    final dateStr = '${closedOn.day}/${closedOn.month}/${closedOn.year}';
    xml = xml.replaceAll(_tplRefTag, '<w:t>${_esc(wo.id)}</w:t>');
    xml = xml.replaceAll(
        _tplTarikhRuns, '<w:r>$_arialBold<w:t>${_esc(dateStr)}</w:t></w:r>');
    // ARAS cell keeps the exact value chosen at WO creation (e.g. "Aras 6");
    // never prepend "ARAS " again or it duplicates.
    final floor = wo.floor.trim();
    if (floor.isNotEmpty) {
      xml = xml.replaceAll(_tplArasTag, '<w:t>${_esc(floor)}</w:t>');
    }

    // ---------- photo boxes ----------
    // The template only ships ONE floating picture (the SEBELUM sample,
    // docPr "Picture 3"); the SEMASA / SELEPAS boxes are empty cells with
    // only their date rectangle. We re-use that same floating picture XML,
    // swap its relationship + z-order, and clone it into the other two cells.
    final picIdx = xml.indexOf('name="Picture 3"');
    if (picIdx < 0) throw StateError('template picture not found');
    final picRunStart = xml.lastIndexOf('<w:r>', picIdx);
    final picRunEnd = xml.indexOf('</w:r>', picIdx) + 6;
    final baseRun = xml.substring(picRunStart, picRunEnd);

    String photoRun(String src, String rid, int relH,
        {String anchor = '', String edit = '', String docId = '', String picName = ''}) {
      var s = src.replaceAll('r:embed="rId5"', 'r:embed="$rid"');
      s = s.replaceAll('relativeHeight="251663360"', 'relativeHeight="$relH"');
      if (anchor.isNotEmpty) {
        s = s.replaceAll('wp14:anchorId="3E791B30"', 'wp14:anchorId="$anchor"');
      }
      if (edit.isNotEmpty) {
        s = s.replaceAll('wp14:editId="21578583"', 'wp14:editId="$edit"');
      }
      if (docId.isNotEmpty) {
        s = s.replaceFirst('<wp:docPr id="3" name="Picture 3"/>',
            '<wp:docPr id="$docId" name="$picName"/>');
        s = s.replaceFirst('name="Picture 2"', 'name="$picName"');
      }
      return s;
    }

    int rectRunStart(String x, String rectName) {
      final i = x.indexOf('name="Rectangle $rectName"');
      return x.lastIndexOf('<w:r>', i);
    }

    // Insertion point inside the FIRST paragraph of the photo cell that owns
    // the given date rectangle (right after its pPr) — the same spot the
    // template uses for its own SEBELUM photo.
    int cellFirstParaInsert(String x, String rectName) {
      final s = rectRunStart(x, rectName);
      final tc = x.lastIndexOf('<w:tc>', s);
      final firstP = x.indexOf('<w:p ', tc);
      return x.indexOf('</w:pPr>', firstP) + 8;
    }

    // Date stamp for one column: both the mc:Choice textbox and the
    // mc:Fallback v:textbox carry the example date <w:r><w:t>29/07/2026</w:t></w:r>.
    String stampColumn(String x, String rectName, String stamp) {
      final s = rectRunStart(x, rectName);
      final altEnd = x.indexOf('</mc:AlternateContent>', s);
      if (altEnd < 0) return x;
      final e = x.indexOf('</w:r>', altEnd) + 6;
      final seg = x.substring(s, e);
      final patched = seg.replaceAll(
          _tplDateRun, '<w:r>$_redStampRpr<w:t>${_esc(stamp)}</w:t></w:r>');
      return x.replaceRange(s, e, patched);
    }

    // SEBELUM — the template's own sample photo slot.
    final before = photos[0];
    if (before != null) {
      final rid = embed(before);
      xml = xml.replaceRange(picRunStart, picRunEnd,
          photoRun(baseRun, rid, _sesudahRelH));
      xml = stampColumn(xml, '1287', dateStr);
    }

    // SEMASA — clone the floating picture into the empty cell. The clone
    // MUST land in the cell's FIRST paragraph (like the template's own
    // SEBELUM photo); anchoring it deeper makes Word grow the 3358-twip row
    // and pushes the SELEPAS row onto page 2.
    final during = photos[1];
    if (during != null) {
      final rid = embed(during);
      xml = xml.replaceRange(
          cellFirstParaInsert(xml, '1288'),
          cellFirstParaInsert(xml, '1288'),
          photoRun(baseRun, rid, _semasaRelH,
              anchor: 'A1000001',
              edit: 'B2000001',
              docId: '1291',
              picName: 'Picture 5'));
      xml = stampColumn(xml, '1288', dateStr);
    }

    // SELEPAS — clone the floating picture into the empty cell.
    final after = photos[2];
    if (after != null) {
      final rid = embed(after);
      xml = xml.replaceRange(
          cellFirstParaInsert(xml, '1289'),
          cellFirstParaInsert(xml, '1289'),
          photoRun(baseRun, rid, _selepasRelH,
              anchor: 'A1000002',
              edit: 'B2000002',
              docId: '1292',
              picName: 'Picture 6'));
      xml = stampColumn(xml, '1289', dateStr);
    }

    // ---------- relationship + media ----------
    if (media.isNotEmpty) {
      final sb = StringBuffer();
      mediaIds.forEach((path, id) {
        sb.write('<Relationship Id="$id" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
            'Target="media/${path.split('/').last}"/>');
      });
      rels = rels.replaceAll('</Relationships>', '$sb</Relationships>');
    }

    final files = <String, List<int>>{};
    for (final f in archive) {
      if (f.isFile) files[f.name] = f.content as List<int>;
    }
    files['word/document.xml'] = utf8.encode(xml);
    files['word/_rels/document.xml.rels'] = utf8.encode(rels);
    files.addAll(media);

    return ZipWriter.store(files);
  }

  /// Saves the report locally to Downloads\FM_Report\CM_Report\<id>\<id>.docx
  /// (desktop only). Returns the saved folder path, or '' if unsupported.
  static String saveLocally(String id, Uint8List bytes) {
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];
      if (home == null || home.isEmpty) return '';
      var downloads = Directory('$home\\Downloads');
      if (!downloads.existsSync()) downloads = Directory('$home/Downloads');
      final dir = Directory('${downloads.path}\\FM_Report\\CM_Report\\$id');
      dir.createSync(recursive: true);
      File('${dir.path}\\$id.docx').writeAsBytesSync(bytes);
      return dir.path;
    } catch (e) {
      return '';
    }
  }
}