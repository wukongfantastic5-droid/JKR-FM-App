import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import '../data/spare_part_data.dart';
import 'repo_service.dart';

/// Tools store (tools.json in the GitHub repo) — same design as spare parts.
/// Loaded with a shared revision notifier so every change (add / edit /
/// delete) is immediately visible to every open screen in real time.
/// Entries reuse the SparePart model (name, quantity, photo, suppliers).
class ToolService {
  static final bool _debug = true;
  static const String file = 'tools.json';
  static List<SparePart> _entries = [];

  /// Bumped on every load/save so open screens refresh in real time.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _bump() => revision.value++;
  static void _log(String msg) {
    if (_debug) debugPrint('[ToolService] $msg');
  }

  static List<SparePart> get entries => List.from(_entries);

  static SparePart? byId(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  static Future<List<SparePart>> load() async {
    try {
      final data = await RepoService.readFile(file);
      if (data is List) {
        _entries = data
            .map((e) => SparePart.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _log('load error: $e');
    }
    _bump();
    return List.from(_entries);
  }

  static Future<bool> save(SparePart tool) async {
    final idx = _entries.indexWhere((e) => e.id == tool.id);
    tool.updatedAt = DateTime.now().toIso8601String();
    if (idx >= 0) {
      _entries[idx] = tool;
    } else {
      _entries.add(tool);
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