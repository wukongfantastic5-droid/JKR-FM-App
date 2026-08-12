import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final data = File('assets/po_mechanical_template.xlsx').readAsBytesSync();
  final zip = ZipDecoder().decodeBytes(data);
  final ss = utf8.decode(zip.files.firstWhere((f) => f.name == 'xl/sharedStrings.xml').content as List<int>);
  print('=== sharedStrings.xml ===');
  print(ss);
  print('=== sheet1.xml ===');
  final sh = utf8.decode(zip.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml').content as List<int>);
  for (final line in sh.split('\n')) {
    if (line.contains('mergeCell') || line.contains('row r="1') || line.contains('row r="2') || line.contains('row r="3') || line.contains('row r="4') || line.contains('row r="5') || line.contains('row r="6') || line.contains('row r="19')) {
      print(line.trim());
    }
  }
}
