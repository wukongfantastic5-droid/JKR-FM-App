import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/repo_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization.dart';
import '../data/pm_status_data.dart';
import '../services/pm_status_service.dart';

class PmTaskScreen extends StatefulWidget {
  final String date;
  final String sys;
  final String sub;
  final String item;
  final String desc;
  final String freq;
  final List<String> markers;
  final String techId;
  final String techName;
  const PmTaskScreen({
    super.key,
    required this.date,
    required this.sys,
    required this.sub,
    required this.item,
    required this.desc,
    required this.freq,
    required this.markers,
    required this.techId,
    required this.techName,
  });

  @override
  State<PmTaskScreen> createState() => _PmTaskScreenState();
}

class _PmTaskScreenState extends State<PmTaskScreen> {
  late PmStatusEntry _e;
  bool _saving = false;
  bool _loaded = false;

  final _findingsCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _assetCtrl = TextEditingController();
  final _woCtrl = TextEditingController();
  final _assetQueryCtrl = TextEditingController();

  List<String> _floors = [];
  List<String> _assets = [];
  String? _floorSel;
  String? _assetSel;
  final List<String> _photos = [];
  bool get _woValid {
    final v = _woCtrl.text.trim();
    if (v.length != 4) return false;
    return int.tryParse(v) != null;
  }
  bool get _canClose =>
      !_e.isClosed && _floorSel != null && _assetSel != null && _woValid && _photos.length >= 3;

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

  @override
  void initState() {
    super.initState();
    _e = PmStatusService.entryFor(
      date: widget.date,
      sys: widget.sys,
      item: widget.item,
      desc: widget.desc,
      sub: widget.sub,
      freq: widget.freq,
      markers: widget.markers,
    );
    _findingsCtrl.text = _e.findings;
    _remarkCtrl.text = _e.remark;
    _assetCtrl.text = _e.asset;
    _woCtrl.text = _e.woNo;
    if (_e.photos.isNotEmpty) _photos.addAll(_e.photos);
    _floorSel = _e.floor.isEmpty ? null : _floorLabel(_e.floor);
    _assetSel = _e.asset.isEmpty ? null : _e.asset;
    _load();
  }

