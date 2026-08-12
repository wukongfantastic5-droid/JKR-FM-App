import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

/// Prints the shared-string index referenced by every cell in the vendor
/// area (rows 3-20) of any xlsx, so we know exactly which cells hold the
/// vendor name / address / tel / attn.
void main(List<String> args) {
  final path = args.isNotEmpty
      ? args[0]
      : 'assets/po_mechanical_template.xlsx';
  final data = File(path).readAsBytesSync();
  final zip = ZipDecoder().decodeBytes(data);
  final ssf = zip.files.firstWhere((f) => f.name == 'xl/sharedStrings.xml',
      orElse: () => zip.files.firstWhere((f) => f.name.endsWith('sharedStrings.xml')));
  final ss = utf8.decode(ssf.content as List<int>);
  final sstMatch = RegExp(r'<sst[^>]*>(.*)</sst>', dotAll: true).firstMatch(ss)!;
  final siList = RegExp(r'<si>(.*?)</si>', dotAll: true)
      .allMatches(sstMatch.group(1)!)
      .toList();
  final strings = siList
      .map((si) => RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
          .allMatches(si.group(1)!)
          .map((m) => m.group(1)!)
          .join()
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>'))
      .toList();

  final sh = utf8.decode(zip.files
      .firstWhere((f) => f.name.endsWith('worksheets/sheet1.xml')).content as List<int>);
  final cellRe = RegExp(r'<c r="([A-Z]+\d+)"[^>]*?(?: t="([^"]+)")?[^>]*?(?: s="(\d+)")?[^>]*>(?:<v>(\d+)</v>)?');
  for (final m in cellRe.allMatches(sh)) {
    final ref = m.group(1)!;
    final row = int.tryParse(ref.replaceAll(RegExp(r'[A-Z]'), ''));
    if (row == null || row < 3 || row > 20) continue;
    final type = m.group(2);
    final idx = m.group(4);
    String val = '';
    if (type == 's' && idx != null) {
      val = strings[int.parse(idx)];
    } else if (idx != null) {
      val = '(num $idx)';
    }
    if (val.trim().isEmpty) continue;
    print('$ref [$type] -> "$val"');
  }
}
