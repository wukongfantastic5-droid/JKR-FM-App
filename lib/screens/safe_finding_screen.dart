import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../localization.dart';
import '../services/safe_finding_service.dart';
import '../services/doc_deliver.dart';
import '../services/repo_service.dart';
import '../widgets/http_error_banner.dart';
import 'safe_finding_task_screen.dart';

/// Safe Finding list screen shared by both accounts:
///  - admin mode: full manage (create/edit/delete) + download generated reports
///  - tech mode:  technician creates findings, taps a card to attend/close it
class SafeFindingScreen extends StatefulWidget {
  final String mode; // 'admin' | 'tech'
  final String techId;
  final String techName;
  const SafeFindingScreen({
    super.key,
    this.mode = 'admin',
    this.techId = '',
    this.techName = '',
  });

  @override
  State<SafeFindingScreen> createState() => _SafeFindingScreenState();
}

class _SafeFindingScreenState extends State<SafeFindingScreen> {
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
    if (widget.mode == 'admin') {
      _timer = Timer.periodic(const Duration(seconds: 8), (_) => SafeFindingService.load());
    }
    SafeFindingService.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SafeFindingService.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) setState(() {});
  }

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
    await SafeFindingService.load();
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

  Future<void> _createFinding(bool eng) async {
    var date = DateTime.now();
    var floor = _floors[0];
    var savedId = '';
    final idCtrl = TextEditingController(
        text: SafeFindingService.nextId().substring(3)); // "2026-001"
    final issueCtrl = TextEditingController();
    final photos = <String>[];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(eng ? 'New Safe Finding' : 'Penemuan Keselamatan Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'No. Rujukan',
                    prefixText: 'SF-',
                    hintText: 'e.g. 2026-001',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0D7377)),
                  title: Text(_fmtDate(date.toIso8601String())),
                  subtitle: Text(eng ? 'Tarikh / Date' : 'Tarikh / Date'),
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
                  controller: issueCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Isu / Issue',
                    hintText: 'e.g. Kabel terdedah, Lantai licin',
                    prefixIcon: Icon(Icons.warning_amber_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                _dialogPhotoSection(ctx, setDlg, photos, eng),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(eng ? 'Cancel' : 'Batal')),
            ElevatedButton(
              onPressed: (widget.mode == 'tech' && photos.length < 3)
                  ? null
                  : () {
                final raw = idCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
                final id = raw.isEmpty ? SafeFindingService.nextId() : 'SF-$raw';
                final issue = issueCtrl.text.trim();
                if (issue.isEmpty) return;
                if (SafeFindingService.byId(id) != null) {
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
              child: Text(eng ? 'Save Finding' : 'Simpan Penemuan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      _showLoading(eng ? 'Saving finding...' : 'Menyimpan penemuan...');
      final saved = await _saveFinding(
          savedId, date, floor, issueCtrl.text.trim(), photos);
      _hideLoading();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved
              ? (widget.mode == 'tech'
                  ? (eng
                      ? 'Finding saved — already attended'
                      : 'Penemuan disimpan — telah dihadiri')
                  : (eng ? 'Finding saved' : 'Penemuan disimpan'))
              : (eng ? 'Failed to save — retry' : 'Gagal simpan — cuba lagi')),
        ));
      }
    }
  }

  Future<bool> _saveFinding(String id, DateTime date, String floor,
      String issue, List<String> photos) async {
    final now = DateTime.now();
    final f = SafeFinding(
      id: id,
      date: date.toIso8601String(),
      floor: floor,
      issue: issue,
      photos: List.from(photos),
      // A technician creating the finding has already attended it, so the
      // finding starts IN PROGRESS with the tech assigned. Admin-created
      // findings stay OPEN for a technician to attend later.
      status: widget.mode == 'tech' ? 'in_progress' : 'open',
      techId: widget.mode == 'tech' ? widget.techId : '',
      techName: widget.mode == 'tech' ? widget.techName : '',
      attendedAt: widget.mode == 'tech' ? now.toIso8601String() : '',
    );
    return await SafeFindingService.create(f);
  }

  /// Camera / gallery picker + thumbnail grid used inside the create dialog.
  Widget _dialogPhotoSection(
      BuildContext dlgCtx, StateSetter setDlg, List<String> photos, bool eng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(eng ? 'Photos (for report)' : 'Gambar (untuk laporan)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            if (widget.mode == 'tech') ...[
              const SizedBox(width: 8),
              Text(
                eng ? 'at least 3 to save' : 'sekurang-kurangnya 3 untuk simpan',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
        if (widget.mode == 'tech') ...[
          const SizedBox(height: 6),
          Text(
            photos.length < 3
                ? (eng
                    ? 'Add ${3 - photos.length} more photo(s)'
                    : 'Tambah ${3 - photos.length} lagi gambar')
                : (eng ? '✓ ${photos.length} photos added' : '✓ ${photos.length} gambar ditambah'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: photos.length < 3
                  ? Colors.grey.shade600
                  : const Color(0xFF16A34A),
            ),
          ),
        ],
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < photos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(photos[i]),
                        width: 84,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 84,
                          height: 70,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => setDlg(() => photos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _pickPhotoDialog(dlgCtx, setDlg, photos, eng),
            icon: const Icon(Icons.add_a_photo_rounded, size: 16, color: Color(0xFF0D7377)),
            label: Text(
              photos.isEmpty
                  ? (eng ? 'Add photo (camera / gallery)' : 'Tambah gambar (kamera / galeri)')
                  : '${eng ? 'Add more photos' : 'Tambah lagi gambar'} (${photos.length})',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF0D7377), fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickPhotoDialog(
      BuildContext dlgCtx, StateSetter setDlg, List<String> photos, bool eng) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: dlgCtx,
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
    setDlg(() => photos.add(base64Encode(bytes)));
  }

  Future<void> _editFinding(SafeFinding f, bool eng) async {
    var date = DateTime.tryParse(f.date) ?? DateTime.now();
    var floor = _floors.contains(f.floor) ? f.floor : _floors[0];
    final sfPrefix = f.id.toUpperCase().startsWith('SF-');
    final idCtrl = TextEditingController(
        text: (sfPrefix && f.id.length > 3) ? f.id.substring(3) : f.id);
    final issueCtrl = TextEditingController(text: f.issue);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(eng ? 'Edit Finding' : 'Edit Penemuan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  decoration: InputDecoration(
                    labelText: 'No. Rujukan',
                    prefixText: sfPrefix ? 'SF-' : null,
                    hintText: sfPrefix ? 'e.g. 2026-001' : 'e.g. SF/2026/001',
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0D7377)),
                  title: Text(_fmtDate(date.toIso8601String())),
                  subtitle: Text(eng ? 'Tarikh / Date' : 'Tarikh / Date'),
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
                  controller: issueCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Isu / Issue',
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
                final newId = sfPrefix ? 'SF-$raw' : raw;
                final issue = issueCtrl.text.trim();
                if (newId.isEmpty || issue.isEmpty) return;
                if (newId != f.id && SafeFindingService.byId(newId) != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(eng
                        ? 'No Rujukan $newId already exists'
                        : 'No Rujukan $newId sudah wujud'),
                  ));
                  return;
                }
                f.date = date.toIso8601String();
                f.floor = floor;
                f.issue = issue;
                _applyEdit(f, newId, eng);
                Navigator.of(ctx).pop(true);
              },
              child: Text(eng ? 'Save' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'Finding updated' : 'Penemuan dikemaskini'),
      ));
    }
  }

  Future<void> _applyEdit(SafeFinding f, String newId, bool eng) async {
    _showLoading(eng ? 'Updating finding...' : 'Mengemaskini penemuan...');
    final ok = await SafeFindingService.update(f, newId: newId);
    _hideLoading();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (eng ? 'Finding updated' : 'Penemuan dikemaskini')
            : (eng ? 'Failed to update — retry' : 'Gagal kemaskini — cuba lagi')),
      ));
    }
  }

  Future<void> _deleteFinding(SafeFinding f, bool eng) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete finding?' : 'Padam penemuan?'),
        content: Text('${f.id} — ${f.issue}'),
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
      _showLoading(eng ? 'Deleting finding...' : 'Memadam penemuan...');
      final ok = await SafeFindingService.removeEntry(f.id);
      _hideLoading();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? (eng ? 'Finding deleted' : 'Penemuan dipadam')
              : (eng ? 'Failed to delete — retry' : 'Gagal padam — cuba lagi')),
        ));
      }
    }
  }

  Future<void> _downloadReport(SafeFinding f, bool eng) async {
    if (f.reportPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'No report yet' : 'Belum ada laporan'),
      ));
      return;
    }
    final raw = await RepoService.readRawFile(f.reportPath);
    if (raw == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'Report not found on GitHub' : 'Laporan tidak dijumpai di GitHub'),
      ));
      return;
    }
    final bytes = base64Decode(raw);
    final path = await DocDeliver.saveLocal(
        'Safe_Finding', '${f.id}.docx', Uint8List.fromList(bytes));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path.isEmpty
            ? (eng ? 'Report saved to GitHub only' : 'Laporan disimpan di GitHub sahaja')
            : 'Report → $path'),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  (Color, String) _statusStyle(SafeFinding f, bool eng) {
    if (f.isClosed) {
      return (const Color(0xFF16A34A), eng ? 'CLOSED' : 'SELESAI');
    }
    if (f.isInProgress) {
      return (const Color(0xFFF59E0B), eng ? 'IN PROGRESS' : 'SEDANG DIJALANKAN');
    }
    return (const Color(0xFFEF4444), eng ? 'OPEN' : 'TERBUKA');
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final list = _filter == 'all'
        ? SafeFindingService.entries
        : SafeFindingService.entries.where((e) => e.status == _filter).toList();
    final sorted = List<SafeFinding>.from(list)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Safe Finding' : 'Penemuan Keselamatan'),
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
                              eng ? 'No safe findings yet' : 'Tiada penemuan keselamatan lagi',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            itemCount: sorted.length,
                            itemBuilder: (_, i) => _card(sorted[i], eng),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createFinding(eng),
        icon: const Icon(Icons.add_rounded),
        label: Text(eng ? 'New Finding' : 'Penemuan Baru'),
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

  Widget _card(SafeFinding f, bool eng) {
    final (color, label) = _statusStyle(f, eng);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (widget.mode == 'tech') {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => SafeFindingTaskScreen(
                  findingId: f.id,
                  techId: widget.techId,
                  techName: widget.techName,
                ),
              ),
            );
            if (changed == true) {
              await SafeFindingService.load();
              if (mounted) setState(() {});
            }
          } else {
            _showDetails(f, eng);
          }
        },
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
                    f.id,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                f.issue,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(_fmtDate(f.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 14),
                  Icon(Icons.layers_rounded, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(f.floor, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              if (f.techName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 5),
                    Text(
                      eng
                          ? 'Assigned: ${f.techName}'
                          : 'Dikendalikan: ${f.techName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
              if (f.isClosed && f.reportPath.isNotEmpty) ...[
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

  Future<void> _showDetails(SafeFinding f, bool eng) async {
    final (color, label) = _statusStyle(f, eng);
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
                  Text(f.id, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
              _detailRow(Icons.calendar_today_rounded, eng ? 'Tarikh' : 'Tarikh', _fmtDate(f.date)),
              _detailRow(Icons.layers_rounded, 'Aras', f.floor),
              _detailRow(Icons.warning_amber_rounded, eng ? 'Isu / Issue' : 'Isu / Issue', f.issue),
              if (f.techName.isNotEmpty) _detailRow(Icons.person_rounded, eng ? 'Technician' : 'Teknisi', f.techName),
              if (f.attendedAt.isNotEmpty) _detailRow(Icons.play_circle_rounded, eng ? 'Attended at' : 'Dihadiri pada', _fmtDate(f.attendedAt)),
              if (f.closedAt.isNotEmpty) _detailRow(Icons.done_all_rounded, eng ? 'Closed at' : 'Ditutup pada', _fmtDate(f.closedAt)),
              if (f.findings.trim().isNotEmpty) _detailRow(Icons.search_rounded, eng ? 'Findings' : 'Dapatan', f.findings.trim()),
              if (f.remark.trim().isNotEmpty) _detailRow(Icons.notes_rounded, eng ? 'Remark' : 'Catatan', f.remark.trim()),
              if (f.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.photo_library_rounded, size: 16, color: const Color(0xFF0D7377)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: Text('${eng ? 'Photos' : 'Gambar'}:',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Text('${f.photos.length}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _editFinding(f, eng);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(eng ? 'Edit Finding' : 'Edit Penemuan'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (f.isClosed && f.reportPath.isNotEmpty)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _downloadReport(f, eng);
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
                            _deleteFinding(f, eng);
                          },
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          label: Text(eng
                              ? (f.isInProgress ? 'Cancel Finding' : 'Delete Finding')
                              : (f.isInProgress ? 'Batal Penemuan' : 'Padam Penemuan')),
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