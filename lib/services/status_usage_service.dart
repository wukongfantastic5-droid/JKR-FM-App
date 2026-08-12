import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;

import '../data/status_usage_data.dart';
import 'repo_service.dart';

/// Status usage store (status_usage.json in the GitHub repo): records of
/// who used which spare part / tool, and how many. Mirrors the
/// SparePartService / ToolService design.
class StatusUsageService {
  static final bool _debug = true;
  static const String file = 'status_usage.json';
  static List<UsageRecord> _entries = [];

  /// Bumped on every load/save so open screens refresh in real time.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _bump() => revision.value++;

  static void _log(String msg) {
    if (_debug) debugPrint('[StatusUsage] $msg');
  }

  static List<UsageRecord> get entries => List.from(_entries);

  static List<UsageRecord> ofType(String type) =>
      _entries.where((e) => e.type == type).toList();

  static Future<List<UsageRecord>> load() async {
    try {
      final data = await RepoService.readFile(file);
      if (data is List) {
        _entries = data
            .map((e) => UsageRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _log('load error: $e');
    }
    _bump();
    return List.from(_entries);
  }

  static Future<bool> save(UsageRecord r) async {
    final idx = _entries.indexWhere((e) => e.id == r.id);
    if (idx >= 0) {
      _entries[idx] = r;
    } else {
      _entries.add(r);
    }
    return await _persist();
  }

  static Future<bool> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    return await _persist();
  }

  static Future<bool> _persist() async {
    final ok = await RepoService.writeFile(
      file,
      _entries.map((e) => e.toJson()).toList(),
    );
    _bump();
    return ok;
  }
}
