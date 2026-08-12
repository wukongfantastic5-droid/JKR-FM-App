import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import '../data/spare_part_data.dart';
import 'repo_service.dart';

/// Spare parts store (spare_parts.json in the GitHub repo).
/// Loaded by both the technician dashboard tab and the admin screen so
/// every change (add / edit / delete) is immediately visible to everyone.
class SparePartService {
  static final bool _debug = true;
  static const String file = 'spare_parts.json';
  static List<SparePart> _entries = [];

  /// Bumped on every load/save so open screens refresh in real time.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _bump() => revision.value++;
  static void _log(String msg) {
    if (_debug) debugPrint('[SparePart] $msg');
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

  static Future<bool> save(SparePart part) async {
    final idx = _entries.indexWhere((e) => e.id == part.id);
    part.updatedAt = DateTime.now().toIso8601String();
    if (idx >= 0) {
      _entries[idx] = part;
    } else {
      _entries.add(part);
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