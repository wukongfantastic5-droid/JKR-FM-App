import 'dart:io';
import 'package:jkr_fm_guide/services/quotation_pdf.dart';

void main(List<String> args) {
  final path =
      args.isNotEmpty ? args[0] : r'Directory\Purchase Order\quotation2.pdf';
  final bytes = File(path).readAsBytesSync();
  final cells = QuotationPdf.extractCells(bytes);
  final targetY = args.length > 1 ? double.parse(args[1]) : 790.0;
  for (final c in cells) {
    if ((c.y - targetY).abs() < 1.5) {
      print('x=${c.x.toStringAsFixed(1)}  "${c.text}"  [${c.text.codeUnits}]');
    }
  }
}
