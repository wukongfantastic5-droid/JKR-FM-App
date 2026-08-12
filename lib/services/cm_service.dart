import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import 'repo_service.dart';

class CmWorkOrder {
  String id;
  String date; // WO tarikh ISO
  String floor; // Aras
  String defect; // Jenis kerosakan
  String status; // open | in_progress | closed
  String techId;
  String techName;
  String attendedAt;
  String closedAt;
  String findings;
  String remark;
  List<String> photosBefore;
  List<String> photosDuring;
  List<String> photosAfter;
  String reportPath; // e.g. CM_Report/CM-0001.docx in the repo

  bool get isClosed => status == 'closed';
  bool get isInProgress => status == 'in_progress';
  bool get isOpen => status == 'open';

  CmWorkOrder({
    required this.id,
    required this.date,
    required this.floor,
    required this.defect,
    this.status = 'open',
    this.techId = '',
    this.techName = '',
    this.attendedAt = '',
    this.closedAt = '',
    this.findings = '',
    this.remark = '',
    this.photosBefore = const [],
    this.photosDuring = const [],
    this.photosAfter = const [],
    this.reportPath = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'floor': floor,
    'defect': defect,
    'status': status,
    'techId': techId,
    'techName': techName,
    'attendedAt': attendedAt,
    'closedAt': closedAt,
    'findings': findings,
    'remark': remark,
    'photosBefore': photosBefore,
    'photosDuring': photosDuring,
    'photosAfter': photosAfter,
    'reportPath': reportPath,
  };

  factory CmWorkOrder.fromJson(Map<String, dynamic> j) => CmWorkOrder(
    id: j['id'] as String? ?? '',
    date: j['date'] as String? ?? '',
    floor: j['floor'] as String? ?? '',
    defect: j['defect'] as String? ?? '',
    status: j['status'] as String? ?? 'open',
    techId: j['techId'] as String? ?? '',
    techName: j['techName'] as String? ?? '',
    attendedAt: j['attendedAt'] as String? ?? '',
    closedAt: j['closedAt'] as String? ?? '',
    findings: j['findings'] as String? ?? '',
    remark: j['remark'] as String? ?? '',
    photosBefore: ((j['photosBefore'] as List?) ?? []).map((e) => e.toString()).toList(),
    photosDuring: ((j['photosDuring'] as List?) ?? []).map((e) => e.toString()).toList(),
    photosAfter: ((j['photosAfter'] as List?) ?? []).map((e) => e.toString()).toList(),
    reportPath: j['reportPath'] as String? ?? '',
  );
}

class CmService {
  static const String file = 'cm_work.json';
  static final bool _debug = true;
  static List<CmWorkOrder> _entries = [];
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static bool _loaded = false;
  static int _writeSeq = 0;

  static void _log(String msg) {
    if (_debug) debugPrint('[CmService] $msg');
  }

  static void _bump() => revision.value++;

  static List<CmWorkOrder> get entries => List.from(_entries);

  static CmWorkOrder? byId(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
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
            .map((e) => CmWorkOrder.fromJson(e as Map<String, dynamic>))
            .toList();
        _loaded = true;
      }
    } catch (e) {
      _log('load error: $e');
    }
    if (seq != _writeSeq) return;
    _bump();
  }

  static Future<bool> create(CmWorkOrder wo) async {
    _entries.add(wo);
    return await _persist();
  }

  static Future<bool> updateEntry(CmWorkOrder wo) => _persist();

  /// Updates [wo] in the list; optionally renames its id to [newId]
  /// (removes the old entry so the list keeps a single copy).
  static Future<bool> update(CmWorkOrder wo, {String? newId}) async {
    final oldId = wo.id;
    if (newId != null && newId.trim().isNotEmpty && newId.trim() != oldId) {
      final id2 = newId.trim();
      if (byId(id2) != null) return false;
      _entries.removeWhere((e) => e.id == oldId);
      wo.id = id2;
      _entries.add(wo);
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
    List<String> before = const [],
    List<String> during = const [],
    List<String> after = const [],
    String findings = '',
    String remark = '',
    String reportPath = '',
  }) async {
    final e = byId(id);
    if (e == null) return false;
    e.photosBefore = List.from(before);
    e.photosDuring = List.from(during);
    e.photosAfter = List.from(after);
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
