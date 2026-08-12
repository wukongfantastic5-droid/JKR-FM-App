import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

import 'zip_writer.dart';

/// Field row (label → value) rendered in a bordered table.
class RepairField {
  final String label;
  final String value;
  const RepairField(this.label, this.value);
}

/// Photo attachment with caption (rendered 2 per row).
class RepairPhoto {
  final Uint8List bytes;
  final String caption;
  const RepairPhoto(this.bytes, this.caption);
}

/// Generic branded DOCX builder for all repair-guide documents:
/// CMSB logo header + JKR header, teal banner, field table, item table,
/// photo grid and the Zainalabidin signature block. Uses the same
/// hand-rolled STORE ZIP that Word accepts (see cm_docx.dart).
class RepairDocxService {
  static const _ns =
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"';

  static const int _teal = 0x0D7377;
  static const int _darkTeal = 0x0B5559;
  static const int _blue = 0x1D4ED8;
  static const int _greyText = 0x9CA3AF;
  static const int _darkText = 0x1F2937;

  static String _hex(int v) => v.toRadixString(16).padLeft(6, '0').toUpperCase();

  static String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static String _run(String text,
      {bool bold = false, int sizePt = 10, int? color, bool italic = false}) {
    final colorAttr = color == null ? '' : ' w:color="${_hex(color)}"';
    final italAttr = italic ? ' w:i="1"' : '';
    return '<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>'
        '<w:sz w:val="${sizePt * 2}"/><w:szCs w:val="${sizePt * 2}"/>'
        '<w:b w:val="${bold ? 1 : 0}"/>$italAttr$colorAttr</w:rPr>'
        '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r>';
  }

  static String _para(List<String> runs,
      {String align = 'left', int spaceAfter = 0, int spaceBefore = 0, double? line}) {
    final al = {'left': 'start', 'center': 'center', 'right': 'end'}[align]!;
    return '<w:p><w:pPr><w:jc w:val="$al"/>'
        '<w:spacing w:after="$spaceAfter" w:before="$spaceBefore" w:line="${(line ?? 240).round()}" w:lineRule="auto"/></w:pPr>'
        '${runs.join()}</w:p>';
  }

  static String _picture(String rId, int cxEmu, int cyEmu, int docId) => '''
<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:before="40" w:after="40"/></w:pPr>
<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">
<wp:extent cx="$cxEmu" cy="$cyEmu"/>
<wp:effectExtent l="0" t="0" r="0" b="0"/>
<wp:docPr id="$docId" name="Image $rId"/>
<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>
<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
<pic:pic><pic:nvPicPr><pic:cNvPr id="$docId" name="Image $rId"/><pic:cNvPicPr/></pic:nvPicPr>
<pic:blipFill><a:blip r:embed="$rId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cxEmu" cy="$cyEmu"/></a:xfrm>
<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>
</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>''';

