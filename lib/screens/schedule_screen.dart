import 'package:flutter/material.dart';
import 'dart:convert';
import '../localization.dart';
import '../providers/theme_provider.dart';
import '../services/tech_service.dart';
import '../services/repo_service.dart';
import '../services/pm_status_service.dart';
import '../widgets/http_error_banner.dart';
import '../services/report_saver.dart';
import '../data/ppm_schedule_data.dart';
import '../data/ppm_scope_data.dart';
import '../data/pm_status_data.dart';
import 'pm_status_edit_screen.dart';
import '../services/doc_deliver.dart';
import '../services/excel_service.dart';

class ScheduleScreen extends StatefulWidget {
  /// When [embedded] is true the screen renders without its own Scaffold /
  /// AppBar so it can live inside another tab (technician dashboard).
  const ScheduleScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<PpmScheduleMonth> _months = [];
  List<PpmScope> _scopes = [];
  PpmScheduleMonth? _month;
  bool _loading = true;
  int _tab = 1; // 0 = jadual matrix, 1 = kalendar (default), 2 = pm status (admin)
  final Map<String, bool> _systemOpen = {};
  List<PmStatusEntry> _pmEntries = [];
  bool _pmLoading = false;
  bool _genBusy = false;
  String _genLog = '';
  bool _dlBusy = false;
  bool _xlsBusy = false;

  static const Map<String, Color> _markerColors = {
    'D': Color(0xFF1D6FB8),
    'W': Color(0xFF1B8A5A),
    'M': Color(0xFFE07B39),
    '3M': Color(0xFF8E44AD),
    '6M': Color(0xFFC0392B),
    'Y': Color(0xFF4A4A4A),
    '2Y': Color(0xFF00838F),
    '5Y': Color(0xFF6D4C41),
  };
  static const List<String> _markerOrder = ['D', 'W', 'M', '3M', '6M', 'Y'];
  static const List<String> _scopeFreqs = ['D', 'W', 'M', '3M', '6M', 'Y', '2Y', '5Y'];

  static const Map<String, String> _freqNames = {
    'D': 'Daily',
    'W': 'Weekly',
    'M': 'Monthly',
    '3M': '3 Monthly',
    '6M': '6 Monthly',
    'Y': 'Yearly',
    '2Y': '2 Yearly',
    '5Y': '5 Yearly',
  };

  @override
  void initState() {
    super.initState();
    PmStatusService.revision.addListener(_onPmStatusChanged);
    _load();
  }

  @override
  void dispose() {
    PmStatusService.revision.removeListener(_onPmStatusChanged);
    super.dispose();
  }

