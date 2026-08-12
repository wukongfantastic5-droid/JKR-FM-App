import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../localization.dart';
import '../services/safe_finding_service.dart';
import '../services/safe_finding_docx.dart';
import '../services/doc_deliver.dart';
import '../services/repo_service.dart';

/// Technician-side Safe Finding task screen (mirrors the CM task flow):
/// attend the finding, add photos from camera/gallery, record findings and
/// close — closing generates the Word report into FM_Report\Safe_Finding.
class SafeFindingTaskScreen extends StatefulWidget {
  final String findingId;
  final String techId;
  final String techName;
  const SafeFindingTaskScreen({
    super.key,
    required this.findingId,
    required this.techId,
    required this.techName,
  });

  @override
  State<SafeFindingTaskScreen> createState() => _SafeFindingTaskScreenState();
}

class _SafeFindingTaskScreenState extends State<SafeFindingTaskScreen> {
  late SafeFinding _sf;
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
    await SafeFindingService.load();
    final cur = SafeFindingService.byId(widget.findingId);
    if (cur != null) {
      _sf = cur;
      _findingsCtrl.text = _sf.findings;
      _remarkCtrl.text = _sf.remark;
      if (_techName.isEmpty) _techName = _sf.techName;
    } else {
      _sf = SafeFinding(id: widget.findingId, date: '', floor: '', issue: '');
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

  Future<void> _pickPhoto() async {
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
      setState(() => _sf.photos = List.from(_sf.photos)..add(base64Encode(bytes)));
    }
  }

  Future<void> _removePhoto(int index) async {
    if (_saving) return;
    setState(() => _sf.photos = List.from(_sf.photos)..removeAt(index));
  }

