import 'dart:io';
import 'package:jkr_fm_guide/services/quotation_pdf.dart';

void main() {
  final args = Platform.environment['QT_FILE'] ??
      r'C:\Users\zaina\OneDrive\Desktop\Kerja\Cakra Mahkota Sdn Bhd\Gerak Kerja\JKR_FM_Guide\Directory\Purchase Order\001-Quotation.pdf';
  final bytes = File(args).readAsBytesSync();
  final cells = QuotationPdf.extractCells(bytes, debug: true);
  print('FILE: $args');
  print('BYTES: ${bytes.length}  CELLS: ${cells.length}');
  if (cells.isEmpty) {
    print('EXTRACTOR GOT NOTHING');
    return;
  }
  final q = QuotationPdf.parse(cells, debug: true);
  print('vendor=${q.vendor}');
  print('toCompany=[${q.toCompany}] dateText=[${q.dateText}] terms=[${q.terms}] attn=[${q.attn}]');
  print('items=${q.items.length} subTotal=${q.subTotal} totalAmount=${q.totalAmount}');
  for (final i in q.items) {
    print('  ${i.no} | ${i.description} | qty=${i.qty} | ${i.unitPrice} | ${i.subtotal}');
  }
  print('--- first cells (compact) ---');
  final ws = cells.where((c) => c.text.trim().isEmpty).toList();
  print('WS CELLS: ${ws.length}  first: ${ws.take(3).map((c) => '${c.x.toStringAsFixed(1)}/${c.y.toStringAsFixed(1)}').join(' vs ')}');
  for (final c in cells.take(400)) {
    print('${c.x.toStringAsFixed(0).padLeft(4)} ${c.y.toStringAsFixed(0).padLeft(4)} ${c.text}');
  }
}