  @override
  void dispose() {
    _findingsCtrl.dispose();
    _remarkCtrl.dispose();
    _assetCtrl.dispose();
    _assetQueryCtrl.dispose();
    _woCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final techId = widget.techId;
    String techName = widget.techName;
    if (techName.isEmpty) {
      techName = prefs.getString('tech_name_$techId') ?? 'Technician $techId';
    }
    await PmStatusService.load();
    final cur = PmStatusService.activeEntries().where((e) => e.id == _e.id).firstOrNull;
    if (cur != null && cur.status != 'open') {
      _e = cur;
      if (_e.photos.isNotEmpty) _photos
        ..clear()
        ..addAll(_e.photos);
    }
    await _loadAssets();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _loadAssets() async {
    try {
      final data = await RepoService.readFile('me_assets.json');
      if (data is Map<String, dynamic>) {
        final floors = <String>[];
        final assets = <String>{};
        data.forEach((floorKey, list) {
          if (list is! List) return;
          floors.add(floorKey);
          for (final a in list) {
            final map = a as Map;
            final system = (map['system'] as String? ?? '').trim();
            final type = (map['type'] as String? ?? '').trim();
            final qty = (map['qty'] as num?)?.toInt() ?? 0;
            if (system.contains(_e.sysCode)) {
              for (var i = 1; i <= qty.clamp(1, 99); i++) {
                assets.add(qty > 1 ? '$type-$i' : type);
              }
            }
          }
        });
        floors.sort((a, b) => _floorRank(a).compareTo(_floorRank(b)));
        final reversed = floors.reversed.toList();
        final assetList = assets.toList()..sort();
        if (mounted) {
          setState(() {
            _floors = reversed.map(_floorLabel).toList();
            _assets = assetList;
            if (_floorSel == null && floors.isNotEmpty) _floorSel = null;
          });
        }
      }
    } catch (e) {
      debugPrint('loadAssets error: $e');
    }
  }

  /// me_assets.json floor key → real building floor label:
  /// LB2→B2, LB1→B1, LP1→P, LM→M, L37→37, …
  static String _floorLabel(String key) {
    switch (key) {
      case 'LB2': return 'B2';
      case 'LB1': return 'B1';
      case 'LP1': return 'P';
      case 'LM': return 'M';
      case 'LG': return 'G';
      default:
        return key.startsWith('L') && key.length > 1 ? key.substring(1) : key;
    }
  }

  /// Bottom → top building order: B2, B1, P, M, 1 … 37.
  static int _compare(String a, String b) => _floorRank(a).compareTo(_floorRank(b));

  void _openAssetDropdown() {
    final eng = LanguageProvider.isEnglish(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171A21)
          : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = _assetQueryCtrl.text;
            final matches = query.trim().isEmpty
                ? _assets
                : _assets
                    .where((a) => a.toLowerCase().contains(query.trim().toLowerCase()))
                    .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Text(eng ? 'Select Asset' : 'Pilih Aset',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _assetQueryCtrl,
                      autofocus: true,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: eng ? 'Search asset...' : 'Cari aset...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _assetQueryCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _assetQueryCtrl.clear();
                                  setSheetState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF262B33)
                            : const Color(0xFFF5F7F6),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: matches.isEmpty
                        ? Center(
                            child: Text(
                                eng
                                    ? 'No asset matches'
                                    : 'Tiada aset sepadan',
                                style: const TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: matches.length,
                            itemBuilder: (_, i) {
                              final a = matches[i];
                              final selected = a == _assetSel;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _assetSel = a;
                                    _assetCtrl.text = a;
                                  });
                                  _assetQueryCtrl.clear();
                                  Navigator.of(ctx).pop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 11),
                                  color: selected
                                      ? const Color(0xFF0D7377)
                                          .withValues(alpha: 0.12)
                                      : null,
                                  child: Row(
                                    children: [
                                      Icon(
                                          selected
                                              ? Icons.check_circle
                                              : Icons.build_rounded,
                                          size: 16,
                                          color: selected
                                              ? const Color(0xFF0D7377)
                                              : Colors.grey.shade500),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(a,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static int _floorRank(String key) {
    switch (key) {
      case 'LB2': return 0;
      case 'LB1': return 1;
      case 'LP1': return 2;
      case 'LM': return 3;
      case 'LG': return 4;
    }
    final n = int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), ''));
    return 10 + (n ?? 999);
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
      setState(() => _photos.add(base64Encode(bytes)));
    }
  }

  Future<void> _attend() async {
    setState(() => _saving = true);
    final ok = await PmStatusService.attend(_e, widget.techId, widget.techName);
    if (ok) {
      final cur = PmStatusService.entries.where((e) => e.id == _e.id).firstOrNull;
      if (cur != null) _e = cur;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Task taken ✅ — now select asset & floor'
          : 'Failed to save — check internet & retry${_errHint()}'),
    ));
  }

  String _errHint() {
    final e = RepoService.lastHttpError;
    return e.isEmpty ? '' : '\n($e)';
  }

  Future<void> _close() async {
    if (_floorSel == null || _assetSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih lantai & aset dahulu (floor & asset)')));
      return;
    }
    if (!_woValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('WO No perlu 4 digit terakhir nombor kerja (last 4 digits)')));
      return;
    }
    if (_photos.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Perlu sekurang-kurangnya 3 gambar (minimum 3 photos)')));
      return;
    }
    setState(() => _saving = true);
    final eng = LanguageProvider.isEnglish(context);
    final closing = eng ? 'Closing PM…' : 'Menutup PM…';
    // Blocking loading overlay — darkens the screen and prevents any
    // interaction until the close operation finishes.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: Colors.white,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(strokeWidth: 3),
                  const SizedBox(height: 14),
                  Text(closing,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    bool ok = false;
    try {
      ok = await PmStatusService.close(
        _e,
        floor: _floorSel!,
        asset: _assetSel!,
        woNo: _woCtrl.text.trim(),
        findings: _findingsCtrl.text.trim(),
        remark: _remarkCtrl.text.trim(),
        photos: _photos,
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'PM close ✅' : 'FAILED to close PM — retry'),
    ));
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(title: Text(eng ? 'PPM Task' : 'Tugasan PPM')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(eng),
    );
  }

  Widget _buildBody(bool eng) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _e.isClosed
        ? const Color(0xFF16A34A)
        : _e.isInProgress
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    final statusLabel = _e.isClosed
        ? (eng ? 'CLOSED' : 'SELESAI')
        : _e.isInProgress
            ? (eng ? 'IN PROGRESS' : 'SEDANG DIJALANKAN')
            : (eng ? 'OPEN' : 'TERBUKA');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ================= TASK INFO CARD =================
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_e.isClosed
                            ? Icons.check_circle_rounded
                            : _e.isInProgress
                                ? Icons.timelapse_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(statusLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(_e.date,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _e.item.isEmpty
                    ? _e.desc
                    : '${_e.item} · ${_e.desc}',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 6),
              Text(_e.sub.isEmpty ? _e.sys : '${_e.sys} — ${_e.sub}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  ..._e.markers.map((m) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _markerColors[m] ?? Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(m,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_e.freq,
                        style: TextStyle(
                            fontSize: 9, color: Colors.grey.shade600)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ================= WORKFLOW / FORM CARD =================
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D2227) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_e.isInProgress || _e.isClosed) ...[
                // ---- asset & floor dropdowns ----
                Text(eng ? 'Asset Information' : 'Maklumat Aset',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _floorSel,
                  decoration: InputDecoration(
                    labelText: eng ? 'Floor' : 'Lantai (Aras)',
                    prefixIcon: const Icon(Icons.stairs_rounded),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF262B33) : const Color(0xFFF5F7F6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: _floors.map((f) =>
                      DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: _e.isClosed
                      ? null
                      : (v) => setState(() => _floorSel = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _assetCtrl,
                  readOnly: true,
                  onTap: _e.isClosed ? null : _openAssetDropdown,
                  decoration: InputDecoration(
                    labelText: eng ? 'Asset' : 'Aset',
                    hintText: eng ? 'Tap to pick asset...' : 'Tekan untuk pilih aset...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _e.isClosed
                        ? (_assetSel == null
                            ? null
                            : const Icon(Icons.check_circle,
                                color: Colors.green, size: 18))
                        : const Icon(Icons.arrow_drop_down_rounded),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF232B33) : const Color(0xFFF5F6F6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _woCtrl,
                  readOnly: _e.isClosed,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: eng ? 'WO No. (last 4 digits)' : 'No. WO (4 digit terakhir)',
                    hintText: eng ? 'e.g. 1234' : 'cth: 1234',
                    prefixIcon: const Icon(Icons.confirmation_number_rounded),
                    suffixIcon: _woValid
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                        : null,
                    counterText: '',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF232B33) : const Color(0xFFF5F6F6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                if (_e.isClosed) ...[
                  _infoRow(Icons.person_rounded,
                      eng ? 'Done by' : 'Dilaksanakan oleh', _e.techName),
                  _infoRow(Icons.schedule_rounded,
                      eng ? 'Started' : 'Mula', _fmt(_e.startedAt)),
                  _infoRow(Icons.check_circle_rounded,
                      eng ? 'Closed' : 'Ditutup', _fmt(_e.closedAt)),
                  const SizedBox(height: 10),
                  if (_e.findings.isNotEmpty) _infoRow(
                      Icons.search_rounded, eng ? 'Findings' : 'Penemuan', _e.findings),
                  if (_e.remark.isNotEmpty) _infoRow(
                      Icons.note_alt_rounded, eng ? 'Remark' : 'Nota', _e.remark),
                ],
              ],

              // ---- Actions ----
              const SizedBox(height: 14),
              if (_e.status == 'open')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _attend,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login_rounded),
                    label: Text(eng ? 'Attend · Take this task' : 'Attend · Ambil tugas ini',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7377),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

              if (_e.isInProgress)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    eng
                        ? '⚠ Complete all mandatory fields & add photos, then tap Close PM below.'
                        : '⚠ Lengkapkan semua medan wajib dan tambah gambar, kemudian tekan Tutup PM di bawah.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        height: 1.4),
                  ),
                ),
            ],
          ),
        ),

        // ================= PHOTO SECTION =================
        if (!_e.isClosed) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1D2227) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_library_rounded,
                        size: 18, color: Color(0xFF0D7377)),
                    const SizedBox(width: 6),
                    Text(eng ? 'Photos (min 3)' : 'Gambar (min 3)',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${_photos.length}/3+',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _photos.length >= 3
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEF4444))),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b64 in _photos)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              base64Decode(b64),
                              width: 82,
                              height: 82,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 3,
                            right: 3,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.remove(b64)),
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_photos.length < 8)
                      InkWell(
                        onTap: _pickPhoto,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF232B33)
                                : const Color(0xFFF5F6F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF0D7377)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_rounded,
                                  color: Color(0xFF0D7377), size: 24),
                              SizedBox(height: 3),
                              Text('Add',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF0D7377),
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (_photos.isNotEmpty && _photos.length < 3) ...[
                  const SizedBox(height: 8),
                  Text('${3 - _photos.length} more photo(s) needed',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade700)),
                ],
              ],
            ),
          ),
        ],

        // ===== FINDINGS / REMARK =====
        if (_e.isInProgress) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1D2227) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eng ? 'Findings (optional)' : 'Penemuan (pilihan)',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _findingsCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: eng
                        ? 'Any finding found during PM...'
                        : 'Sebarang penemuan semasa PM...',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF232B33)
                        : const Color(0xFFF5F6F6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Text(eng ? 'Remark / Suggestion (optional)' : 'Nota / Cadangan (pilihan)',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _remarkCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: eng
                        ? 'Remark or suggestion for admin'
                        : 'Nota atau cadangan untuk admin',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF232B33)
                        : const Color(0xFFF5F6F6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 18),

                // ---- Close PM (bottom, after all details) ----
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving || !_canClose ? null : _close,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                        _canClose
                            ? (eng ? 'Close PM' : 'Tutup PM')
                            : (eng
                                ? 'Close PM — fill mandatory fields + 3 photos'
                                : 'Tutup PM — lengkapkan wajib + 3 gambar'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _canClose
                          ? const Color(0xFF16A34A)
                          : Colors.grey.shade400,
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Color markerColor(String m) => _markerColors[m] ?? Colors.grey.shade500;

  String _fmt(String iso) {
    if (iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String p(int v) => v.toString().padLeft(2, '0');
    final date = '${p(d.day)}/${p(d.month)}/${d.year}';
    final time = '${p(d.hour)}:${p(d.minute)}';
    return '$date $time';
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D7377)),
          const SizedBox(width: 8),
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}