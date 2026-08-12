import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/technician_data.dart';
import '../data/ppm_schedule_data.dart';
import '../data/ppm_scope_data.dart';
import 'repo_service.dart';

class TechService {
  static final bool _debug = true;

  // Federal (JKR/KL) public holidays 2026-2031 - matches the TETAPAN sheet of
  // the generated PPM workbooks. Islamic dates are estimates. Key: yyyymmdd.
  static const Map<int, String> ppmHolidays = {
20260825: 'Maulidur Rasul (Hari Keputeraan Nabi Muhammad S.A.W.)',
    20260831: 'Hari Kebangsaan (Merdeka Day)',
    20260916: 'Hari Malaysia',
    20261109: 'Hari Deepavali (cuti ganti)',
    20261225: 'Hari Krismas',
    20270101: 'Tahun Baru',
    20270201: 'Hari Wilayah Persekutuan',
    20270208: 'Tahun Baru Cina (cuti ganti)',
    20270224: 'Nuzul Al-Quran',
    20270310: 'Hari Raya Aidilfitri (anggaran)',
    20270311: 'Hari Raya Aidilfitri Hari Ke-2 (anggaran)',
    20270517: 'Hari Raya Haji (anggaran)',
    20270520: 'Hari Wesak',
    20270607: 'Hari Keputeraan YDP Agong',
    20270816: 'Maulidur Rasul (cuti ganti)',
    20270831: 'Hari Kebangsaan',
    20270916: 'Hari Malaysia',
    20271028: 'Hari Deepavali',
    20280126: 'Tahun Baru Cina',
    20280127: 'Tahun Baru Cina Hari Ke-2',
    20280201: 'Hari Wilayah Persekutuan',
    20280214: 'Nuzul Al-Quran (cuti ganti)',
    20280227: 'Hari Raya Aidilfitri (anggaran)',
    20280228: 'Hari Raya Aidilfitri Hari Ke-2 (anggaran)',
    20280501: 'Hari Pekerja',
    20280505: 'Hari Raya Haji (anggaran)',
    20280509: 'Hari Wesak',
    20280525: 'Awal Muharram (anggaran)',
    20280605: 'Hari Keputeraan YDP Agong',
    20280803: 'Maulidur Rasul (anggaran)',
    20280831: 'Hari Kebangsaan',
    20281017: 'Hari Deepavali',
    20281225: 'Hari Krismas',
    20290101: 'Tahun Baru',
    20290201: 'Hari Wilayah Persekutuan',
    20290213: 'Tahun Baru Cina',
    20290214: 'Tahun Baru Cina Hari Ke-2',
    20290215: 'Hari Raya Aidilfitri (anggaran)',
    20290216: 'Hari Raya Aidilfitri Hari Ke-2 (anggaran)',
    20290424: 'Hari Raya Haji (anggaran)',
    20290501: 'Hari Pekerja',
    20290515: 'Awal Muharram (anggaran)',
    20290528: 'Hari Wesak (cuti ganti)',
    20290604: 'Hari Keputeraan YDP Agong',
    20290724: 'Maulidur Rasul (anggaran)',
    20290831: 'Hari Kebangsaan',
    20290917: 'Hari Malaysia (cuti ganti)',
    20291105: 'Hari Deepavali (cuti ganti)',
    20291225: 'Hari Krismas',
    20300101: 'Tahun Baru',
    20300122: 'Nuzul Al-Quran (anggaran)',
    20300201: 'Hari Wilayah Persekutuan',
    20300204: 'Tahun Baru Cina (cuti ganti)',
    20300205: 'Hari Raya Aidilfitri (anggaran)',
    20300206: 'Hari Raya Aidilfitri Hari Ke-2 (anggaran)',
    20300415: 'Hari Raya Haji (cuti ganti)',
    20300501: 'Hari Pekerja',
    20300504: 'Awal Muharram (anggaran)',
    20300516: 'Hari Wesak',
    20300603: 'Hari Keputeraan YDP Agong',
    20300713: 'Maulidur Rasul (anggaran)',
    20300831: 'Hari Kebangsaan',
    20300916: 'Hari Malaysia',
    20301026: 'Hari Deepavali',
    20301225: 'Hari Krismas',
    20310101: 'Tahun Baru',
    20310111: 'Nuzul Al-Quran (anggaran)',
    20310123: 'Tahun Baru Cina',
    20310124: 'Tahun Baru Cina Hari Ke-2',
    20310125: 'Hari Raya Aidilfitri (anggaran)',
    20310127: 'Hari Raya Aidilfitri Hari Ke-2 (cuti ganti)',
    20310201: 'Hari Wilayah Persekutuan',
    20310403: 'Hari Raya Haji (anggaran)',
    20310404: 'Hari Raya Haji Hari Ke-2 (anggaran)',
    20310423: 'Awal Muharram (anggaran)',
    20310501: 'Hari Pekerja',
    20310505: 'Hari Wesak',
    20310602: 'Hari Keputeraan YDP Agong',
    20310702: 'Maulidur Rasul (anggaran)',
    20310901: 'Hari Kebangsaan (cuti ganti)',
    20310916: 'Hari Malaysia',
    20311114: 'Hari Deepavali',
    20311225: 'Hari Krismas',
};

