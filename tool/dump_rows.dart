import 'dart:io';
import 'package:jkr_fm_guide/services/quotation_pdf.dart';

void main(List<String> args) {
  final path =
      args.isNotEmpty ? args[0] : r'Directory\Purchase Order\quotation2.pdf';
  final bytes = File(path).readAsBytesSync();
  final cells = QuotationPdf.extractCells(bytes);
  final rows = <List<PdfCell>>[];
  var cur = <PdfCell>[];
  var cy = 0.0;
  var cp = 0;
  for (final c in cells) {
    if (cur.isNotEmpty && (c.page != cp || (cy - c.y).abs() > 1.0)) {
      rows.add(cur);
      cur = [];
    }
    cp = c.page;
    cy = c.y;
    cur.add(c);
  }
  if (cur.isNotEmpty) rows.add(cur);
  var i = 0;
  for (final r in rows) {
    r.sort((a, b) => a.x.compareTo(b.x));
    final t = r.map((c) => c.text).join(' ');
    final up = t.toUpperCase();
    final toIx = up.indexOf('TO');
    final marked = toIx >= 0 &&
        (toIx == 0 || up[toIx - 1] == ' ' || up[toIx - 1] == '-');
    print('row#$i page=${r.first.page} y=${r.first.y.toStringAsFixed(1)} '
        'toIx=$toIx${marked ? '  <== TO-CANDIDATE' : ''}');
    if (marked || toIx >= 0) print('   TEXT: "$t"');
    i++;
  }
}
