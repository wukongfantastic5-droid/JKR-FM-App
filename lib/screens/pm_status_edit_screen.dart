import 'package:flutter/material.dart';
import 'dart:convert';
import '../localization.dart';
import '../providers/theme_provider.dart';
import '../data/pm_status_data.dart';
import '../services/pm_status_service.dart';

class PmStatusEditScreen extends StatefulWidget {
  final PmStatusEntry entry;
  const PmStatusEditScreen({super.key, required this.entry});

  @override
  State<PmStatusEditScreen> createState() => _PmStatusEditScreenState();
}

class _PmStatusEditScreenState extends State<PmStatusEditScreen> {
  late String _status;
  late final TextEditingController _techCtrl;
  late final TextEditingController _floorCtrl;
  late final TextEditingController _assetCtrl;
  late final TextEditingController _woCtrl;
  late final TextEditingController _findingsCtrl;
  late final TextEditingController _remarkCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _status = e.status;
    _techCtrl = TextEditingController(text: e.techName);
    _floorCtrl = TextEditingController(text: e.floor);
    _assetCtrl = TextEditingController(text: e.asset);
    _woCtrl = TextEditingController(text: e.woNo);
    _findingsCtrl = TextEditingController(text: e.findings);
    _remarkCtrl = TextEditingController(text: e.remark);
  }

  @override
  void dispose() {
    _techCtrl.dispose();
    _floorCtrl.dispose();
    _assetCtrl.dispose();
    _woCtrl.dispose();
    _findingsCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final e = widget.entry;
    e.status = _status;
    e.techName = _techCtrl.text.trim();
    e.floor = _floorCtrl.text.trim();
    e.asset = _assetCtrl.text.trim();
    e.woNo = _woCtrl.text.trim();
    e.findings = _findingsCtrl.text.trim();
    e.remark = _remarkCtrl.text.trim();
    if (_status == 'open') {
      e.techId = '';
      e.attendedAt = '';
      e.startedAt = '';
      e.closedAt = '';
    } else if (_status == 'closed' && e.closedAt.isEmpty) {
      e.closedAt = DateTime.now().toIso8601String();
    }
    final ok = await PmStatusService.updateEntry(e);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? (LanguageProvider.isEnglish(context) ? 'Saved' : 'Disimpan') : (LanguageProvider.isEnglish(context) ? 'Save failed' : 'Gagal menyimpan'))));
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete task?' : 'Padam tugasan?'),
        content: Text(eng
            ? 'This removes the PM task permanently.'
            : 'Ini akan membuang tugasan PM secara kekal.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Delete' : 'Padam'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _saving = true);
    final ok = await PmStatusService.removeEntry(widget.entry);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final e = widget.entry;
    final isDark = ThemeProvider.isDark(context);
    return Scaffold(
      appBar: AppBar(title: Text(eng ? 'Edit PM Task' : 'Edit Tugasan PM')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1D2227) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.sys, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                if (e.sub.isNotEmpty)
                  Text(e.sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(e.item.isEmpty ? e.desc : '${e.item}${e.desc.isNotEmpty ? ' · ${e.desc}' : ''}',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text('${e.date} · ${e.freq} · ${e.markers.join(",")}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: _dec(eng ? 'Status' : 'Status', Icons.flag_rounded, isDark),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
              DropdownMenuItem(value: 'closed', child: Text('Closed')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'open'),
          ),
          const SizedBox(height: 10),
          _clearableField(_techCtrl,
              label: eng ? 'Technician' : 'Teknisi', icon: Icons.person_rounded, isDark: isDark),
          const SizedBox(height: 10),
          _clearableField(_floorCtrl,
              label: eng ? 'Floor' : 'Aras', icon: Icons.stairs_rounded, isDark: isDark),
          const SizedBox(height: 10),
          _clearableField(_assetCtrl,
              label: eng ? 'Asset' : 'Aset', icon: Icons.build_rounded, isDark: isDark),
          const SizedBox(height: 10),
          _clearableField(_woCtrl,
              label: eng ? 'WO No. (last 4 digits)' : 'No. WO (4 digit terakhir)',
              icon: Icons.confirmation_number_rounded,
              isDark: isDark,
              keyboardType: TextInputType.number,
              maxLength: 4),
          const SizedBox(height: 10),
          _clearableField(_findingsCtrl,
              label: eng ? 'Findings' : 'Penemuan',
              icon: Icons.search_rounded,
              isDark: isDark,
              maxLines: 2),
          const SizedBox(height: 10),
          _clearableField(_remarkCtrl,
              label: eng ? 'Remark' : 'Nota',
              icon: Icons.note_alt_rounded,
              isDark: isDark,
              maxLines: 2),
          const SizedBox(height: 14),

          // ---- Photos taken by technician ----
          Row(
            children: [
              const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF0D7377)),
              const SizedBox(width: 6),
              Text(eng ? 'Photos (${widget.entry.photos.length})' : 'Gambar (${widget.entry.photos.length})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (widget.entry.photos.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => widget.entry.photos.clear()),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: Text(eng ? 'Remove all' : 'Buang semua',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.entry.photos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(eng ? 'No photos' : 'Tiada gambar',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b64 in List.of(widget.entry.photos))
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(base64Decode(b64),
                            width: 90, height: 90, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                width: 90, height: 90,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image_rounded))),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => widget.entry.photos.remove(b64)),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: Text(eng ? 'Save Changes' : 'Simpan Perubahan'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D7377),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_rounded, color: Color(0xFFDC2626)),
            label: Text(eng ? 'Delete Task' : 'Padam Tugasan',
                style: const TextStyle(color: Color(0xFFDC2626))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF262B33) : const Color(0xFFF5F7F6),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  /// Text field with an (x) button at the left of the row that clears the field.
  Widget _clearableField(TextEditingController ctrl,
      {required String label,
      required IconData icon,
      required bool isDark,
      TextInputType? keyboardType,
      int maxLines = 1,
      int? maxLength}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (ctrl.text.isNotEmpty)
          InkWell(
            onTap: () => setState(() => ctrl.clear()),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
            ),
          )
        else
          const SizedBox(width: 24),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            decoration: _dec(label, icon, isDark).copyWith(counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}