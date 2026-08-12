import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/spare_part_data.dart';
import '../data/status_usage_data.dart';
import '../localization.dart';
import '../services/spare_part_service.dart';
import '../services/status_usage_service.dart';
import '../services/tool_service.dart';

/// Technician "Status Usage" tab: shows stock on hand (how many we have),
/// records who used a spare part / tool and how many, and lists the history.
class StatusUsageTab extends StatefulWidget {
  const StatusUsageTab({super.key, required this.techId});

  final String techId;

  @override
  State<StatusUsageTab> createState() => _StatusUsageTabState();
}

class _StatusUsageTabState extends State<StatusUsageTab> {
  String? _itemKey; // 'part|<id>' or 'tool|<id>'
  final _qtyCtrl = TextEditingController(text: '1');
  final _remarkCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _techName = '';

  @override
  void initState() {
    super.initState();
    _load();
    StatusUsageService.revision.addListener(_onRev);
    SparePartService.revision.addListener(_onRev);
    ToolService.revision.addListener(_onRev);
  }

  @override
  void dispose() {
    StatusUsageService.revision.removeListener(_onRev);
    SparePartService.revision.removeListener(_onRev);
    ToolService.revision.removeListener(_onRev);
    _qtyCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _onRev() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _techName =
        prefs.getString('tech_name_${widget.techId}') ?? widget.techId;
    await Future.wait([
      StatusUsageService.load(),
      SparePartService.load(),
      ToolService.load(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<SparePart> get _parts => SparePartService.entries;
  List<SparePart> get _tools => ToolService.entries;

  int get _totalPartsQty =>
      _parts.fold(0, (s, p) => s + (p.quantity < 0 ? 0 : p.quantity));
  int get _totalToolsQty =>
      _tools.fold(0, (s, t) => s + (t.quantity < 0 ? 0 : t.quantity));

  SparePart? _stockFor(String? itemKey) {
    if (itemKey == null || !itemKey.startsWith('part|')) return null;
    final part = _parts.where((p) => p.id == itemKey.substring(5)).firstOrNull;
    return part;
  }

  String _labelFor(String itemKey) {
    if (itemKey.startsWith('part|')) {
      final p = _parts.where((x) => x.id == itemKey.substring(5)).firstOrNull;
      return p?.name ?? itemKey.substring(5);
    }
    final t = _tools.where((x) => x.id == itemKey.substring(5)).firstOrNull;
    return t?.name ?? itemKey.substring(5);
  }

  Future<void> _saveRecord() async {
    final eng = LanguageProvider.isEnglish(context);
    final key = _itemKey;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (key == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'Pick an item and enter quantity ≥ 1'
            : 'Pilih item dan masukkan kuantiti ≥ 1'),
      ));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final rec = UsageRecord(
      id: 'u${now.millisecondsSinceEpoch}',
      type: key.startsWith('part|') ? 'part' : 'tool',
      itemId: key.split('|')[1],
      itemName: _labelFor(key),
      qtyUsed: qty,
      techId: widget.techId,
      techName: _techName,
      date: date,
      remark: _remarkCtrl.text.trim(),
    );
    final ok = await StatusUsageService.save(rec);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? (eng ? 'Usage recorded ✓' : 'Kegunaan direkod ✓')
                       : (eng ? 'Save failed — retry' : 'Gagal simpan — cuba lagi')),
    ));
    if (ok) {
      _qtyCtrl.text = '1';
      _remarkCtrl.clear();
      setState(() => _itemKey = null);
    }
  }

  Future<void> _removeRecord(UsageRecord r) async {
    final eng = LanguageProvider.isEnglish(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete this record?' : 'Padam rekod ini?'),
        content: Text(
            '${r.itemName} · ${r.qtyUsed} · ${r.techName} — ${r.date}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(eng ? 'CANCEL' : 'BATAL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (go != true) return;
    final ok = await StatusUsageService.remove(r.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? (eng ? 'Deleted ✓' : 'Dipadam ✓')
                       : (eng ? 'Delete failed — retry' : 'Gagal padam — cuba lagi')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final sorted = List<UsageRecord>.from(StatusUsageService.entries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _card(
          eng ? 'Record usage' : 'Rekod kegunaan',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _itemKey,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: eng ? 'Item used' : 'Item digunakan',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final p in _parts)
                    DropdownMenuItem(
                      value: 'part|${p.id}',
                      child: Text('${p.name} (${eng ? 'Part' : 'Alat Ganti'}, stok ${p.quantity})',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  for (final t in _tools)
                    DropdownMenuItem(
                      value: 'tool|${t.id}',
                      child: Text('${t.name} (${eng ? 'Tool' : 'Perkakas'}, stok ${t.quantity})',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _itemKey = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: eng ? 'Quantity used' : 'Kuantiti digunakan',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _remarkCtrl,
                decoration: InputDecoration(
                  labelText: eng ? 'Remark (e.g. asset / location)' : 'Catatan (cth. aset / lokasi)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A)),
                onPressed: _saving ? null : _saveRecord,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving
                    ? (eng ? 'Saving...' : 'Menyimpan...')
                    : (eng ? 'Save' : 'Simpan')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          eng ? "How many we have" : "Berapa banyak yang kita ada",
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('${_parts.length}', eng ? 'part items' : 'item alat ganti'),
              _chip('$_totalPartsQty', eng ? 'parts qty' : 'jumlah alat ganti'),
              _chip('${_tools.length}', eng ? 'tool items' : 'item perkakas'),
              _chip('$_totalToolsQty', eng ? 'tools qty' : 'jumlah perkakas'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          eng ? 'Usage history' : 'Sejarah kegunaan',
          sorted.isEmpty
              ? Text(eng ? '(no usage recorded yet)' : '(belum ada rekod kegunaan)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))
              : Column(
                  children: [
                    for (final r in sorted)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: r.type == 'part'
                              ? const Color(0xFF7B1FA2).withValues(alpha: .15)
                              : const Color(0xFF059669).withValues(alpha: .15),
                          child: Icon(
                            r.type == 'part'
                                ? Icons.build_rounded
                                : Icons.handyman_rounded,
                            size: 18,
                            color: r.type == 'part'
                                ? const Color(0xFF7B1FA2)
                                : const Color(0xFF059669),
                          ),
                        ),
                        title: Text(
                            '${r.itemName} × ${r.qtyUsed}',
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${r.techName} · ${r.date}'
                          '${r.remark.isNotEmpty ? ' · ${r.remark}' : ''}',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red, size: 20),
                          onPressed: () => _removeRecord(r),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _chip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D7377).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D7377)),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.withValues(alpha: .25))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}