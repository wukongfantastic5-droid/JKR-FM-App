import 'package:flutter/material.dart';
import '../data/complaint_data.dart';
import '../screens/engineering_demo_screen.dart' show assetToMainCat;
import '../services/complaint_service.dart';
import '../services/repo_service.dart';

/// Lets the admin manually pin a complaint ticket to the real affected asset
/// on the ticket's floor (e.g. OTHER MECHANICAL -> BLIND SPOT MIRROR 1).
/// Asset list comes from me_assets_grouped.json on GitHub.
Future<void> showPinAssetSheet(BuildContext ctx, ComplaintTicket t, bool eng) async {
  final data = await RepoService.readFile('me_assets_grouped.json');
  if (data is! Map<String, dynamic> || data['L${t.floor}'] is! List) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(eng ? 'No asset data for this floor' : 'Tiada data aset untuk aras ini'),
      backgroundColor: Colors.orange.shade800,
    ));
    return;
  }
  final entries = data['L${t.floor}'] as List;
  final items = <({String cat, String inst})>[];
  for (final e in entries) {
    final type = (e as Map<String, dynamic>)['type'] as String;
    final cat = assetToMainCat[type] ?? 'OTHER MECHANICAL';
    final qty = e['qty'] as int;
    final itemsList = e['items'] as List?;
    if (itemsList != null) {
      for (final n in itemsList) {
        items.add((cat: cat, inst: n as String));
      }
    } else if (qty > 1) {
      for (var i = 1; i <= qty; i++) {
        items.add((cat: cat, inst: '$type $i'));
      }
    } else {
      items.add((cat: cat, inst: type));
    }
  }
  final seen = <String>{};
  final uniq = <({String cat, String inst})>[];
  for (final it in items) {
    final k = it.inst.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (k.isNotEmpty && seen.add(k)) uniq.add(it);
  }
  uniq.sort((a, b) => a.cat == b.cat ? a.inst.compareTo(b.inst) : a.cat.compareTo(b.cat));
  if (!ctx.mounted) return;
  String query = '';
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) {
        List<({String cat, String inst})> filtered() {
          final q = query.trim().toLowerCase();
          if (q.isEmpty) return uniq;
          return uniq.where((it) =>
              it.inst.toLowerCase().contains(q) || it.cat.toLowerCase().contains(q)).toList();
        }
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(margin: const EdgeInsets.only(bottom: 10), width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                      Text(eng ? 'Pin ticket #${t.seqId} to asset' : 'Semat tiket #${t.seqId} ke aset',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: eng ? 'Search asset…' : 'Cari aset…',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (v) => setSheet(() => query = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    children: [
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.autorenew_rounded, color: Colors.grey),
                        title: Text(eng ? 'Auto-match (remove manual pin)' : 'Padanan auto (buang sematan)',
                          style: const TextStyle(fontSize: 13)),
                        onTap: () async {
                          final ok = await ComplaintService.update(t.id, clearAssignedAsset: true);
                          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(ok
                                ? (eng ? 'Pin cleared' : 'Sematan dibuang')
                                : (eng ? 'Failed — check network' : 'Gagal — periksa rangkaian')),
                            backgroundColor: ok ? const Color(0xFF0D7377) : const Color(0xFFEF4444),
                          ));
                        },
                      ),
                      const Divider(height: 4),
                      ...filtered().map((it) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.push_pin_outlined, color: Color(0xFF0D7377)),
                        title: Text(it.inst, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(it.cat, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        onTap: () async {
                          final ok = await ComplaintService.update(t.id, assignedAsset: it.inst);
                          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(ok
                                ? '${eng ? "Pinned to" : "Disemat ke"} ${it.inst}'
                                : (eng ? 'Failed — check network' : 'Gagal — periksa rangkaian')),
                            backgroundColor: ok ? const Color(0xFF0D7377) : const Color(0xFFEF4444),
                          ));
                        },
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