  static const Map<String, int> _ppmCycle = {'3M': 3, '6M': 6, 'Y': 12, '5Y': 60};

  static int _dkey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static DateTime _shiftHol(DateTime d) {
    var x = DateTime(d.year, d.month, d.day);
    while (x.weekday >= 6 || ppmHolidays.containsKey(_dkey(x))) {
      x = DateTime(x.year, x.month, x.day + 1);
    }
    return x;
  }

  static DateTime _lastOfMonth(int y, int m) => DateTime(y, m + 1, 0);

  static DateTime _windowEnd(int y, int m) {
    final last = _lastOfMonth(y, m);
    return last.add(Duration(days: (7 - last.weekday) % 7));
  }

  static DateTime _initLast(int anchor, int cycle) {
    final dm0 = (6 - cycle) % 12;
    return DateTime(2026 + ((6 - cycle) - dm0) ~/ 12, dm0 + 1, anchor);
  }

  static List<Technician> _techs = [];
  static List<ScheduleItem> _scheduleCache = [];
  static int _cacheDay = -1;

  static void _log(String msg) {
    if (_debug) debugPrint('[TechService] $msg');
  }

  static List<Technician> get technicians => List.from(_techs);

  static Future<List<PpmItem>> loadPpmData() async {
    try {
      final data = await RepoService.readFile('ppm.json');
      if (data == null) return [];
      return (data as List).map((e) => PpmItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _log('loadPpmData error: $e');
      return [];
    }
  }

  // Workbook-faithful PPM schedule (ppm_schedule.json): months of exact
  // day-marker cells from the JADUAL sheet, source of truth for the UI.
  static Future<List<PpmScheduleMonth>> loadPpmSchedule() async {
    try {
      final data = await RepoService.readFile('ppm_schedule.json');
      if (data == null) return [];
      return (data as List)
          .map((e) => PpmScheduleMonth.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('loadPpmSchedule error: $e');
      return [];
    }
  }

  // Contract scope of work per system (ppm_scope.json) — the checklists the
  // contractor covers for each PPM task, grouped by maintenance frequency.
  static Future<List<PpmScope>> loadPpmScope() async {
    try {
      final data = await RepoService.readFile('ppm_scope.json');
      if (data == null) return [];
      return (data as List)
          .map((e) => PpmScope.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('loadPpmScope error: $e');
      return [];
    }
  }

  static void initDefaultTechs() {
    _techs = [
      Technician(id: 'A', name: 'Technician A'),
      Technician(id: 'B', name: 'Technician B'),
      Technician(id: 'C', name: 'Technician C'),
      Technician(id: 'D', name: 'Technician D'),
      Technician(id: 'E', name: 'Technician E'),
    ];
  }

  static Future<void> loadTechStatus() async {
    // Prefer the GitHub account database (technicians.json)
    try {
      final data = await RepoService.readFile('technicians.json');
      if (data is List && data.isNotEmpty) {
        _techs = data.map((e) => Technician.fromJson(e as Map<String, dynamic>)).toList();
        _log('loadTechStatus: ${_techs.length} accounts from GitHub');
        return;
      }
    } catch (e) {
      _log('loadTechStatus GitHub error: $e');
    }
    // Fall back to the local cache
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tech_status');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).map((e) => Technician.fromJson(e as Map<String, dynamic>)).toList();
        if (list.isNotEmpty) {
          _techs = list;
          return;
        }
      } catch (_) {}
    }
    initDefaultTechs();
  }

  static Future<void> saveTechStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tech_status', jsonEncode(_techs.map((e) => e.toJson()).toList()));
    try {
      await RepoService.saveTechnicians(_techs.map((e) => e.toJson()).toList());
    } catch (e) {
      _log('saveTechStatus GitHub error: $e');
    }
  }

