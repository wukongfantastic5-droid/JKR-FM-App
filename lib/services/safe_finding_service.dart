import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import 'repo_service.dart';

/// A Safety / Safe Finding record raised by a technician.
///
/// Flow mirrors the CM work order lifecycle:
///   open  -> technician presses ATTEND  -> in_progress
///   in_progress -> technician closes with photo(s) + findings -> closed
class SafeFinding {
  String id;
  String date; // Tarikh isu (ISO)
  String floor; // Aras
  String issue; // Apakah isu / what issue
  String status; // open | in_progress | closed
  String techId;
  String techName;
  String attendedAt;
  String closedAt;
  String findings;
  String remark;
  List<String> photos; // base64 photos (camera or gallery)
  String reportPath; // e.g. Safe_Finding/SF-2026-001.docx in the repo

  bool get isClosed => status == 'closed';
  bool get isInProgress => status == 'in_progress';
  bool get isOpen => status == 'open';

  SafeFinding({
    required this.id,
    required this.date,
    required this.floor,
    required this.issue,
    this.status = 'open',
    this.techId = '',
    this.techName = '',
    this.attendedAt = '',
    this.closedAt = '',
    this.findings = '',
    this.remark = '',
    this.photos = const [],
    this.reportPath = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'floor': floor,
    'issue': issue,
    'status': status,
    'techId': techId,
    'techName': techName,
    'attendedAt': attendedAt,
    'closedAt': closedAt,
    'findings': findings,
    'remark': remark,
    'photos': photos,
    'reportPath': reportPath,
  };

  factory SafeFinding.fromJson(Map<String, dynamic> j) => SafeFinding(
    id: j['id'] as String? ?? '',
    date: j['date'] as String? ?? '',
    floor: j['floor'] as String? ?? '',
    issue: j['issue'] as String? ?? '',
    status: j['status'] as String? ?? 'open',
    techId: j['techId'] as String? ?? '',
    techName: j['techName'] as String? ?? '',
    attendedAt: j['attendedAt'] as String? ?? '',
    closedAt: j['closedAt'] as String? ?? '',
    findings: j['findings'] as String? ?? '',
    remark: j['remark'] as String? ?? '',
    photos: ((j['photos'] as List?) ?? []).map((e) => e.toString()).toList(),
    reportPath: j['reportPath'] as String? ?? '',
  );
}

class SafeFindingService {
  static const String file = 'safe_findings.json';
  static final bool _debug = true;
  static List<SafeFinding> _entries = [];
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static int _writeSeq = 0;

  static void _log(String msg) {
    if (_debug) debugPrint('[SafeFindingService] $msg');
  }

  static void _bump() => revision.value++;

  static List<SafeFinding> get entries => List.from(_entries);

  static SafeFinding? byId(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Auto-generates the next free finding id: `SF-<year>-<nnn>`.
  static String nextId({int? year}) {
    final y = (year ?? DateTime.now().year).toString();
    for (var n = 1; n < 10000; n++) {
      final id = 'SF-$y-${n.toString().padLeft(3, '0')}';
      if (byId(id) == null) return id;
    }
    return 'SF-$y-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Silent refresh used by real-time polling (does not bump loading state).
  /// A read that was started before a local write is DISCARDED, otherwise a
  /// slow GitHub read could resurrect a just-deleted / just-edited entry.
  static Future<void> load() async {
    final seq = _writeSeq;
    try {
      final data = await RepoService.readFile(file);
      if (seq != _writeSeq) return;
      if (data is List) {
        _entries = data
            .map((e) => SafeFinding.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _log('load error: $e');
    }
    if (seq != _writeSeq) return;
    _bump();
  }

  static Future<bool> create(SafeFinding f) async {
    _entries.add(f);
    return await _persist();
  }

  static Future<bool> updateEntry(SafeFinding f) => _persist();

  /// Updates [f] in the list; optionally renames its id to [newId]
  /// (removes the old entry so the list keeps a single copy).
  static Future<bool> update(SafeFinding f, {String? newId}) async {
    final oldId = f.id;
    if (newId != null && newId.trim().isNotEmpty && newId.trim() != oldId) {
      final id2 = newId.trim();
      if (byId(id2) != null) return false;
      _entries.removeWhere((e) => e.id == oldId);
      f.id = id2;
      _entries.add(f);
    }
    return await _persist();
  }

  static Future<bool> removeEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    return await _persist();
  }

  static Future<bool> attend(String id, String techId, String techName) async {
    final e = byId(id);
    if (e == null) return false;
    if (e.isClosed) return false;
    e.status = 'in_progress';
    e.techId = techId;
    e.techName = techName;
    e.attendedAt = e.attendedAt.isEmpty ? DateTime.now().toIso8601String() : e.attendedAt;
    return await _persist();
  }

  static Future<bool> close(
    String id, {
    List<String> photos = const [],
    String findings = '',
    String remark = '',
    String reportPath = '',
  }) async {
    final e = byId(id);
    if (e == null) return false;
    e.photos = List.from(photos);
    e.findings = findings;
    e.remark = remark;
    e.status = 'closed';
    e.closedAt = DateTime.now().toIso8601String();
    e.reportPath = reportPath;
    return await _persist();
  }

  static Future<bool> _persist() async {
    _writeSeq++;
    final ok = await RepoService.writeFile(
      file,
      _entries.map((e) => e.toJson()).toList(),
    );
    _bump();
    return ok;
  }
}