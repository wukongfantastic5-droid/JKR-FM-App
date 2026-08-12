import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization.dart';
import '../services/cm_service.dart';
import '../services/cm_docx.dart';
import '../services/repo_service.dart';

class CmTaskScreen extends StatefulWidget {
  final String woId;
  final String techId;
  final String techName;
  const CmTaskScreen({
    super.key,
    required this.woId,
    required this.techId,
    required this.techName,
  });

  @override
  State<CmTaskScreen> createState() => _CmTaskScreenState();
}

class _CmTaskScreenState extends State<CmTaskScreen> {
  late CmWorkOrder _wo;
  bool _saving = false;
  bool _loaded = false;
  String _techName = '';

  final _findingsCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _techName = widget.techName;
    _load();
  }

  @override
  void dispose() {
    _findingsCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await CmService.load();
    final cur = CmService.byId(widget.woId);
    if (cur != null) {
      _wo = cur;
      _findingsCtrl.text = _wo.findings;
      _remarkCtrl.text = _wo.remark;
      if (_techName.isEmpty) _techName = _wo.techName;
    } else {
      _wo = CmWorkOrder(id: widget.woId, date: '', floor: '', defect: '');
    }
    if (mounted) setState(() => _loaded = true);
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

  Future<void> _pickPhoto(List<String> slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171A21)
          : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFF0D7377)),
              title: const Text('Camera / Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0D7377)),
              title: const Text('Gallery / Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() => slot.add(base64Encode(bytes)));
    }
  }

  Future<void> _attend(bool eng) async {
    setState(() => _saving = true);
    final ok = await CmService.attend(widget.woId, widget.techId, _techName);
    if (ok) await _load();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'WO taken — now take 3 photos (before/during/after)' : 'WO diambil — ambil 3 gambar (sebelum/semasa/selesai)')
          : (eng ? 'Failed to save — check internet & retry${_errHint()}' : 'Gagal simpan — semak internet & cuba lagi${_errHint()}')),
    ));
  }

  String _errHint() {
    final e = RepoService.lastHttpError;
    return e.isEmpty ? '' : '\n($e)';
  }

  Future<void> _close(bool eng) async {
    if (_wo.photosBefore.isEmpty || _wo.photosDuring.isEmpty || _wo.photosAfter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'Need at least 1 photo in each column (before, during, after)'
            : 'Perlu sekurang-kurangnya 1 gambar setiap ruang (sebelum, semasa, selesai)'),
      ));
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Close this WO?' : 'Tutup WO ini?'),
        content: Text(eng
            ? '${_wo.id} — ${_wo.defect}\n\n'
                'The WO will be marked CLOSED and the Word report will be generated with all 3 photo columns.'
            : '${_wo.id} — ${_wo.defect}\n\n'
                'WO akan ditandakan SELESAI dan laporan Word akan dijana dengan 3 ruang gambar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Yes, Close WO' : 'Ya, Tutup WO'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _saving = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x99051E24),
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 34, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Color(0xFF0D7377), blurRadius: 48, spreadRadius: 10),
                  BoxShadow(color: Colors.black26, blurRadius: 18),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF0D7377)),
                  ),
                  SizedBox(height: 18),
                  Text('Menjana laporan Word...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D7377))),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    bool ok = false;
    var reportPath = '';
    try {
      ok = await CmService.close(
        widget.woId,
        before: _wo.photosBefore,
        during: _wo.photosDuring,
        after: _wo.photosAfter,
        findings: _findingsCtrl.text.trim(),
        remark: _remarkCtrl.text.trim(),
      );
      if (ok) {
        await CmService.load();
        final fresh = CmService.byId(widget.woId);
        if (fresh != null) _wo = fresh;
        // Generate the Word report from the template with photos & details
        final bytes = await CmDocxService.build(_wo, DateTime.now());
        reportPath = 'CM_Report/${_wo.id}.docx';
        final pushed = await RepoService.writeRawFile(reportPath, base64Encode(bytes));
        CmDocxService.saveLocally(_wo.id, bytes);
        if (pushed) {
          await CmService.close(
            widget.woId,
            before: _wo.photosBefore,
            during: _wo.photosDuring,
            after: _wo.photosAfter,
            findings: _wo.findings,
            remark: _wo.remark,
            reportPath: reportPath,
          );
        }
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'WO closed ✓ report generated' : 'WO ditutup ✓ laporan dijana')
          : (eng ? 'FAILED to close WO — retry' : 'GAGAL tutup WO — cuba lagi')),
      duration: const Duration(seconds: 4),
    ));
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'CM Work Order' : 'WO CM'),
        actions: [
          if (_wo.isClosed)
            IconButton(
              icon: const Icon(Icons.description_rounded),
              tooltip: eng ? 'Open report' : 'Buka laporan',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    _wo.reportPath.isEmpty
                        ? (eng ? 'No report uploaded yet' : 'Belum ada laporan dimuat naik')
                        : (eng ? 'Report: ${_wo.reportPath}' : 'Laporan: ${_wo.reportPath}'),
                  ),
                ));
              },
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusBanner(eng),
                const SizedBox(height: 12),
                _infoCard(eng),
                if (_wo.isInProgress) ...[
                  const SizedBox(height: 12),
                  _photoColumns(eng),
                  const SizedBox(height: 12),
                  _findingsCard(eng),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _close(eng),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(
                        eng ? 'CLOSE WO (generate report)' : 'TUTUP WO (jana laporan)',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _statusBanner(bool eng) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, label) = _wo.isClosed
        ? (const Color(0xFF16A34A), eng ? 'CLOSED' : 'SELESAI')
        : _wo.isInProgress
            ? (const Color(0xFFF59E0B), eng ? 'IN PROGRESS' : 'SEDANG DIJALANKAN')
            : (const Color(0xFFEF4444), eng ? 'OPEN' : 'TERBUKA');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            _wo.isClosed
                ? Icons.check_circle_rounded
                : _wo.isInProgress
                    ? Icons.hourglass_top_rounded
                    : Icons.pending_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          if (_wo.isInProgress && _wo.techName.isNotEmpty)
            Text(
              _wo.techName,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _infoCard(bool eng) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D7377),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _wo.id,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_wo.defect, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: const Color(0xFF0D7377)),
              const SizedBox(width: 6),
              Text('${eng ? 'Tarikh' : 'Tarikh'}: ${_fmtDate(_wo.date)}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.layers_rounded, size: 14, color: const Color(0xFF0D7377)),
              const SizedBox(width: 6),
              Text('Aras: ${_wo.floor}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (_wo.isOpen) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _attend(eng),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  eng ? 'ATTEND — TAKING THE WO' : 'AMBIL TUGAS',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          if (_wo.isClosed && _wo.closedAt.isNotEmpty)
            Text(
              '${eng ? 'Closed at' : 'Ditutup pada'}: ${_fmtDate(_wo.closedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _photoColumns(bool eng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(eng ? 'Photos (for report)' : 'Gambar (untuk laporan)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text(
              '1 per column minimum',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _photoColumn(eng, 'SEBELUM', 'BEFORE REPAIR', _wo.photosBefore, const Color(0xFFEF4444))),
            const SizedBox(width: 8),
            Expanded(child: _photoColumn(eng, 'SEMASA', 'DURING REPAIR', _wo.photosDuring, const Color(0xFFF59E0B))),
            const SizedBox(width: 8),
            Expanded(child: _photoColumn(eng, 'SELESAI', 'AFTER REPAIR', _wo.photosAfter, const Color(0xFF16A34A))),
          ],
        ),
      ],
    );
  }

  Widget _photoColumn(bool eng, String title, String subtitle, List<String> photos, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Column(
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 7.5, color: Colors.grey.shade500, letterSpacing: 0.2)),
              ],
            ),
          ),
          ...photos.map((p) => GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => Dialog(
                    backgroundColor: Colors.black,
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(
                        base64Decode(p),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: Colors.grey.shade800,
                          child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(p),
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 90,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              )),
          Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _pickPhoto(photos),
                icon: Icon(Icons.add_a_photo_rounded, size: 16, color: color),
                label: Text(
                  photos.isEmpty ? (eng ? 'Add photo' : 'Tambah gambar') : '${photos.length}',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _findingsCard(bool eng) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eng ? 'Findings & Remarks' : 'Dapatan & Catatan',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(
            controller: _findingsCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: eng ? 'Findings / Dapatan' : 'Dapatan / Findings',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _remarkCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: eng ? 'Remark / Catatan' : 'Catatan / Remark',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
