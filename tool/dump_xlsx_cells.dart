import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : r'assets\po_mechanical_template.xlsx';
  final data = File(path).readAsBytesSync();
  final zip = ZipDecoder().decodeBytes(data);
  print('--- files ---');
  for (final f in zip.files) {
    print(f.name);
  }
  List<String> strings = [];
  try {
    final ssf = zip.files.firstWhere((f) => f.name.endsWith('sharedStrings.xml'));
    final ss = utf8.decode(ssf.content as List<int>);
    final sstMatch =
        RegExp(r'<sst[^>]*>(.*)</sst>', dotAll: true).firstMatch(ss)!;
    strings = RegExp(r'<si>(.*?)</si>', dotAll: true)
        .allMatches(sstMatch.group(1)!)
        .map((si) => RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
            .allMatches(si.group(1)!)
            .map((m) => m.group(1)!)
            .join()
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>'))
        .toList();
    print('--- sharedStrings: ${strings.length} ---');
  } catch (e) {
    print('--- no sharedStrings: $e ---');
  }
  final sh = utf8.decode(zip.files
      .firstWhere((f) => f.name.endsWith('worksheets/sheet1.xml')).content
      as List<int>);
  // attribute-order-independent: extract each <c ...> with raw attrs
  final cellRe = RegExp(r'<c\b([^>]*?)(?:/>|>(?:<v>([^<]*)</v>)?(?:<is><t[^>]*>([^<]*)</t></is>)?</c>)',
      dotAll: true);
  for (final m in cellRe.allMatches(sh)) {
    final attrs = m.group(1)!;
    final v = m.group(2);
    final inline = m.group(3);
    final refM = RegExp(r'r="([A-Z]+\d+)"').firstMatch(attrs);
    if (refM == null) continue;
    final ref = refM.group(1)!;
    final row = int.tryParse(ref.replaceAll(RegExp(r'[A-Z]'), ''));
    if (row == null || row < 1 || row > 40) continue;
    final tM = RegExp(r'\bt="([^"]+)"').firstMatch(attrs);
    final type = tM?.group(1);
    String val = '';
    if (type == 's' && v != null && v.isNotEmpty) {
      val = strings[int.parse(v)];
    } else if (type == 'inlineStr' && inline != null) {
      val = '(inline) $inline';
    } else if (v != null) {
      val = v;
    }
    if (val.trim().isEmpty && type == null) continue;
    print('$ref [${type ?? 'num'}] -> "$val"');
  }
}