  static Future<void> setTechOnline(String id, bool online) async {
    final idx = _techs.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _techs[idx].isOnline = online;
      _techs[idx].lastSeen = DateTime.now().toIso8601String();
      await saveTechStatus();
    }
  }

  static Future<Technician?> saveTechAccount(Technician tech) async {
    final idx = _techs.indexWhere((t) => t.id == tech.id);
    if (idx >= 0) {
      _techs[idx] = tech;
    } else {
      _techs.add(tech);
    }
    await saveTechStatus();
    return tech;
  }

  static Future<Technician?> techLogin(String email, String password) async {
    await loadTechStatus();
    for (final t in _techs) {
      if (t.email.isNotEmpty &&
          t.email.toLowerCase() == email.toLowerCase() &&
          t.password == password) {
        return t;
      }
    }
    return null;
  }

  static String photoUrl(Technician t) {
    if (t.photoPath.isEmpty) return '';
    return 'https://raw.githubusercontent.com/${RepoService.currentOwner}/'
        '${RepoService.currentRepo}/main/${t.photoPath}';
  }

  static Future<List<ScheduleItem>> generateSchedule(List<PpmItem> ppmItems, DateTime start, DateTime end) async {
    final today = DateTime.now().day;
    if (_cacheDay == today && _scheduleCache.isNotEmpty) return _scheduleCache;

    if (_techs.isEmpty) initDefaultTechs();
    final schedule = <ScheduleItem>[];
    final techIds = _techs.map((t) => t.id).toList();
    int techIndex = 0;

    final first = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, 1);

    for (final item in ppmItems) {
      if (item.freq.isEmpty) continue;
      final dates = <DateTime>{};
      final lastDone = <String, DateTime>{};
      for (final e in item.anchors.entries) {
        final cycle = _ppmCycle[e.key];
        if (cycle != null) lastDone[e.key] = _initLast(e.value, cycle);
      }
      final pending = <String, DateTime>{};

      var y = first.year;
      var m = first.month;
      while (y < last.year || (y == last.year && m <= last.month)) {
        final dim = _lastOfMonth(y, m).day;
        final wend = _windowEnd(y, m);

        if (item.w != null) {
          final w0 = item.w! - 1;
          final m1 = DateTime(y, m, 1);
          final m1w = m1.weekday - 1;
          final bases = <DateTime>{};
          if (m1w >= w0) bases.add(m1);
          var b = m1.add(Duration(days: (w0 - m1w) % 7));
          while (b.year == y && b.month == m) {
            bases.add(b);
            b = b.add(const Duration(days: 7));
          }
          for (final base in bases) {
            final d = _shiftHol(base);
            if (!d.isAfter(wend)) dates.add(d);
          }
        }

        DateTime? mEff;
        if (item.m != null && item.m! <= dim) {
          mEff = _shiftHol(DateTime(y, m, item.m!));
        }
        var eff = mEff;
        if (eff == null && pending.containsKey('M')) {
          eff = _shiftHol(pending['M']!);
        }
        if (eff != null) {
          if (eff.isAfter(wend)) {
            pending['M'] = eff;
          } else {
            dates.add(eff);
            pending.remove('M');
          }
        }

        for (final e in item.anchors.entries) {
          final code = e.key;
          final anchor = e.value;
          final cycle = _ppmCycle[code];
          if (cycle == null) continue;
          final lastD = lastDone[code];
          DateTime? own;
          if (anchor <= dim && lastD != null) {
            final db = (y * 12 + m) - (lastD.year * 12 + lastD.month);
            if (db > 0 && db % cycle == 0) own = _shiftHol(DateTime(y, m, anchor));
          }
          var effC = own;
          if (effC == null && pending.containsKey(code)) {
            effC = _shiftHol(pending[code]!);
          }
          if (effC != null) {
            if (effC.isAfter(wend)) {
              pending[code] = effC;
            } else {
              dates.add(effC);
              pending.remove(code);
              lastDone[code] = effC;
            }
          }
        }

        if (item.dm == 1) {
          for (var day = 1; day <= dim; day++) {
            final d = DateTime(y, m, day);
            if (d.weekday <= 5 && !ppmHolidays.containsKey(_dkey(d))) dates.add(d);
          }
        } else if (item.dm == 2 && mEff != null && !mEff.isAfter(wend)) {
          dates.add(mEff);
        }

        if (m == 12) {
          y++;
          m = 1;
        } else {
          m++;
        }
      }

      for (final d in dates) {
        final techId = techIds[techIndex % techIds.length];
        techIndex++;
        schedule.add(ScheduleItem(
          date: d,
          techId: techId,
          system: item.system,
          section: item.section,
          item: item.item,
          task: item.task,
          freq: item.freq.join('/'),
        ));
      }
    }

    schedule.sort((a, b) => a.date.compareTo(b.date));
    _scheduleCache = schedule;
    _cacheDay = today;
    _log('Generated ${schedule.length} schedule items');
    return schedule;
  }

  static List<ScheduleItem> getTodaysSchedule(String techId) {
    final today = DateTime.now();
    return _scheduleCache.where((s) =>
      s.techId == techId &&
      s.date.year == today.year &&
      s.date.month == today.month &&
      s.date.day == today.day
    ).toList();
  }

  static List<ScheduleItem> getUpcomingSchedule(String techId, {int days = 30}) {
    final now = DateTime.now();
    final end = now.add(Duration(days: days));
    return _scheduleCache.where((s) =>
      s.techId == techId &&
      !s.date.isBefore(DateTime(now.year, now.month, now.day)) &&
      !s.date.isAfter(DateTime(end.year, end.month, end.day))
    ).toList();
  }

  static List<ScheduleItem> getScheduleForTech(String techId) {
    return _scheduleCache.where((s) => s.techId == techId).toList();
  }

  static int getPendingCount(String techId) {
    return _scheduleCache.where((s) =>
      s.techId == techId && s.status == 'pending'
    ).length;
  }
}
