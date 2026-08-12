import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization.dart';
import '../services/cm_service.dart';
import '../services/cm_docx.dart';
import '../widgets/http_error_banner.dart';
import '../services/repo_service.dart';
import 'cm_task_screen.dart';

class CmAdminScreen extends StatefulWidget {
  /// Supervisor mode: adds a "Close WO" action that routes into the full
  /// close flow (photos + findings + generated Word report).
  final bool canClose;
  final String closeTechId;
  final String closeTechName;
  const CmAdminScreen({
    super.key,
    this.canClose = false,
    this.closeTechId = '',
    this.closeTechName = '',
  });

  @override
  State<CmAdminScreen> createState() => _CmAdminScreenState();
}

class _CmAdminScreenState extends State<CmAdminScreen> {
  bool _loading = true;
  String _filter = 'all'; // all | open | in_progress | closed
  Timer? _timer;

  static const List<String> _floors = [
    'B2', 'B1', 'P', 'G', 'M',
    'Aras 1',
    'Aras 2', 'Aras 3', 'Aras 4', 'Aras 5', 'Aras 6',
    'Aras 7', 'Aras 8', 'Aras 9', 'Aras 10', 'Aras 11', 'Aras 12',
    'Aras 13', 'Aras 14', 'Aras 15', 'Aras 16', 'Aras 17', 'Aras 18',
    'Aras 19', 'Aras 20', 'Aras 21', 'Aras 22', 'Aras 23', 'Aras 24',
    'Aras 25', 'Aras 26', 'Aras 27', 'Aras 28', 'Aras 29', 'Aras 30',
    'Aras 31', 'Aras 32', 'Aras 33', 'Aras 34', 'Aras 35', 'Aras 36',
    'Aras 37',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => CmService.load());
    CmService.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    _timer?.cancel();
    CmService.revision.removeListener(_onRevision);
    super.dispose();
  }

  /// Live UI refresh: fires on every poll result / repo change anywhere.
  void _onRevision() {
    if (mounted) setState(() {});
  }

  /// Blocking, brighter-than-everything loading popup. No tap outside closes it.
  void _showLoading(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x99051E24),
      barrierLabel: 'Loading',
      builder: (_) => PopScope(
        canPop: false,
        child: AbsorbPointer(
          absorbing: true,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF0D7377), blurRadius: 48, spreadRadius: 10),
                    BoxShadow(color: Colors.black26, blurRadius: 18),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 46,
                      height: 46,
                      child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF0D7377)),
                    ),
                    const SizedBox(height: 18),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D7377))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoading() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await CmService.load();
    if (mounted) setState(() => _loading = false);
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-${d.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _createWo(bool eng) async {
    var date = DateTime.now();
    var floor = _floors[0];
    var savedId = '';
    final idCtrl = TextEditingController();
    final defectCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(eng ? 'New Corrective Maintenance WO' : 'WO CM Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'No. Rujukan',
                    prefixText: 'JKRBG',
                    hintText: 'e.g. 200050023',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0D7377)),
                  title: Text(_fmtDate(date.toIso8601String())),
                  subtitle: Text(eng ? 'Tarikh / Date' : 'Tarikh / Tarikh'),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (p != null) setDlg(() => date = p);
                  },
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: floor,
                  decoration: const InputDecoration(
                    labelText: 'Aras / Floor',
                    prefixIcon: Icon(Icons.layers_rounded),
                  ),
                  items: _floors.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setDlg(() => floor = v ?? floor),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: defectCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Jenis kerosakan / Defect type',
                    hintText: 'e.g. Chiller tidak sejuk, Pump bocor',
                    prefixIcon: Icon(Icons.warning_amber_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(eng ? 'Cancel' : 'Batal')),
            ElevatedButton(
              onPressed: () {
                final digits = idCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
                final defect = defectCtrl.text.trim();
                if (digits.isEmpty || defect.isEmpty) return;
                final id = 'JKRBG$digits';
                if (CmService.byId(id) != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(eng
                        ? 'No Rujukan $id already exists'
                        : 'No Rujukan $id sudah wujud'),
                  ));
                  return;
                }
                savedId = id;
                Navigator.of(ctx).pop(true);
              },
              child: Text(eng ? 'Create WO' : 'Buat WO'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      _showLoading(eng ? 'Saving WO...' : 'Menyimpan WO...');
      final saved = await _saveWo(savedId, date, floor, defectCtrl.text.trim());
      _hideLoading();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved
              ? (eng ? 'WO created' : 'WO dicipta')
              : (eng ? 'Failed to save — retry' : 'Gagal simpan — cuba lagi')),
        ));
      }
    }
  }

  Future<bool> _saveWo(String id, DateTime date, String floor, String defect) async {
    final wo = CmWorkOrder(
      id: id,
      date: date.toIso8601String(),
      floor: floor,
      defect: defect,
    );
    return await CmService.create(wo);
  }

  Future<void> _editWo(CmWorkOrder wo, bool eng) async {
    var date = DateTime.tryParse(wo.date) ?? DateTime.now();
    var floor = _floors.contains(wo.floor) ? wo.floor : _floors[0];
    final jkrbg = wo.id.toUpperCase().startsWith('JKRBG');
    final idCtrl = TextEditingController(
        text: (jkrbg && wo.id.length > 5) ? wo.id.substring(5) : wo.id);
    final defectCtrl = TextEditingController(text: wo.defect);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(eng ? 'Edit WO' : 'Edit WO'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  decoration: InputDecoration(
                    labelText: 'No. Rujukan',
                    prefixText: jkrbg ? 'JKRBG' : null,
                    hintText: jkrbg ? 'e.g. 200050023' : 'e.g. CM/JKR/2026/001',
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0D7377)),
                  title: Text(_fmtDate(date.toIso8601String())),
                  subtitle: Text(eng ? 'Tarikh / Date' : 'Tarikh / Tarikh'),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (p != null) setDlg(() => date = p);
                  },
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: floor,
                  decoration: const InputDecoration(
                    labelText: 'Aras / Floor',
                    prefixIcon: Icon(Icons.layers_rounded),
                  ),
                  items: _floors.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setDlg(() => floor = v ?? floor),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: defectCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Jenis kerosakan / Defect type',
                    prefixIcon: Icon(Icons.warning_amber_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(eng ? 'Cancel' : 'Batal')),
            ElevatedButton(
              onPressed: () {
                final raw = idCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
                final newId = jkrbg ? 'JKRBG$raw' : raw;
                final defect = defectCtrl.text.trim();
                if (newId.isEmpty || defect.isEmpty) return;
                if (newId != wo.id && CmService.byId(newId) != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(eng
                        ? 'No Rujukan $newId already exists'
                        : 'No Rujukan $newId sudah wujud'),
                  ));
                  return;
                }
                Navigator.of(ctx).pop(true);
                _applyEdit(wo, newId, date, floor, defect, eng);
              },
              child: Text(eng ? 'Save' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'WO updated' : 'WO dikemaskini'),
      ));
    }
  }

  Future<void> _applyEdit(CmWorkOrder wo, String newId, DateTime date, String floor, String defect, bool eng) async {
    _showLoading(eng ? 'Updating WO...' : 'Mengemaskini WO...');
    wo.date = date.toIso8601String();
    wo.floor = floor;
    wo.defect = defect;
    final ok = await CmService.update(wo, newId: newId);
    _hideLoading();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (eng ? 'WO updated' : 'WO dikemaskini')
            : (eng ? 'Failed to update — retry' : 'Gagal kemaskini — cuba lagi')),
      ));
    }
  }

  Future<void> _deleteWo(CmWorkOrder wo, bool eng) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete WO?' : 'Padam WO?'),
        content: Text('${wo.id} — ${wo.defect}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Delete' : 'Padam', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (sure == true) {
      _showLoading(eng ? 'Deleting WO...' : 'Memadam WO...');
      final ok = await CmService.removeEntry(wo.id);
      _hideLoading();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? (eng ? 'WO deleted' : 'WO dipadam')
              : (eng ? 'Failed to delete — retry' : 'Gagal padam — cuba lagi')),
        ));
      }
    }
  }

  Future<void> _downloadReport(CmWorkOrder wo, bool eng) async {
    if (wo.reportPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'No report yet' : 'Belum ada laporan'),
      ));
      return;
    }
    final raw = await RepoService.readRawFile(wo.reportPath);
    if (raw == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'Report not found on GitHub' : 'Laporan tidak dijumpai di GitHub'),
      ));
      return;
    }
    final bytes = base64Decode(raw);
    final path = CmDocxService.saveLocally(wo.id, Uint8List.fromList(bytes));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path.isEmpty
            ? (eng ? 'Report saved to GitHub only' : 'Laporan disimpan di GitHub sahaja')
            : 'Report → $path'),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  (Color, String) _statusStyle(CmWorkOrder wo, bool eng) {
    if (wo.isClosed) {
      return (const Color(0xFF16A34A), eng ? 'CLOSED' : 'SELESAI');
    }
    if (wo.isInProgress) {
      return (const Color(0xFFF59E0B), eng ? 'IN PROGRESS' : 'SEDANG DIJALANKAN');
    }
    return (const Color(0xFFEF4444), eng ? 'OPEN' : 'TERBUKA');
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final list = _filter == 'all'
        ? CmService.entries
        : CmService.entries.where((e) => e.status == _filter).toList();
    final sorted = List<CmWorkOrder>.from(list)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Corrective Maintenance (CM)' : 'Penyelenggaraan Pembetulan (CM)'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  const HttpErrorBanner(),
                  SizedBox(
                    height: 46,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      children: [
                        _filterChip('all', eng ? 'All' : 'Semua', const Color(0xFF0D7377)),
                        _filterChip('open', eng ? 'Open' : 'Terbuka', const Color(0xFFEF4444)),
                        _filterChip('in_progress', eng ? 'In Progress' : 'Dalam Kerja', const Color(0xFFF59E0B)),
                        _filterChip('closed', eng ? 'Closed' : 'Selesai', const Color(0xFF16A34A)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: sorted.isEmpty
                        ? Center(
                            child: Text(
                              eng ? 'No CM work orders yet' : 'Tiada WO CM lagi',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            itemCount: sorted.length,
                            itemBuilder: (_, i) => _woCard(sorted[i], eng),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createWo(eng),
        icon: const Icon(Icons.add_rounded),
        label: Text(eng ? 'New WO' : 'WO Baru'),
      ),
    );
  }

  Widget _filterChip(String value, String label, Color color) {
    final sel = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: sel,
        label: Text(label),
        selectedColor: color,
        labelStyle: TextStyle(
          color: sel ? Colors.white : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _woCard(CmWorkOrder wo, bool eng) {
    final (color, label) = _statusStyle(wo, eng);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(wo, eng),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    wo.id,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                wo.defect,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(_fmtDate(wo.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 14),
                  Icon(Icons.layers_rounded, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(wo.floor, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              if (wo.techName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 5),
                    Text(
                      eng
                          ? 'Assigned: ${wo.techName}'
                          : 'Dikendalikan: ${wo.techName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
              if (wo.isClosed && wo.reportPath.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.description_rounded, size: 15, color: Color(0xFF0D7377)),
                    const SizedBox(width: 6),
                    Text(
                      eng ? 'Report generated ✓' : 'Laporan dijana ✓',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D7377)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(CmWorkOrder wo, bool eng) async {
    final (color, label) = _statusStyle(wo, eng);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171A21)
          : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Text(wo.id, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _detailRow(Icons.calendar_today_rounded, eng ? 'Tarikh' : 'Tarikh', _fmtDate(wo.date)),
              _detailRow(Icons.layers_rounded, 'Aras', wo.floor),
              _detailRow(Icons.warning_amber_rounded, eng ? 'Kategori Kerja' : 'Kategori Kerja', wo.defect),
              if (wo.techName.isNotEmpty) _detailRow(Icons.person_rounded, eng ? 'Technician' : 'Teknisi', wo.techName),
              if (wo.closedAt.isNotEmpty) _detailRow(Icons.done_all_rounded, eng ? 'Closed at' : 'Ditutup pada', _fmtDate(wo.closedAt)),
              const SizedBox(height: 14),
              Column(
                children: [
                  if (widget.canClose && !wo.isClosed) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CmTaskScreen(
                                woId: wo.id,
                                techId: widget.closeTechId,
                                techName: widget.closeTechName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(eng
                            ? 'Close WO (photos + report)'
                            : 'Tutup WO (gambar + laporan)'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _editWo(wo, eng);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(eng ? 'Edit WO' : 'Edit WO'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (wo.isClosed && wo.reportPath.isNotEmpty)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _downloadReport(wo, eng);
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(eng ? 'Download Report' : 'Muat Turun Laporan'),
                          ),
                        ),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _deleteWo(wo, eng);
                          },
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          label: Text(eng
                              ? (wo.isInProgress ? 'Cancel WO' : 'Delete WO')
                              : (wo.isInProgress ? 'Batal WO' : 'Padam WO')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D7377)),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