  /// Refresh the visible month when PM statuses change (task closed, etc.)
  /// so closed tasks disappear from the calendar and matrix.
  void _onPmStatusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      TechService.loadPpmSchedule(),
      TechService.loadPpmScope(),
      PmStatusService.load(),
    ]);
    final months = results[0] as List<PpmScheduleMonth>;
    final scopes = results[1] as List<PpmScope>;
    if (mounted) {
      setState(() {
        _months = months;
        _scopes = scopes;
        _month = months.isNotEmpty ? months.first : null;
        _loading = false;
      });
    }
  }

  void _goTo(int dir) {
    final idx = _months.indexWhere((m) => m.month == _month!.month);
    final next = idx + dir;
    if (next >= 0 && next < _months.length) {
      setState(() => _month = _months[next]);
    }
  }

  DateTime? _dt(int day) {
    final m = _month!;
    if (m.month.length < 7) return null;
    final y = int.tryParse(m.month.substring(0, 4));
    final mo = int.tryParse(m.month.substring(5, 7));
    if (y == null || mo == null) return null;
    return DateTime(y, mo, day);
  }

  String _iso(int day) {
    final d = _dt(day);
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

    bool get _hasPrev => _month != null && _months.isNotEmpty && _months.first.month != _month!.month;
  bool get _hasNext => _month != null && _months.isNotEmpty && _months.last.month != _month!.month;

  List<String> _sync(List<String> markers) {
    final list = [...markers];
    list.sort((a, b) {
      final ia = _markerOrder.indexOf(a);
      final ib = _markerOrder.indexOf(b);
      if (ia == -1 && ib == -1) return a.compareTo(b);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return list;
  }

  Map<String, List<ScheduleTask>> _tasksByDay() {
    final map = <String, List<ScheduleTask>>{};
    for (final row in _month!.rows) {
      row.cells.forEach((iso, markers) {
        if (_isTaskClosed(iso, row)) return;
        map.putIfAbsent(iso, () => []).add(ScheduleTask(
          sys: row.sys,
          sub: row.sub,
          item: row.item,
          desc: row.desc,
          freq: row.freq,
          markers: _sync(markers.toList()),
        ));
      });
    }
    return map;
  }

  /// True when the scheduled task for [iso] has already been closed
  /// (demo-aware: uses the statuses that are active in this session).
  bool _isTaskClosed(String iso, PpmScheduleRow row) {
    final id = PmStatusService.buildId(
        date: iso, sys: row.sys, item: row.item, desc: row.desc);
    return PmStatusService.closedIdsOn(iso).contains(id);
  }

  bool _sysOpen(String s) => _systemOpen[s] ?? true;

  void _toggleSystem(String s) {
    setState(() => _systemOpen[s] = !_sysOpen(s));
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    if (widget.embedded) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : _month == null
              ? _buildEmpty(eng)
              : Column(
                  children: [
                    const HttpErrorBanner(),
                    _buildMonthNav(eng),
                    _buildLegend(eng),
                    _buildTabs(eng),
                    const Divider(height: 1),
                    Expanded(
                      child: _tab == 0
                          ? _buildJadual(eng)
                          : _tab == 2
                              ? _buildPmStatus(eng)
                              : _buildKalendar(eng),
                    ),
                  ],
                );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'PPM Schedule' : 'Jadual PPM'),
        actions: [
          IconButton(
            icon: _xlsBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.table_chart_rounded),
            tooltip: eng ? 'Export to Excel' : 'Eksport ke Excel',
            onPressed: _xlsBusy ? null : _exportExcel,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _month == null
              ? _buildEmpty(eng)
              : Column(
                  children: [
                    const HttpErrorBanner(),
                    _buildMonthNav(eng),
                    _buildLegend(eng),
                    _buildTabs(eng),
                    const Divider(height: 1),
                    Expanded(
                      child: _tab == 0
                          ? _buildJadual(eng)
                          : _tab == 2
                              ? _buildPmStatus(eng)
                              : _buildKalendar(eng),
                    ),
                  ],
                ),
    );
  }

  Future<void> _exportExcel() async {
    if (_xlsBusy || _months.isEmpty) return;
    setState(() => _xlsBusy = true);
    final eng = LanguageProvider.isEnglish(context);
    try {
      final now = DateTime.now();
      final fileDate = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final sheets = <ExcelSheet>[
        for (final m in _months)
          ExcelSheet(
            name: m.title,
            headers: [
              'Sistem', 'Sub-Sistem', 'Item', 'Deskripsi', 'Kekerapan',
              for (final iso in m.days) 'T${iso.substring(8, 10)}',
            ],
            rows: [
              for (final r in m.rows)
                [
                  r.sys, r.sub, r.item, r.desc, r.freq,
                  for (final iso in m.days)
                    ((r.cells[iso] ?? {}).toList()..sort()).join(', '),
                ],
            ],
          ),
      ];
      final bytes = await ExcelService.build(sheets);
      final fileName = 'PM_Schedule_$fileDate.xlsx';
      final local = await DocDeliver.saveLocal('PM Schedule', fileName, bytes);
      final ok = await RepoService.writeRawFile(
          'Reports/Schedule/$fileName', base64Encode(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (local.isNotEmpty
                ? (eng ? 'Saved: $local' : 'Disimpan: $local')
                : (eng
                    ? 'Saved in database (Reports/Schedule)'
                    : 'Disimpan dalam database (Reports/Schedule)'))
            : (eng ? 'Export ok but save failed' : 'Eksport berjaya tetapi simpan gagal')),
      ));
      if (ok) {
        await DocDeliver.offerOpen(
          context,
          repoPath: 'Reports/Schedule/$fileName',
          eng: eng,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'Export failed: $e' : 'Eksport gagal: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    } finally {
      if (mounted) setState(() => _xlsBusy = false);
    }
  }

  Widget _buildEmpty(bool eng) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(eng ? 'Schedule data not loaded' : 'Data jadual belum dimuat',
              style: TextStyle(color: Colors.grey.shade500)),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(eng ? 'Retry' : 'Cuba semula'),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNav(bool eng) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _hasPrev ? () => _goTo(-1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(_month!.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: _hasNext ? () => _goTo(1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(bool eng) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _legendItem('D', eng ? 'Daily' : 'Harian'),
          _legendItem('W', eng ? 'Weekly' : 'Mingguan'),
          _legendItem('M', eng ? 'Monthly' : 'Bulanan'),
          _legendItem('3M', eng ? '3 Monthly' : '3 Bulanan'),
          _legendItem('6M', eng ? '6 Monthly' : '6 Bulanan'),
          _legendItem('Y', eng ? 'Yearly' : 'Tahunan'),
        ],
      ),
    );
  }

  Widget _legendItem(String code, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: _markerColors[code],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 4),
          Text(code,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildTabs(bool eng) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _tabBtn(1, Icons.calendar_month_rounded, eng ? 'Calendar' : 'Kalendar'),
            _tabBtn(0, Icons.table_chart_rounded, eng ? 'Jadual' : 'Jadual'),
            if (!widget.embedded) _tabBtn(2, Icons.task_alt_rounded, eng ? 'PM Status' : 'Status PM'),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(int idx, IconData icon, String label) {
    final active = _tab == idx;
    final isDark = ThemeProvider.isDark(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tab = idx);
          if (idx == 2) _loadPmStatus();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF2A333D) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? const Color(0xFF0D7377) : Colors.grey.shade500),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? const Color(0xFF0D7377)
                          : Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PM STATUS — admin view of open / in-progress / closed PM tasks
  // ---------------------------------------------------------------------------
  Future<void> _loadPmStatus() async {
    setState(() => _pmLoading = true);
    await PmStatusService.load();
    if (mounted) setState(() => _pmLoading = false);
  }

  Widget _buildPmStatus(bool eng) {
    final all = PmStatusService.entries;
    final open = all.where((e) => e.status == 'open').toList();
    final inProg = all.where((e) => e.status == 'in_progress').toList();
    final closed = all.where((e) => e.status == 'closed').toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _genBusy ? null : _generatePmStatus,
                      icon: _genBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(eng ? 'Generate PM Report' : 'Hasilkan Laporan PM'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _dlBusy ? null : _downloadPmReports,
                      icon: _dlBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.folder_zip_outlined, size: 18),
                      label: Text(eng ? 'Download PM Report' : 'Muat Turun Laporan PM'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        if (_genLog.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(_genLog,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
        Expanded(
          child: _pmLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  children: [
                    _pmSection(eng, Icons.fiber_new_rounded,
                        eng ? 'Open' : 'Terbuka', open, Color(0xFFE07B39)),
                    _pmSection(eng, Icons.hourglass_top_rounded,
                        eng ? 'In Progress' : 'Sedang Dijalankan', inProg, Color(0xFF1D6FB8)),
                    _pmSection(eng, Icons.check_circle_rounded,
                        eng ? 'Closed' : 'Selesai', closed, Color(0xFF1B8A5A)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _pmSection(bool eng, IconData icon, String title, List<PmStatusEntry> list, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Text('$title (${list.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 6),
            child: Text(eng ? 'No tasks' : 'Tiada tugasan',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          )
        else
          ...list.map((e) => _pmCard(e, eng, c)),
      ],
    );
  }

  Widget _pmCard(PmStatusEntry e, bool eng, Color c) {
    final isDark = ThemeProvider.isDark(context);
    return InkWell(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => PmStatusEditScreen(entry: e)),
        );
        if (changed == true) await _loadPmStatus();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2227) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
                child: Text(e.sysCode,
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  e.item.isEmpty ? e.desc : e.item,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(e.date + (e.floor.isNotEmpty ? ' · Aras ${e.floor}' : ''),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          if (e.techName.isNotEmpty)
            Text('${eng ? 'Tech' : 'Teknisi'}: ${e.techName}'
                '${e.asset.isNotEmpty ? ' · ${e.asset}' : ''}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          if (e.findings.isNotEmpty)
            Text(e.findings, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (e.photos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.photo_library_rounded, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${e.photos.length}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: e.photos
                          .take(5)
                          .map((b64) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.memory(
                                    base64Decode(b64),
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                        width: 28,
                                        height: 28,
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                            Icons.broken_image_rounded,
                                            size: 14)),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  Future<void> _generatePmStatus() async {
    final eng = LanguageProvider.isEnglish(context);
    setState(() {
      _genBusy = true;
      _genLog = '';
    });
    await PmStatusService.load();
    final entries = PmStatusService.entries;
    var ok = 0;
    var fail = 0;
    // Group by month folder: PM_Status/<Month>/…
    final byMonth = <String, List<PmStatusEntry>>{};
    for (final e in entries) {
      byMonth.putIfAbsent(e.month, () => []).add(e);
    }
    final months = byMonth.keys.toList()..sort();
    for (final month in months) {
      final monthFolder = 'PM_Status/$month';
      final closed = byMonth[month]!.where((e) => e.isClosed).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final openNow = byMonth[month]!.where((e) => !e.isClosed).toList();
      // Placeholder files so empty folders exist
      if (closed.isEmpty) {
        await RepoService.writeRawFile('$monthFolder/Closed PM/README.txt',
            base64Encode(utf8.encode(
                eng ? 'No closed PM reports this month' : 'Tiada laporan PM selesai bulan ini')));
      }
if (openNow.isNotEmpty) {
        for (final e in openNow) {
          final dayFolder = '$monthFolder/${e.isInProgress ? 'In Progress PM' : 'Open PM'}/'
              '${e.date}/${e.sys}';
          final report = _pmReportText(e, eng);
          final r = await RepoService.writeRawFile('$dayFolder/report.txt',
              base64Encode(utf8.encode(report)));
          if (r) ok++; else fail++;
        }
      }
    }
    // Closed reports with photos
    for (final e in entries.where((x) => x.isClosed)) {
      final folder = 'PM_Status/${e.month}/Closed PM/${e.date}/'
          '${e.sys}/${e.asset}';
      final report = _pmReportText(e, eng);
      final r = await RepoService.writeRawFile('$folder/report.txt',
          base64Encode(utf8.encode(report)));
      if (r) ok++; else fail++;
      if (e.photos.isNotEmpty) {
        final code = _assetCode(e.asset);
        var pi = 0;
        for (final p in e.photos) {
          pi++;
          final pr = await RepoService.writeRawFile(
              '$folder/${code}_$pi.jpg', p);
          if (pr) ok++; else fail++;
        }
      }
    }
    if (mounted) {
      setState(() {
        _genBusy = false;
        _genLog = eng
            ? 'Done — $ok files uploaded, $fail failed'
            : 'Siap — $ok fail dimuat naik, $fail gagal';
      });
    }
  }

  /// Downloads every file under PM_Status/ from the repo into a local folder,
  /// with a clean structure:
  /// FM_Report\PM_Status\<Status>\<date>\<System, e.g. 1.0 ACMV>\<asset>\files.
  Future<void> _downloadPmReports() async {
    final eng = LanguageProvider.isEnglish(context);
    setState(() => _dlBusy = true);
    try {
      final paths = await RepoService.listAllFiles('PM_Status/');
      if (paths.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(eng ? 'No PM reports in the repo yet' : 'Tiada laporan PM di repo lagi')));
        return;
      }

      // Map short sys code ("1.0") → full system name ("1.0 ACMV") from the
      // loaded PPM schedule so local folders use the full name.
      final sysNames = <String, String>{};
      for (final m in _months) {
        for (final r in m.rows) {
          final code = r.sys.split(' ').first.trim();
          if (code.isNotEmpty && !sysNames.containsKey(code)) {
            sysNames[code] = r.sys;
          }
        }
      }
      for (final e in PmStatusService.entries) {
        sysNames.putIfAbsent(e.sys.split(' ').first.trim(), () => e.sys);
      }

      final files = <String, String>{};
      for (final p in paths) {
        final b64 = await RepoService.readRawFile(p);
        if (b64 == null) continue;
        final local = _localReportPath(p, sysNames);
        if (local != null) files[local] = b64;
      }
      final msg = await ReportSaver.save(files);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(eng ? 'PM report: $msg' : 'Laporan PM: $msg')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(eng ? 'Download failed: $e' : 'Muat turun gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _dlBusy = false);
    }
  }

  /// Converts a repo path like
  ///   PM_Status/2026-08/Closed PM/2026-08-10/1.0/AIR COOLED CHILLER-1/report.txt
  /// into the clean local layout (drop month, sys code → full system name):
  ///   PM_Status/Closed PM/2026-08-10/1.0 ACMV/AIR COOLED CHILLER-1/report.txt
  String? _localReportPath(String repoPath, Map<String, String> sysNames) {
    final seg = repoPath.split('/').where((s) => s.isNotEmpty).toList();
    if (seg.length < 3 || seg[0] != 'PM_Status') return null;
    final out = <String>['PM_Status'];
    final rest = seg.sublist(2); // drop month
    for (var i = 0; i < rest.length; i++) {
      var s = rest[i];
      final next = i + 1 < rest.length ? rest[i + 1] : '';
      final isDate = s.length == 10 && s[4] == '-' && s[7] == '-';
      if (i > 0 && !isDate && sysNames.containsKey(s) && s.split(' ').length == 1) {
        s = sysNames[s]!;
      }
      out.add(s);
    }
    return out.join('/');
  }

  String _pmReportText(PmStatusEntry e, bool eng) {
    final buf = StringBuffer();
    buf.writeln(eng ? 'PPM TASK REPORT' : 'LAPORAN TUGAS PPM');
    buf.writeln('====================');
    buf.writeln('System    : ${e.sys}${e.sub.isEmpty ? '' : ' / ${e.sub}'}');
    buf.writeln('Item      : ${e.item}');
    buf.writeln('Desc      : ${e.desc}');
    buf.writeln('Frequency : ${e.freq}  Markers: ${e.markers.join(',')}');
    buf.writeln('Status    : ${e.status}');
    buf.writeln('Technician: ${e.techName} (${e.techId})');
    buf.writeln('Attended  : ${e.attendedAt}');
    buf.writeln('Started   : ${e.startedAt}');
    buf.writeln('Closed    : ${e.closedAt}');
    buf.writeln('Floor     : Aras ${e.floor}');
    buf.writeln('Asset     : ${e.asset}');
    buf.writeln('WO No     : ${e.woNo}');
    buf.writeln('Findings  : ${e.findings}');
    buf.writeln('Remark    : ${e.remark}');
    buf.writeln('');
    return buf.toString();
  }

  /// Asset name → short code for photo filenames:
  /// "Air Handling Unit 3" → AHU3, "FAN COIL UNIT-2" → FCU2, "VRF" → VRF.
  static String _assetCode(String asset) {
    final m = RegExp(r'^(.+?)[\s_\-]+(\d+)$').firstMatch(asset.trim());
    final base = m?.group(1) ?? asset.trim();
    final num = m?.group(2) ?? '';
    final words = base
        .split(RegExp(r'[\s_\-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final code = words.length == 1
        ? words.first.toUpperCase()
        : words.map((w) => w[0].toUpperCase()).join();
    return '$code$num';
  }

  // ---------------------------------------------------------------------------
  Widget _buildJadual(bool eng) {
    final byDay = _tasksByDay();
    final systems = _month!.rows.map((r) => r.sys).toSet().toList();

    const itemW = 44.0;
    const descW = 148.0;
    const leftW = itemW + descW + 38.0;
    const dayW = 30.0;
    const rowH = 42.0;
    const palette = [
      Color(0xFF0D7377),
      Color(0xFF1565C0),
      Color(0xFF7B1FA2),
      Color(0xFFE64A19),
      Color(0xFF4A6741),
      Color(0xFFC62828),
      Color(0xFF6D4C41),
      Color(0xFF283593),
      Color(0xFF00838F),
    ];
    final sysColor = <String, Color>{};
    for (var i = 0; i < systems.length; i++) {
      sysColor[systems[i]] = palette[i % palette.length];
    }

    return Column(
      children: [
        Container(
          height: 34,
          color: const Color(0xFF0D7377),
          child: Row(
            children: [
              SizedBox(
                width: leftW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(eng ? 'Task' : 'Tugasan',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _headerStrip(dayW, byDay),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              for (final s in systems) ...[
                _systemBar(s, sysColor[s]!),
                if (_sysOpen(s)) ..._systemRows(s, itemW, dayW, rowH),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        _buildSummaryBar(byDay, eng),
      ],
    );
  }

  Widget _headerStrip(double dayW, Map<String, List<ScheduleTask>> byDay) {
    final days = _month!.days;
    return Row(
      children: List.generate(days.length, (i) {
        final d = DateTime.tryParse(days[i]);
        final wd = d?.weekday ?? 1;
        final weekend = wd >= 6;
        final day = d?.day ?? (i + 1);
        final has = (byDay[days[i]]?.length ?? 0) > 0;
        return Container(
          width: dayW,
          decoration: BoxDecoration(
            color: weekend ? Colors.white.withValues(alpha: 0.10) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(const ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'][wd],
                  style: const TextStyle(color: Colors.white70, fontSize: 8)),
              Text('$day',
                  style: TextStyle(
                      color: has ? const Color(0xFFFFD54F) : Colors.white,
                      fontSize: 11,
                      fontWeight: has ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        );
      }),
    );
  }

  /// Rows of one system with a compact sub-system header bar whenever the
  /// workbook groups tasks under a code like "9.3 Grey Water Harvesting
  /// System".
  List<Widget> _systemRows(String s, double itemW, double dayW, double rowH) {
    final out = <Widget>[];
    var prev = '';
    for (final row in _month!.rows.where((r) => r.sys == s)) {
      if (row.sub.isNotEmpty && row.sub != prev) out.add(_subBar(row.sub));
      out.add(GestureDetector(
        onTap: () => _showScopeSheet(row),
        child: _jadualRow(row, itemW, dayW, rowH, _month!.days),
      ));
      prev = row.sub;
    }
    return out;
  }

  Widget _subBar(String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      color: const Color(0xFF0D7377).withValues(alpha: 0.10),
      child: Text(sub,
          style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D7377))),
    );
  }

  Widget _systemBar(String s, Color color) {
    final open = _sysOpen(s);
    return Material(
      color: ThemeProvider.isDark(context)
          ? const Color(0xFF1B222B)
          : const Color(0xFFE8F2F0),
      child: InkWell(
        onTap: () => _toggleSystem(s),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 16,
                  color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(s,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Text('${_month!.rows.where((r) => r.sys == s).length} items',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jadualRow(PpmScheduleRow row, double itemW, double dayW, double rowH, List<String> days) {
    const descW = 148.0;
    return SizedBox(
      height: rowH,
      child: Row(
        children: [
          SizedBox(
            width: itemW + descW + 38,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: rowH,
                  color: const Color(0xFF0D7377).withValues(alpha: 0.6),
                ),
                Container(
                  width: itemW - 3,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.centerLeft,
                  child: Text(
                      row.item.isEmpty ? '·' : row.item,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  width: descW,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.centerLeft,
                  child: Text(row.desc,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  width: 38,
                  alignment: Alignment.center,
                  child: Text(row.freq,
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _jadualDayStrip(row, dayW, rowH, days),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _jadualDayStrip(
      PpmScheduleRow row, double dayW, double rowH, List<String> days) {
    return Row(
      children: List.generate(days.length, (i) {
        final iso = days[i];
        final markers = _isTaskClosed(iso, row) ? null : row.cells[iso];
        final d = DateTime.tryParse(iso);
        final weekend = (d?.weekday ?? 1) >= 6;
        return Container(
          width: dayW,
          height: rowH,
          decoration: BoxDecoration(
            border: Border(
                right: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.12), width: 0.5)),
            color: weekend ? Colors.grey.withValues(alpha: 0.05) : null,
          ),
          child: markers == null || markers.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: () => _showDayTasks(iso),
                  child: Center(
                    child: _markerStack(_sync(markers.toList()), dayW),
                  ),
                ),
        );
      }),
    );
  }

  Widget _markerStack(List<String> markers, double dayW) {
    if (markers.isEmpty) return const SizedBox.shrink();
    if (markers.length == 1) return _chip(markers.first, dayW, 14);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip(markers[0], dayW / 2, 10),
        _chip(markers[1], dayW / 2, 10),
      ],
    );
  }

  Widget _chip(String code, double w, double h) {
    return Container(
      width: w - 2,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _markerColors[code],
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(code,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              height: 1)),
    );
  }

  Widget _buildSummaryBar(Map<String, List<ScheduleTask>> byDay, bool eng) {
    var total = 0;
    var wk = 0;
    for (final v in byDay.values) {
      total += v.length;
    }
    for (final iso in _month!.days) {
      if ((byDay[iso] ?? []).isNotEmpty) wk++;
    }
    final s = eng
        ? '$total scheduled · $wk working days'
        : '$total berjadual · $wk hari bekerja';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: const Color(0xFF0D7377),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(s,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KALENDAR view — month grid with marker counts
  // ---------------------------------------------------------------------------
  Widget _buildKalendar(bool eng) {
    final byDay = _tasksByDay();
    final first = DateTime.tryParse(_month!.days.first) ?? DateTime(2026, 7, 1);
    final leading = first.weekday - 1;
    final rows = ((leading + _month!.days.length) / 7).ceil();

    return Column(
      children: [
        Row(
          children: const [
            'M', 'T', 'W', 'T', 'F', 'S', 'S'
          ].map((d) => Expanded(
                child: Center(
                  child: Text(d,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                ),
              )).toList(),
        ),
        Expanded(
          child: ListView(
            children: List.generate(rows, (r) {
              return SizedBox(
                height: 58,
                child: Row(
                  children: List.generate(7, (c) {
                    final cellIdx = r * 7 + c;
                    final day = cellIdx - leading + 1;
                    if (day < 1 || day > _month!.days.length) {
                      return const Expanded(child: SizedBox());
                    }
                    return _calCell(day, byDay);
                  }),
                ),
              );
            }),
          ),
        ),
        const Divider(height: 1),
        _buildSummaryCard(byDay, eng),
      ],
    );
  }

  Widget _calCell(int day, Map<String, List<ScheduleTask>> byDay) {
    final iso = _iso(day);
    final tasks = byDay[iso] ?? const [];
    final d = _dt(day);
    final weekend = (d?.weekday ?? 1) >= 6;
    final markerSet = <String>{};
    for (final t in tasks) {
      markerSet.addAll(t.markers);
    }
    final dots = _sync(markerSet.toList());

    return Expanded(
      child: GestureDetector(
        onTap: tasks.isEmpty ? null : () => _showDayTasks(iso),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: weekend ? Colors.grey.withValues(alpha: 0.07) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: tasks.isNotEmpty
                          ? FontWeight.w800
                          : FontWeight.w400,
                      color: tasks.isNotEmpty
                          ? const Color(0xFF0D7377)
                          : null)),
              if (tasks.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dots.take(4).map((m) => Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                            color: _markerColors[m], shape: BoxShape.circle),
                      )).toList(),
                ),
                const SizedBox(height: 2),
                Text('${tasks.length}',
                    style:
                        TextStyle(fontSize: 8, color: Colors.grey.shade500)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      Map<String, List<ScheduleTask>> byDay, bool eng) {
    var total = 0;
    for (final v in byDay.values) {
      total += v.length;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final code in _markerOrder)
            if (byDay.values.any((l) => l.any((t) => t.markers.contains(code))))
              _summaryPill(code, byDay),
          Text(' ·  $total ${eng ? 'total tasks' : 'jumlah tugasan'}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _summaryPill(String code, Map<String, List<ScheduleTask>> byDay) {
    var n = 0;
    for (final v in byDay.values) {
      for (final t in v) {
        if (t.markers.contains(code)) n++;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _markerColors[code]!.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$code ×$n',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _markerColors[code])),
    );
  }

  // ---------------------------------------------------------------------------
  // Day detail bottom sheet
  // ---------------------------------------------------------------------------
  void _showDayTasks(String iso) {
    final tasks = _tasksByDay()[iso] ?? const [];
    if (tasks.isEmpty) return;
    final d = DateTime.tryParse(iso);
    if (d == null) return;
    final eng = LanguageProvider.isEnglish(context);
    final isDark = ThemeProvider.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF171A21) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtl) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Text('${_month!.title} · $iso',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7377),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                          '${tasks.length} ${eng ? 'tasks' : 'tugas'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtl,
                  padding: const EdgeInsets.all(10),
                  children: tasks.map((t) => _taskTile(t, isDark)).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Score-free best match from the contact scope data
  // ---------------------------------------------------------------------------
  // Builds the target numeric chain used by the extractor: sub code first,
  // else the item's own numeric code (e.g. jadual rows "5.3 Pumps").
  String _scopeNumCode(PpmScheduleRow row) {
    final m = RegExp(r'^\d+(\.\d+)*').firstMatch(row.sub) ??
        RegExp(r'^\d+(\.\d+)*').firstMatch(row.item);
    return m?.group(0) ?? '';
  }

  PpmScopeEntry? _scopeFor(PpmScheduleRow row) {
    final sysNum = row.sys.split(' ').first;
    final scope = _scopes.where((s) => s.sys == sysNum).firstOrNull;
    if (scope == null) return null;
    final numCode = _scopeNumCode(row);
    final itemCode = row.item.trim();
    final desc = row.desc.trim().toLowerCase();
    PpmScopeEntry? best;
    var bestScore = -1;
    for (final e in scope.entries) {
      final numSame = numCode.isEmpty ? e.lastNum.isEmpty : e.lastNum == numCode;
      final codeSame = e.code.isNotEmpty && e.code == itemCode;
      final t = e.title.toLowerCase().trim();
      final titleSame = desc.isNotEmpty && (t == desc || t.contains(desc) || desc.contains(t));
      var s = 0;
      if (numSame) s += 1;
      if (codeSame) s += 2;
      if (titleSame) s += 3;
      if (s > bestScore) {
        bestScore = s;
        best = e;
      }
    }
    return bestScore > 0 ? best : null;
  }

  // ---------------------------------------------------------------------------
  // Contract scope detail sheet (tapped PPM row)
  // ---------------------------------------------------------------------------
  void _showScopeSheet(PpmScheduleRow row) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = ThemeProvider.isDark(context);
    final scope = _scopeFor(row);
    final items = scope?.items ?? const <PpmScopeItem>[];
    final usedFreqs = [
      for (final f in _scopeFreqs)
        if (items.any((i) => i.freq.contains(f))) f
    ];

    final groups = <String, List<PpmScopeItem>>{};
    for (final it in items) {
      for (final f in it.freq) {
        groups.putIfAbsent(f, () => []).add(it);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF171A21) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtl) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D7377), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_rounded,
                            color: Colors.white70, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row.sys,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (row.sub.isNotEmpty) row.sub,
                        if (row.item.isNotEmpty)
                          '${row.item} ${row.desc}'.trim(),
                      ].join(' · '),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                    if (usedFreqs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _freqPillRow(usedFreqs),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtl,
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (scope == null)
                      _emptyScope(eng, isDark)
                    else ...[
                      if (groups.isEmpty && scope.prose.isEmpty)
                        _emptyScope(eng, isDark)
                      else ...[
                        for (final f in usedFreqs) ...[
                          _freqSection(f, groups[f] ?? const [], eng, isDark),
                          const SizedBox(height: 10),
                        ],
                        if (scope.prose.isNotEmpty) ...[
                          _proseSection(scope.prose, eng, isDark),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _freqPillRow(List<String> freqs) {
    return SizedBox(
      height: 26,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in freqs)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _markerColors[f],
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(_freqName(f),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  String _freqName(String f) => _freqNames[f] ?? f;

  Widget _freqSection(String f, List<PpmScopeItem> items, bool eng, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _markerColors[f]!.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gpp_good_rounded, size: 14, color: _markerColors[f]),
              const SizedBox(width: 5),
              Text(_freqName(f),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _markerColors[f])),
              const SizedBox(width: 6),
              Text('${items.length}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final it in items) _itemTile(it, f, isDark),
      ],
    );
  }

  Widget _itemTile(PpmScopeItem it, String freq, bool isDark) {
    final color = _markerColors[freq]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22262F) : const Color(0xFFF2F5F4),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(it.code.replaceAll('.', ''),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(it.text,
                style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _emptyScope(bool eng, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 46, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(eng ? 'No contract scope for this task' : 'Tiada skop kontrak bagi tugasan ini',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(eng ? 'Check the PPM checklist workbook for details.' : 'Rujuk buku senarai semak PPM untuk butiran.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _proseSection(List<String> prose, bool eng, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eng ? 'Notes' : 'Nota',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey)),
        const SizedBox(height: 8),
        for (final p in prose)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22262F) : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(p, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ),
      ],
    );
  }

  Widget _taskTile(ScheduleTask t, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF22262F) : const Color(0xFFF2F5F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D7377),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.sys,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D7377))),
                    if (t.sub.isNotEmpty)
                      Text(t.sub,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600)),
                    Text('${t.item.isEmpty ? '' : '${t.item} · '}${t.desc}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ...t.markers.map((m) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _markerColors[m],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(m,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                  )),
              const Spacer(),
              Text(t.freq.isEmpty ? '-' : t.freq,
                  style:
                      TextStyle(fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

class ScheduleTask {
  final String sys;
  final String sub;
  final String item;
  final String desc;
  final String freq;
  final List<String> markers;
  ScheduleTask({
    required this.sys,
    this.sub = '',
    required this.item,
    required this.desc,
    required this.freq,
    required this.markers,
  });
}