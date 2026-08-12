import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final data = File('assets/po_mechanical_template.xlsx').readAsBytesSync();
  final zip = ZipDecoder().decodeBytes(data);
  final ss = utf8.decode(zip.files.firstWhere((f) => f.name == 'xl/sharedStrings.xml').content as List<int>);
  
  final sstMatch = RegExp(r'<sst[^>]*>(.*)</sst>', dotAll: true).firstMatch(ss)!;
  final siList = RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(sstMatch.group(1)!).toList();
  for (var i = 0; i < siList.length; i++) {
    final inner = siList[i].group(1)!;
    final txt = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
        .allMatches(inner)
        .map((m) => m.group(1)!)
        .join()
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    if (txt.trim().isNotEmpty) {
      print('[$i] "$txt"');
    }
  }
  
  final sh = utf8.decode(zip.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml').content as List<int>);
  for (final line in sh.split('\n')) {
    if (line.contains('row r="3"') || line.contains('row r="16"') || line.contains('row r="17"')) {
      print('ROW: $line');
    }
  }
}