  static ({int w, int h}) _sizeOf(Uint8List bytes) {
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      return (w: w, h: h);
    }
    var off = 2;
    while (off + 9 < bytes.length) {
      if (bytes[off] != 0xFF) {
        off++;
        continue;
      }
      final next = bytes[off + 1];
      if (next >= 0xC0 && next <= 0xCF && next != 0xC4 && next != 0xC8 && next != 0xCC) {
        final h = (bytes[off + 5] << 8) | bytes[off + 6];
        final w = (bytes[off + 7] << 8) | bytes[off + 8];
        if (w > 0 && h > 0) return (w: w, h: h);
        break;
      }
      final len = ((bytes[off + 2] << 8) | bytes[off + 3]) & 0x7FFF;
      off += 2 + len;
    }
    return (w: 800, h: 600);
  }

  static Future<Uint8List> build({
    required String title,
    required String titleEn,
    required String refNo,
    required String dateStr,
    List<RepairField> fields = const [],
    List<String> paragraphs = const [],
    List<String> tableHeader = const [],
    List<List<String>> tableRows = const [],
    /// One photo per table row (column = last table column). Null/empty = '-'.
    List<Uint8List?> tableImages = const [],
    /// Per-column widths in cm when a custom layout is wanted.
    List<double> colWidthsCm = const [],
    List<RepairPhoto> photos = const [],
    String preparedBy = 'ZAINALABIDIN BIN CHE HASSAN',
    String designation = 'Jurutera Mekanikal',
    String reviewer = 'JURUTERA MEKANIKAL (FM)',
  }) async {
    final cmsb = (await rootBundle.load('assets/images/logo_cmsb.png')).buffer.asUint8List();
    final jkr = (await rootBundle.load('assets/images/logo_jkr.jpg')).buffer.asUint8List();

    const cmEmu = 360000;
    const twipsPerCm = 567;
    final imageIds = <String, String>{};
    final media = <String, Uint8List>{
      'word/media/logo1.png': cmsb,
      'word/media/logo2.jpg': jkr,
    };
    var rid = 12;
    var picDocId = 10;
    String embed(Uint8List bytes, String ext) {
      final id = 'rId$rid';
      rid++;
      final path = 'word/media/img$id.$ext';
      media[path] = bytes;
      imageIds[path] = id;
      return id;
    }

    const logo1Id = 'rId10';
    const logo2Id = 'rId11';
    final logo1Size = _sizeOf(cmsb);
    final logo2Size = _sizeOf(jkr);
    const logoWCm = 2.6;
    final logo1Cx = (logoWCm * 360000).round();
    final logo1Cy = (logo1Cx * logo1Size.h / logo1Size.w).round();
    final logo2Cx = (logoWCm * 360000).round();
    final logo2Cy = (logo2Cx * logo2Size.h / logo2Size.w).round();

    final leftLines = <String>[
      '<w:p><w:pPr><w:spacing w:before="20" w:after="20"/></w:pPr>'
          '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
          '<wp:extent cx="$logo1Cx" cy="$logo1Cy"/>'
          '<wp:docPr id="1" name="Logo1"/><wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
          '<pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="Logo1"/><pic:cNvPicPr/></pic:nvPicPr>'
          '<pic:blipFill><a:blip r:embed="$logo1Id"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
          '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$logo1Cx" cy="$logo1Cy"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
          '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>',
      _para([_run('CAKRA MAHKOTA SDN. BHD.', bold: true, sizePt: 10, color: _darkTeal)]),
      _para([_run('G7, B09 & CE14, No. 13B, Tingkat 2, Blok 4,', sizePt: 8)]),
      _para([_run('Pusat Perniagaan WorldWide, Jalan Karate 13/47,', sizePt: 8)]),
      _para([_run('Seksyen 13, 40675 Petaling Jaya, Selangor.', sizePt: 8)]),
      _para([_run('Tel: 03-1234 5678', sizePt: 8, bold: true, color: _darkTeal)]),
    ].join();
    final rightLines = <String>[
      '<w:p><w:pPr><w:jc w:val="end"/><w:spacing w:before="20" w:after="20"/></w:pPr>'
          '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
          '<wp:extent cx="$logo2Cx" cy="$logo2Cy"/>'
          '<wp:docPr id="2" name="Logo2"/><wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
          '<pic:pic><pic:nvPicPr><pic:cNvPr id="2" name="Logo2"/><pic:cNvPicPr/></pic:nvPicPr>'
          '<pic:blipFill><a:blip r:embed="$logo2Id"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
          '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$logo2Cx" cy="$logo2Cy"/></a:xfrm>'
          '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>'
          '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>',
      _para([_run('JABATAN KERJA RAYA MALAYSIA', bold: true, sizePt: 10, color: _darkText)], align: 'right'),
      _para([_run('Blok G, Ibu Pejabat JKR, Menara Kerja Raya,', sizePt: 8)], align: 'right'),
      _para([_run('Jalan Sultan Salahuddin, 50400 Kuala Lumpur.', sizePt: 8)], align: 'right'),
      _para([_run('Tel: 03-2618 8799', sizePt: 8, bold: true, color: _darkText)], align: 'right'),
    ].join();

    final headerTable = '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblLayout w:type="fixed"/>'
        '<w:tblBorders><w:top w:val="none" w:sz="0" w:color="auto"/><w:left w:val="none" w:sz="0" w:color="auto"/>'
        '<w:bottom w:val="none" w:sz="0" w:color="auto"/><w:right w:val="none" w:sz="0" w:color="auto"/>'
        '<w:insideH w:val="none" w:sz="0" w:color="auto"/><w:insideV w:val="none" w:sz="0" w:color="auto"/>'
        '</w:tblBorders></w:tblPr><w:tblGrid>'
        '<w:gridCol w:w="${(9.1 * twipsPerCm).round()}"/><w:gridCol w:w="${(9.1 * twipsPerCm).round()}"/>'
        '</w:tblGrid>'
        '<w:tr><w:tc><w:tcPr><w:tcW w:w="${(9.1 * twipsPerCm).round()}" w:type="dxa"/></w:tcPr>'
        '$leftLines</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="${(9.1 * twipsPerCm).round()}" w:type="dxa"/></w:tcPr>'
        '$rightLines</w:tc></w:tr></w:tbl>';

    final banner = '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblLayout w:type="fixed"/>'
        '<w:tblBorders><w:top w:val="single" w:sz="8" w:color="${_hex(_teal)}"/>'
        '<w:bottom w:val="single" w:sz="8" w:color="${_hex(_teal)}"/></w:tblBorders></w:tblPr>'
        '<w:tblGrid><w:gridCol w:w="${(18.2 * twipsPerCm).round()}"/></w:tblGrid>'
        '<w:tr><w:tc><w:tcPr><w:tcW w:w="${(18.2 * twipsPerCm).round()}" w:type="dxa"/>'
        '<w:shd w:val="clear" w:color="auto" w:fill="${_hex(_teal)}"/></w:tcPr>'
        '${_para([_run(title, bold: true, sizePt: 16, color: 0xFFFFFF)], align: 'center', spaceBefore: 120, spaceAfter: 40)}'
        '${_para([_run(titleEn, sizePt: 8, color: 0xD7EFEA)], align: 'center', spaceAfter: 120)}'
        '</w:tc></w:tr></w:tbl>';

    final refTable = '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblLayout w:type="fixed"/>'
        '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="9AA5B1"/><w:left w:val="single" w:sz="4" w:color="9AA5B1"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="9AA5B1"/><w:right w:val="single" w:sz="4" w:color="9AA5B1"/>'
        '<w:insideH w:val="single" w:sz="4" w:color="9AA5B1"/><w:insideV w:val="single" w:sz="4" w:color="9AA5B1"/>'
        '</w:tblBorders></w:tblPr><w:tblGrid>'
        '<w:gridCol w:w="${(4.3 * twipsPerCm).round()}"/><w:gridCol w:w="${(4.8 * twipsPerCm).round()}"/>'
        '<w:gridCol w:w="${(4.3 * twipsPerCm).round()}"/><w:gridCol w:w="${(4.8 * twipsPerCm).round()}"/>'
        '</w:tblGrid>'
        '<w:tr>'
        '<w:tc><w:tcPr><w:tcW w:w="${(4.3 * twipsPerCm).round()}" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="${_hex(_darkTeal)}"/><w:vAlign w:val="center"/></w:tcPr>'
        '${_para([_run('NO. RUJUKAN', bold: true, sizePt: 9, color: 0xFFFFFF)], align: 'center')}</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="${(4.8 * twipsPerCm).round()}" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
        '${_para([_run(refNo, bold: true, sizePt: 10)], spaceBefore: 120, spaceAfter: 120)}</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="${(4.3 * twipsPerCm).round()}" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="${_hex(_darkTeal)}"/><w:vAlign w:val="center"/></w:tcPr>'
        '${_para([_run('TARIKH', bold: true, sizePt: 9, color: 0xFFFFFF)], align: 'center')}</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="${(4.8 * twipsPerCm).round()}" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
        '${_para([_run(dateStr, bold: true, sizePt: 10)], spaceBefore: 120, spaceAfter: 120)}</w:tc>'
        '</w:tr></w:tbl>';

    final labelW = (5.2 * twipsPerCm).round();
    final valueW = (13.0 * twipsPerCm).round();
    String cell(String label, String value, {bool head = false}) =>
        '<w:tc><w:tcPr><w:tcW w:w="${head ? labelW : valueW}" w:type="dxa"/>'
        '${head ? '<w:shd w:val="clear" w:color="auto" w:fill="${_hex(_darkTeal)}"/><w:vAlign w:val="center"/>' : '<w:vAlign w:val="center"/>'}</w:tcPr>'
        '${head ? _para([_run(label, bold: true, sizePt: 9, color: 0xFFFFFF)], align: 'center') : _para([_run(label, sizePt: 10)], spaceBefore: 60, spaceAfter: 60)}</w:tc>';

    final fieldsXml = fields.isEmpty
        ? ''
        : '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblLayout w:type="fixed"/>'
            '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="9AA5B1"/><w:left w:val="single" w:sz="4" w:color="9AA5B1"/>'
            '<w:bottom w:val="single" w:sz="4" w:color="9AA5B1"/><w:right w:val="single" w:sz="4" w:color="9AA5B1"/>'
            '<w:insideH w:val="single" w:sz="4" w:color="9AA5B1"/><w:insideV w:val="single" w:sz="4" w:color="9AA5B1"/>'
            '</w:tblBorders></w:tblPr><w:tblGrid>'
            '<w:gridCol w:w="$labelW"/><w:gridCol w:w="$valueW"/></w:tblGrid>'
            '${fields.map((f) => '<w:tr>${cell(f.label, '', head: true)}${cell(f.value, '')}</w:tr>').join()}'
            '</w:tbl>';

    final paragraphsXml = paragraphs
        .map((p) => _para([_run(p, sizePt: 10)], spaceAfter: 60))
        .join();

    String itemTable() {
      if (tableHeader.isEmpty) return '';
      final colW = (18.2 * twipsPerCm).round();
      String th(String text, int w) =>
          '<w:tc><w:tcPr><w:tcW w:w="$w" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="${_hex(_teal)}"/><w:vAlign w:val="center"/></w:tcPr>'
          '${_para([_run(text, bold: true, sizePt: 9, color: 0xFFFFFF)], align: 'center')}</w:tc>';
      String td(String text, int w, {String align = 'left'}) =>
          '<w:tc><w:tcPr><w:tcW w:w="$w" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
          '${_para([_run(text, sizePt: 9, bold: align == 'right')], align: align, spaceBefore: 40, spaceAfter: 40)}</w:tc>';
      String imageCell(Uint8List? bytes, int w) {
        if (bytes == null || bytes.length < 8) return td('-', w, align: 'center');
        try {
          final sz = _sizeOf(bytes);
          final id = embed(bytes, bytes[0] == 0x89 ? 'png' : 'jpg');
          final photoW = (6.0 * cmEmu).round();
          var h = (photoW * sz.h / sz.w).round();
          final maxH = (4.6 * cmEmu).round();
          if (h > maxH) h = maxH;
          return '<w:tc><w:tcPr><w:tcW w:w="$w" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
              '${_picture(id, photoW, h, picDocId++)}</w:tc>';
        } catch (_) {
          return td('-', w, align: 'center');
        }
      }
      final nCols = tableHeader.length;
      final widths = colWidthsCm.isNotEmpty
          ? colWidthsCm.map((c) => (c * twipsPerCm).round()).toList()
          : nCols == 4
              ? [(8.6 * twipsPerCm).round(), (2.6 * twipsPerCm).round(), (3.5 * twipsPerCm).round(), (3.5 * twipsPerCm).round()]
              : [for (var i = 0; i < nCols; i++) (colW ~/ nCols)];
      final head = '<w:tr>${List.generate(nCols, (i) => th(tableHeader[i], widths[i])).join()}</w:tr>';
      final body = tableRows.asMap().entries.map((e) {
        final i = e.key;
        final r = e.value;
        final cells = <String>[];
        for (var j = 0; j < nCols; j++) {
          final align = j >= nCols - 2 ? 'right' : 'left';
          if (tableImages.isNotEmpty &&
              tableImages.length > i &&
              j == nCols - 1) {
            cells.add(imageCell(tableImages[i], widths[j]));
          } else {
            cells.add(td(r[j], widths[j], align: align));
          }
        }
        return '<w:tr>${cells.join()}</w:tr>';
      }).join();
      return '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblLayout w:type="fixed"/>'
          '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="9AA5B1"/><w:left w:val="single" w:sz="4" w:color="9AA5B1"/>'
          '<w:bottom w:val="single" w:sz="4" w:color="9AA5B1"/><w:right w:val="single" w:sz="4" w:color="9AA5B1"/>'
          '<w:insideH w:val="single" w:sz="4" w:color="9AA5B1"/><w:insideV w:val="single" w:sz="4" w:color="9AA5B1"/>'
          '</w:tblBorders></w:tblPr><w:tblGrid>'
          '${widths.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>$head$body</w:tbl>';
    }

    // ---------- PHOTO GRID (2 per row) ----------
    var photoXml = '';
    if (photos.isNotEmpty) {
      final pw = (8.6 * cmEmu).round();
      String photoCell(RepairPhoto p) {
        final sz = _sizeOf(p.bytes);
        final id = embed(p.bytes, p.bytes[0] == 0x89 ? 'png' : 'jpg');
        final h = (pw * sz.h / sz.w).round();
        return '<w:tc><w:tcPr><w:tcW w:w="${(9.1 * twipsPerCm).round()}" w:type="dxa"/></w:tcPr>'
            '${_picture(id, pw, h, picDocId++)}'
            '${_para([_run(p.caption, sizePt: 8, bold: true, color: _darkTeal)], align: 'center', spaceAfter: 80)}'
            '</w:tc>';
      }
      final rows = <String>[];
      for (var i = 0; i < photos.length; i += 2) {
        final pair = photos.skip(i).take(2).toList();
        final cellsXml = pair.map(photoCell).join();
        final pad = pair.length < 2
            ? '<w:tc><w:tcPr><w:tcW w:w="${(9.1 * twipsPerCm).round()}" w:type="dxa"/></w:tcPr></w:tc>'
            : '';
        rows.add('<w:tr>$cellsXml$pad</w:tr>');
      }
      photoXml = '<w:p/><w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblLayout w:type="fixed"/>'
          '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="9AA5B1"/><w:left w:val="single" w:sz="4" w:color="9AA5B1"/>'
          '<w:bottom w:val="single" w:sz="4" w:color="9AA5B1"/><w:right w:val="single" w:sz="4" w:color="9AA5B1"/>'
          '<w:insideH w:val="single" w:sz="4" w:color="9AA5B1"/><w:insideV w:val="single" w:sz="4" w:color="9AA5B1"/>'
          '</w:tblBorders></w:tblPr><w:tblGrid>'
          '<w:gridCol w:w="${(9.1 * twipsPerCm).round()}"/><w:gridCol w:w="${(9.1 * twipsPerCm).round()}"/>'
          '</w:tblGrid>${rows.join()}</w:tbl>';
    }

    final sigW = (9.1 * twipsPerCm).round();
    final sigLeft = _para([_run('DISEDIAKAN OLEH:', bold: true, sizePt: 9, color: _darkTeal)], spaceBefore: 60)
        + _para([_run(preparedBy, bold: true, sizePt: 11, color: _blue)], spaceBefore: 200, spaceAfter: 40)
        + _para([_run('Jawatan: $designation', sizePt: 11, bold: true)])
        + _para([_run('Tarikh: $dateStr', sizePt: 9)])
        + _para([_run('Tandatangan & Cop:', sizePt: 9)], spaceBefore: 120)
        + _para([_run('', sizePt: 9)], spaceBefore: 300, spaceAfter: 300);
    final sigRight = _para([_run('DISEMAK / DILULUSKAN OLEH:', bold: true, sizePt: 9, color: _darkTeal)], spaceBefore: 60)
        + _para([_run(reviewer, bold: true, sizePt: 10, color: _darkText)], spaceBefore: 200, spaceAfter: 40)
        + _para([_run('Jabatan / Department:', sizePt: 9)])
        + _para([_run('Tarikh:', sizePt: 9)], spaceBefore: 120)
        + _para([_run('Tandatangan & Cop:', sizePt: 9)], spaceBefore: 120)
        + _para([_run('', sizePt: 9)], spaceBefore: 300, spaceAfter: 300);
    final sigTable = '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblLayout w:type="fixed"/>'
        '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="9AA5B1"/><w:left w:val="single" w:sz="4" w:color="9AA5B1"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="9AA5B1"/><w:right w:val="single" w:sz="4" w:color="9AA5B1"/>'
        '<w:insideH w:val="single" w:sz="4" w:color="9AA5B1"/><w:insideV w:val="single" w:sz="4" w:color="9AA5B1"/>'
        '</w:tblBorders></w:tblPr><w:tblGrid>'
        '<w:gridCol w:w="$sigW"/><w:gridCol w:w="$sigW"/></w:tblGrid>'
        '<w:tr><w:tc><w:tcPr><w:tcW w:w="$sigW" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
        '$sigLeft</w:tc>'
        '<w:tc><w:tcPr><w:tcW w:w="$sigW" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>'
        '$sigRight</w:tc></w:tr></w:tbl>';

    final footer = _para([
      _run('CAKRA MAHKOTA SDN. BHD.  •  JABATAN KERJA RAYA MALAYSIA  •  Pengurusan Aspek (Fasiliti)',
          sizePt: 7, color: _greyText),
    ], align: 'center', spaceBefore: 200);

    final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document $_ns><w:body>'
        '$headerTable<w:p/>$banner<w:p/>$refTable<w:p/>$fieldsXml'
        '${fields.isEmpty ? '' : '<w:p/>'}$paragraphsXml'
        '${tableHeader.isNotEmpty ? '<w:p/>${itemTable()}' : ''}'
        '$photoXml<w:p/>$sigTable<w:p/>$footer'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="567" w:right="794" w:bottom="567" w:left="794" w:header="720" w:footer="720" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';

    final contentType = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Default Extension="png" ContentType="image/png"/>'
        '<Default Extension="jpg" ContentType="image/jpeg"/>'
        '<Default Extension="jpeg" ContentType="image/jpeg"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';

    final rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final imageRels = media.entries.map((e) {
      final name = e.key.split('/').last;
      final id = e.key == 'word/media/logo1.png'
          ? 'rId10'
          : e.key == 'word/media/logo2.jpg'
              ? 'rId11'
              : imageIds[e.key]!;
      return '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$name"/>';
    }).join();

    final docRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$imageRels</Relationships>';

    final files = <String, List<int>>{
      '[Content_Types].xml': utf8.encode(contentType),
      '_rels/.rels': utf8.encode(rootRels),
      'word/document.xml': utf8.encode(documentXml),
      'word/_rels/document.xml.rels': utf8.encode(docRels),
      ...media,
    };

    return ZipWriter.store(files);
  }
}

/// Extracts the base64 body from `data:image/...;base64,...` strings.
String b64FromDataUri(String? uri) {
  if (uri == null || uri.isEmpty) return '';
  final idx = uri.indexOf(',');
  return idx < 0 ? uri : uri.substring(idx + 1);
}

/// Base64-encodes bytes (standard, no line breaks) for repo upload.
String base64Of(Uint8List bytes) => base64Encode(bytes);