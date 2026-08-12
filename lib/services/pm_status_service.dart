import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import '../data/pm_status_data.dart';
import 'repo_service.dart';

/// PM task status workflow store (pm_status.json in the GitHub repo).
class PmStatusService {
  static final bool _debug = true;
  static const String file = 'pm_status.json';
  static List<PmStatusEntry> _entries = [];

  /// Bumped whenever statuses change (close / attend / remove / update /
  /// reload) so schedule screens can refresh their closed-task filtering.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _bump() => revision.value++;

  /// When true all mutations stay in-memory only — used by demo/preview mode
  /// so attending/closing a previewed PM never touches the real schedule.
  static bool demoMode = false;
  static final Map<String, PmStatusEntry> _demo = {};

  static void _log(String msg) {
    if (_debug) debugPrint('[PmStatus] $msg');
  }

  static List<PmStatusEntry> get entries => List.from(_entries);

  static List<PmStatusEntry> activeEntries() =>
      demoMode ? List.of(_demo.values) : List.from(_entries);

  /// Ids of tasks that are already closed on the given ISO date
  /// (demo-aware: in demo mode only the in-memory preview matters).
  static Set<String> closedIdsOn(String isoDate) {
    final src = demoMode ? _demo.values : _entries;
    return src
        .where((e) => e.date == isoDate && e.isClosed)
        .map((e) => e.id)
        .toSet();
  }

  static List<PmStatusEntry> byDate(String isoDate) =>
      _entries.where((e) => e.date == isoDate).toList();

  static List<PmStatusEntry> byMonth(String month) =>
      _entries.where((e) => e.month == month).toList();

  static Future<List<PmStatusEntry>> load() async {
    try {
      final data = await RepoService.readFile(file);
      if (data is List) {
        _entries = data
            .map((e) => PmStatusEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _log('load error: $e');
    }
    _bump();
    return List.from(_entries);
  }

  static Future<bool> _persist() async {
    if (demoMode) {
      _bump();
      return true;
    }
    return await _persistReal();
  }

  /// Writes the real pm_status.json regardless of demo mode. Used when a
  /// demo-session task is closed so the record appears in the admin PM
  /// Status tab (where it can be edited) exactly like a normal close.
  static Future<bool> _persistReal() async {
    final ok = await RepoService.writeFile(
      file,
      _entries.map((e) => e.toJson()).toList(),
    );
    _bump();
    return ok;
  }

  static String buildId({
    required String date,
    required String sys,
    required String item,
    required String desc,
  }) {
    final raw = '$date|$sys|$item|$desc';
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  }

  /// Returns the live entry for [e]'s id, attaching [e] to the working list
  /// when the server copy doesn't have it yet (first-time attend). Critical:
  /// [load] REPLACES _entries with the server file, so a freshly-created task
  /// entry would otherwise be invisible to attend/close and fail silently.
  static PmStatusEntry _ensure(PmStatusEntry e) {
    for (final x in _entries) {
      if (x.id == e.id) return x;
    }
    _entries.add(e);
    return e;
  }

  static PmStatusEntry entryFor({
    required String date,
    required String sys,
    required String item,
    required String desc,
    String sub = '',
    String freq = '',
    List<String> markers = const [],
  }) {
    final id = buildId(date: date, sys: sys, item: item, desc: desc);
    if (demoMode) {
      final ex = _demo[id];
      if (ex != null) return ex;
      final d = PmStatusEntry(
        id: id,
        date: date,
        month: date.length >= 7 ? date.substring(0, 7) : '',
        sys: sys,
        sub: sub,
        item: item,
        desc: desc,
        freq: freq,
        markers: markers,
      );
      _demo[id] = d;
      return d;
    }
    final e = PmStatusEntry(
      id: id,
      date: date,
      month: date.length >= 7 ? date.substring(0, 7) : '',
      sys: sys,
      sub: sub,
      item: item,
      desc: desc,
      freq: freq,
      markers: markers,
    );
    return _ensure(e);
  }

  static Future<bool> attend(PmStatusEntry e, String techId, String techName) async {
    final cur = demoMode ? _demo[e.id] : _ensure(e);
    if (cur == null) return false;
    cur.status = 'in_progress';
    cur.techId = techId;
    cur.techName = techName;
    cur.attendedAt = DateTime.now().toIso8601String();
    cur.startedAt = cur.startedAt.isEmpty ? cur.attendedAt : cur.startedAt;
    return await _persist();
  }

  static Future<bool> updateEntry(PmStatusEntry e) => _persist();

  static Future<bool> removeEntry(PmStatusEntry e) async {
    if (demoMode) {
      _demo.remove(e.id);
      return true;
    }
    _entries.removeWhere((x) => x.id == e.id);
    return await _persist();
  }

  static Future<bool> close(
    PmStatusEntry e, {
    required String floor,
    required String asset,
    String woNo = '',
    String findings = '',
    String remark = '',
    List<String> photos = const [],
  }) async {
    final cur = demoMode ? _demo[e.id] : _ensure(e);
    if (cur == null) return false;
    cur.floor = floor;
    cur.asset = asset;
    cur.woNo = woNo;
    cur.findings = findings;
    cur.remark = remark;
    cur.photos = List.from(photos);
    cur.status = 'closed';
    cur.closedAt = DateTime.now().toIso8601String();
if (demoMode) {
      // Even in demo, persist the closed record into the real pm_status.json
      // so the admin PM Status tab sees it and can edit it. Replace (or add)
      // the real entry with this closed snapshot.
      _entries.removeWhere((x) => x.id == cur.id);
      _entries.add(PmStatusEntry.fromJson(cur.toJson()));
      return await _persistReal();
    }
    return await _persist();
  }
}