  Future<void> _attend(bool eng) async {
    setState(() => _saving = true);
    final ok = await SafeFindingService.attend(
        widget.findingId, widget.techId, _techName);
    if (ok) await _load();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Finding taken — now add photos & details' : 'Penemuan diambil — tambah gambar & maklumat')
          : (eng ? 'Failed to save — check internet & retry${_errHint()}' : 'Gagal simpan — semak internet & cuba lagi${_errHint()}')),
    ));
  }

  String _errHint() {
    final e = RepoService.lastHttpError;
    return e.isEmpty ? '' : '\n($e)';
  }

  Future<void> _close(bool eng) async {
    if (_sf.photos.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'Need at least 3 photos (camera or gallery)'
            : 'Perlu sekurang-kurangnya 3 gambar (kamera atau galeri)'),
      ));
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Close this Safe Finding?' : 'Tutup penemuan ini?'),
        content: Text(eng
            ? '${_sf.id} — ${_sf.issue}\n\n'
                'The finding will be marked CLOSED and the Word report will be generated with all photos.'
            : '${_sf.id} — ${_sf.issue}\n\n'
                'Penemuan akan ditandakan SELESAI dan laporan Word akan dijana dengan semua gambar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Yes, Close' : 'Ya, Tutup'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _saving = true);
    if (!mounted) return;
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
                  Text(eng ? 'Generating Word report...' : 'Menjana laporan Word...',
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
      ok = await SafeFindingService.close(
        widget.findingId,
        photos: _sf.photos,
        findings: _findingsCtrl.text.trim(),
        remark: _remarkCtrl.text.trim(),
      );
      if (ok) {
        await SafeFindingService.load();
        final fresh = SafeFindingService.byId(widget.findingId);
        if (fresh != null) _sf = fresh;
        final bytes = await SafeFindingDocxService.build(_sf, DateTime.now());
        reportPath = 'Safe_Finding/${_sf.id}.docx';
        final pushed = await RepoService.writeRawFile(reportPath, base64Encode(bytes));
        await DocDeliver.saveLocal('Safe_Finding', '${_sf.id}.docx', bytes);
        if (pushed) {
          await SafeFindingService.close(
            widget.findingId,
            photos: _sf.photos,
            findings: _sf.findings,
            remark: _sf.remark,
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
          ? (eng ? 'Finding closed ✓ report generated' : 'Penemuan ditutup ✓ laporan dijana')
          : (eng ? 'FAILED to close finding — retry' : 'GAGAL tutup penemuan — cuba lagi')),
      duration: const Duration(seconds: 4),
    ));
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Safe Finding' : 'Penemuan Keselamatan'),
        actions: [
          if (_sf.isClosed)
            IconButton(
              icon: const Icon(Icons.description_rounded),
              tooltip: eng ? 'Report info' : 'Maklumat laporan',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    _sf.reportPath.isEmpty
                        ? (eng ? 'No report uploaded yet' : 'Belum ada laporan dimuat naik')
                        : (eng ? 'Report: ${_sf.reportPath}' : 'Laporan: ${_sf.reportPath}'),
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
                if (_sf.isInProgress) ...[
                  const SizedBox(height: 12),
                  _photoCard(eng),
                  const SizedBox(height: 12),
                  _findingsCard(eng),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: (_saving || _sf.photos.length < 3)
                          ? null
                          : () => _close(eng),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(
                        eng ? 'CLOSE FINDING (generate report)' : 'TUTUP PENEMUAN (jana laporan)',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sf.photos.length < 3
                        ? (eng
                            ? 'Add ${3 - _sf.photos.length} more photo(s) to enable the button'
                            : 'Tambah ${3 - _sf.photos.length} lagi gambar untuk membolehkan butang')
                        : (eng
                            ? '✓ ${_sf.photos.length} photos added'
                            : '✓ ${_sf.photos.length} gambar ditambah'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _sf.photos.length < 3
                          ? Colors.grey.shade600
                          : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _statusBanner(bool eng) {
    final (color, label) = _sf.isClosed
        ? (const Color(0xFF16A34A), eng ? 'CLOSED' : 'SELESAI')
        : _sf.isInProgress
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
            _sf.isClosed
                ? Icons.check_circle_rounded
                : _sf.isInProgress
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
          if (_sf.isInProgress && _sf.techName.isNotEmpty)
            Text(
              _sf.techName,
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
                  _sf.id,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_sf.issue, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: const Color(0xFF0D7377)),
              const SizedBox(width: 6),
              Text('${eng ? 'Tarikh' : 'Tarikh'}: ${_fmtDate(_sf.date)}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.layers_rounded, size: 14, color: const Color(0xFF0D7377)),
              const SizedBox(width: 6),
              Text('Aras: ${_sf.floor}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (_sf.isOpen) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _attend(eng),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  eng ? 'ATTEND — TAKING THE FINDING' : 'AMBIL TUGAS',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          if (_sf.isClosed && _sf.closedAt.isNotEmpty)
            Text(
              '${eng ? 'Closed at' : 'Ditutup pada'}: ${_fmtDate(_sf.closedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _photoCard(bool eng) {
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
          Row(
            children: [
              Text(eng ? 'Photos (for report)' : 'Gambar (untuk laporan)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text(
                eng ? 'at least 3 — camera or gallery' : 'sekurang-kurangnya 3 — kamera atau galeri',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_sf.photos.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: _sf.photos.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => Dialog(
                    backgroundColor: Colors.black,
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(
                        base64Decode(_sf.photos[i]),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color: Colors.grey.shade800,
                          child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(_sf.photos[i]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => _removePhoto(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _pickPhoto,
              icon: const Icon(Icons.add_a_photo_rounded, size: 16, color: Color(0xFF0D7377)),
              label: Text(
                _sf.photos.isEmpty
                    ? (eng ? 'Add photo (camera / gallery)' : 'Tambah gambar (kamera / galeri)')
                    : '${eng ? 'Add more photos' : 'Tambah lagi gambar'} (${_sf.photos.length})',
                style: const TextStyle(fontSize: 12, color: Color(0xFF0D7377), fontWeight: FontWeight.w700),
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