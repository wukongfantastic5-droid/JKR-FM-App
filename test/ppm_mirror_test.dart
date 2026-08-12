import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/data/technician_data.dart';
import 'package:jkr_fm_guide/services/tech_service.dart';

const String tmp = r'C:\Users\zaina\AppData\Local\Temp\opencode';

String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  test('mirror schedule equals Excel-validated grids 2026-07..2031-12', () async {
    final raw = File('$tmp\\ppm_new.json').readAsStringSync();
    final list = jsonDecode(raw) as List;
    final items = list.map((e) => PpmItem.fromJson(e as Map<String, dynamic>)).toList();

    final sched = await TechService.generateSchedule(items, DateTime(2026, 7, 1), DateTime(2031, 12, 31));

    final expected = <String, int>{};
    final expectedRows = <String, Set<int>>{};
    for (int y = 2026; y <= 2031; y++) {
      for (int m = 1; m <= 12; m++) {
        if (y == 2026 && m < 7) continue;
        final f = File('$tmp\\ppm_out\\expected\\$y-${m.toString().padLeft(2, '0')}.json');
        final grid = jsonDecode(f.readAsStringSync()) as List;
        final first = DateTime(y, m, 1);
        final wstart = first.subtract(Duration(days: first.weekday - 1));
        for (int i = 0; i < grid.length; i++) {
          final cells = grid[i] as Map<String, dynamic>;
          final sys = list[i]['system'] as String;
          final it = list[i]['item'] as String;
          final task = list[i]['task'] as String;
          final freq = (list[i]['freq'] as List).join('/');
          cells.forEach((k, v) {
            if (v != null && v.toString().isNotEmpty) {
              final d = wstart.add(Duration(days: int.parse(k)));
              final key = '${fmtDate(d)}|$sys|$it|$task|$freq';
              expectedRows.putIfAbsent(key, () => <int>{}).add(i);
            }
          });
        }
      }
    }
    for (final e in expectedRows.entries) {
      expected[e.key] = e.value.length;
    }

    final actual = <String, int>{};
    for (final s in sched) {
      final key = '${fmtDate(s.date)}|${s.system}|${s.item}|${s.task}|${s.freq}';
      actual[key] = (actual[key] ?? 0) + 1;
    }

    final missingKeys = expected.keys.where((k) => (actual[k] ?? 0) < expected[k]!).toList()..sort();
    final extraKeys = actual.keys.where((k) => (expected[k] ?? 0) < actual[k]!).toList()..sort();

    if (missingKeys.isNotEmpty || extraKeys.isNotEmpty) {
      fail('MISMATCH\n  expected entries: ${expected.length}, actual: ${actual.length}\n'
          '  MISSING (${missingKeys.length}):\n    ${missingKeys.take(40).join('\n    ')}\n'
          '  EXTRA (${extraKeys.length}):\n    ${extraKeys.take(40).join('\n    ')}');
    }
    expect(missingKeys, isEmpty);
    expect(extraKeys, isEmpty);
    expect(sched.length, expected.values.fold(0, (a, b) => a + b));
  });
}
