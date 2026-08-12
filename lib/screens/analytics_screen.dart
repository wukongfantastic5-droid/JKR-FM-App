import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization.dart';
import '../services/complaint_service.dart';
import '../services/doc_deliver.dart';
import '../services/excel_service.dart';
import '../services/pm_status_service.dart';
import '../services/repo_service.dart';
import '../services/spare_part_service.dart';
import '../services/tech_service.dart';
import '../services/backup_service.dart';
import '../data/complaint_data.dart';

/// Dashboard-style analytics: complaint stats, low-stock alerts with WhatsApp
/// nudge to the recommended supplier, and PPM reminders (overdue / upcoming).
/// Downloads a 3-sheet Excel summary via [ExcelService].
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<ComplaintTicket> _tickets = [];
  List<dynamic> _months = [];
  List<dynamic> _lowStock = [];
  bool _loading = true;
  bool _exporting = false;
  bool _backingUp = false;
  String _err = '';

  static const _lowThreshold = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final results = await Future.wait([
        ComplaintService.load(),
        TechService.loadPpmSchedule(),
        SparePartService.load(),
        PmStatusService.load(),
      ]);
      final tickets = (results[0] as List<ComplaintTicket>).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final months = results[1] as List;
      final parts = (results[2] as List)
          .where((p) => (p as dynamic).quantity <= _lowThreshold)
          .toList()
        ..sort((a, b) => (a as dynamic).quantity.compareTo((b as dynamic).quantity));
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _months = months;
        _lowStock = parts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  int _count(String s) => _tickets.where((t) => t.status == s).length;

  List<MapEntry<String, int>> get _floorCounts {
    final map = <String, int>{};
    for (final t in _tickets) {
      map[t.floor] = (map[t.floor] ?? 0) + 1;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(5).toList();
  }

  Map<String, List<dynamic>> get _pmReminders {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final window = now.add(const Duration(days: 14));
    final windowStr = '${window.year.toString().padLeft(4, '0')}-'
        '${window.month.toString().padLeft(2, '0')}-'
        '${window.day.toString().padLeft(2, '0')}';
    final thisMonth = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';

    final overdue = <dynamic>[];
    final upcoming = <dynamic>[];
    for (final mRaw in _months) {
      final m = mRaw as dynamic;
      if (m.month != thisMonth) continue;
      for (final iso in m.days as List) {
        final date = iso as String;
        if (date.compareTo(today) < 0 || date.compareTo(windowStr) > 0) continue;
        for (final r in m.rows as List) {
          final row = r as dynamic;
          if (!(row.cells as Map).containsKey(date)) continue;
          final id = PmStatusService.buildId(
              date: date, sys: row.sys, item: row.item, desc: row.desc);
          if (PmStatusService.closedIdsOn(date).contains(id)) continue;
          final entry = {
            'date': date,
            'item': row.item,
            'sys': row.sys,
            'freq': row.freq,
            'markers': (row.cells[date] as Set).join(','),
          };
          if (date.compareTo(today) < 0) {
            overdue.add(entry);
          } else {
            upcoming.add(entry);
          }
        }
      }
    }
    overdue.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    upcoming.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return {'overdue': overdue, 'upcoming': upcoming};
  }

  String _waNumber(String raw) {
    String d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return '';
    if (d.startsWith('0')) d = '6$d'.substring(1);
    return d;
  }

  Future<void> _nudgeSupplier(dynamic part, bool eng) async {
    final supplier = (part as dynamic).recommendedSupplier;
    final base = supplier?.whatsapp as String? ?? '';
    final num = _waNumber(base);
    if (num.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'No WhatsApp number for the recommended supplier'
            : 'Tiada nombor WhatsApp untuk pembekal disyorkan'),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }
    final text = eng
        ? 'Restock alert: *${part.name}* is down to *${part.quantity}* pcs. Please check availability.'
        : 'Amaran stok: *${part.name}* tinggal *${part.quantity}* unit sahaja. Mohon semak bekalan.';
    await launchUrl(
      Uri.parse('https://wa.me/$num?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _export(bool eng) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final reminders = _pmReminders;
      final bytes = await ExcelService.build([
        ExcelSheet(
          name: 'Complaints',
          headers: const ['Status', 'Count'],
          rows: [
            ['Total', '${_tickets.length}'],
            ['Open', '${_count('open')}'],
            ['In Progress', '${_count('in_progress')}'],
            ['Closed', '${_count('closed')}'],
            ['Rejected', '${_count('rejected')}'],
            for (final f in _floorCounts) ['Floor ${f.key}', '${f.value}'],
          ],
        ),
        ExcelSheet(
          name: 'Low Stock',
          headers: const ['Spare Part', 'Quantity'],
          rows: [
            for (final p in _lowStock) [(p as dynamic).name, '${p.quantity}'],
          ],
        ),
        ExcelSheet(
          name: 'PM Reminders',
          headers: const ['Date', 'System', 'Item', 'Frequency', 'Markers', 'Status'],
          rows: [
            for (final r in reminders['overdue'] as List)
              [r['date'], r['sys'], r['item'], r['freq'], r['markers'], 'Overdue'],
            for (final r in reminders['upcoming'] as List)
              [r['date'], r['sys'], r['item'], r['freq'], r['markers'], 'Upcoming'],
          ],
        ),
      ]);
      final now = DateTime.now();
      final fileDate = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final fileName = 'Analytics_$fileDate.xlsx';
      final local = await DocDeliver.saveLocal('Analytics', fileName, bytes);
      final ok = await RepoService.writeRawFile(
          'Reports/Analytics/$fileName', base64Encode(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (local.isNotEmpty
                ? (eng ? 'Saved: $local' : 'Disimpan: $local')
                : (eng
                    ? 'Saved in database (Reports/Analytics)'
                    : 'Disimpan dalam database (Reports/Analytics)'))
            : (eng ? 'Export ok but save failed' : 'Eksport berjaya tetapi simpan gagal')),
      ));
      if (ok) {
        await DocDeliver.offerOpen(
          context,
          repoPath: 'Reports/Analytics/$fileName',
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
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _backup(bool eng) async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    try {
      final bytes = await BackupService.collectAll();
      if (bytes == null) {
        throw eng
            ? 'No files available to backup'
            : 'Tiada fail untuk disandarkan';
      }
      final now = DateTime.now();
      final fileName = 'DB_Backup_${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}.zip';
      final local = await DocDeliver.saveLocal('Backup', fileName, bytes);
      final ok = await RepoService.writeRawFile(
          'Reports/Backup/$fileName', base64Encode(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (local.isNotEmpty
                ? (eng ? 'Backup saved: $local' : 'Sandaran disimpan: $local')
                : (eng
                    ? 'Backup saved in database (Reports/Backup)'
                    : 'Sandaran disimpan dalam database (Reports/Backup)'))
            : (eng ? 'Backup ok but save failed' : 'Sandaran berjaya tetapi simpan gagal')),
      ));
      if (ok) {
        await DocDeliver.offerOpen(
          context,
          repoPath: 'Reports/Backup/$fileName',
          eng: eng,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'Backup failed: $e' : 'Sandaran gagal: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Analytics' : 'Analisis'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.table_chart_rounded),
              tooltip: eng ? 'Export to Excel' : 'Eksport ke Excel',
              onPressed: _exporting || _loading ? null : () => _export(eng),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(_err, textAlign: TextAlign.center),
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(eng ? 'Retry' : 'Cuba semula'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _backupCard(eng),
                      const SizedBox(height: 16),
                      _sectionHeader(Icons.report_problem_rounded, eng ? 'Complaint Summary' : 'Ringkasan Aduan',
                          const Color(0xFFDC2626)),
                      _statRow(eng),
                      if (_floorCounts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _floorBars(eng),
                      ],
                      const SizedBox(height: 22),
                      _sectionHeader(Icons.inventory_2_rounded, eng ? 'Low Stock Alerts' : 'Amaran Stok Rendah',
                          const Color(0xFFE07B39)),
                      _lowStockList(eng),
                      const SizedBox(height: 22),
                      _sectionHeader(Icons.event_available_rounded, eng ? 'PM Reminders' : 'Peringatan PM',
                          const Color(0xFF1D6FB8)),
                      _pmList(eng),
                    ],
                  ),
                ),
    );
  }

  Widget _backupCard(bool eng) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D7377), Color(0xFF0B5559)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eng ? 'Database Backup' : 'Sandaran Database',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 3),
                Text(
                  eng
                      ? 'Back up every file in the GitHub database into one ZIP'
                      : 'Sandarkan semua fail database GitHub ke satu ZIP',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white),
            onPressed: _backingUp ? null : () => _backup(eng),
            icon: _backingUp
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.archive_rounded, size: 18, color: Color(0xFF0D7377)),
            label: Text(_backingUp ? (eng ? 'Zipping…' : 'Membungkus…') : (eng ? 'Backup' : 'Sandar'),
                style: const TextStyle(color: Color(0xFF0D7377))),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _statRow(bool eng) {
    final items = [
      ('Total', _tickets.length, const Color(0xFF0D7377)),
      ('Open', _count('open'), const Color(0xFFDC2626)),
      ('In Progress', _count('in_progress'), const Color(0xFF1D6FB8)),
      ('Closed', _count('closed'), const Color(0xFF1B8A5A)),
    ];
    return Row(
      children: [
        for (final (label, value, color) in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text('$value',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                    Text(label,
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _floorBars(bool eng) {
    final max = _floorCounts.first.value;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eng ? 'Top floors' : 'Aras tertinggi',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final f in _floorCounts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(f.key,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: f.value / max,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${f.value}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _lowStockList(bool eng) {
    if (_lowStock.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(eng ? 'All items in stock' : 'Semua stok mencukupi',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
      );
    }
    return Column(
      children: [
        for (final p in _lowStock)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((p as dynamic).name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(
                        (p as dynamic).recommendedSupplier?.name as String? ?? '',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${p.quantity}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_rounded, size: 20, color: Color(0xFF16A34A)),
                  tooltip: eng ? 'WhatsApp supplier' : 'WhatsApp pembekal',
                  onPressed: () => _nudgeSupplier(p, eng),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pmList(bool eng) {
    final reminders = _pmReminders;
    final overdue = reminders['overdue'] as List;
    final upcoming = reminders['upcoming'] as List;
    if (overdue.isEmpty && upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(eng ? 'No PM tasks due this period' : 'Tiada tugas PM dalam tempoh ini',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
      );
    }
    return Column(
      children: [
        if (overdue.isNotEmpty) ...[
          _pmGroup(eng ? 'Overdue' : 'Terlepas', overdue, const Color(0xFFDC2626), eng),
          const SizedBox(height: 10),
        ],
        if (upcoming.isNotEmpty)
          _pmGroup(eng ? 'Next 14 days' : '14 hari akan datang', upcoming, const Color(0xFFE07B39), eng),
      ],
    );
  }

  Widget _pmGroup(String title, List items, Color color, bool eng) {
    var max = 40;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 6),
              Text('$title (${items.length})',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        for (final r in items.take(max))
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Text(r['date'].toString().substring(8),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['item'] as String,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${r['sys']} · ${r['markers']}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}