import 'dart:convert';
import 'dart:ui' show ImageByteFormat;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:qr_flutter/qr_flutter.dart';
import '../localization.dart';
import '../services/repo_service.dart';
import '../services/doc_deliver.dart';
import '../widgets/http_error_banner.dart';
import '../services/excel_service.dart';
import 'qr_scan_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  Map<String, List<_MeEntry>> _allData = {};
  bool _loading = true;
  String? _error;

  final _searchCtrl = TextEditingController();
  String _search = '';
  String _floorFilter = '';
  String _typeFilter = '';

  static const _floorOrder = [
    'L37','L36','L35','L34','L33','L32','L31','L30',
    'L29','L28','L27','L26','L25','L24','L23','L22','L21','L20',
    'L19','L18','L17','L16','L15','L14','L13','L12','L11','L10',
    'L9','L8','L7','L6','L5','L4','L3','L2','L1',
    'LP1','LM','LB1','LB2',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await RepoService.readFile('me_assets.json');
      if (data is Map<String, dynamic>) {
        final parsed = <String, List<_MeEntry>>{};
        for (final entry in data.entries) {
          final floor = entry.key;
          final list = (entry.value as List).cast<Map<String, dynamic>>();
          parsed[floor] = list.map((e) => _MeEntry(
            system: e['system'] as String? ?? '',
            type: e['type'] as String,
            qty: e['qty'] as int,
          )).toList();
        }
        if (mounted) setState(() { _allData = parsed; _loading = false; _error = null; });
      } else {
        if (mounted) setState(() { _error = 'Invalid data format'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Set<String> get _allTypes {
    final types = <String>{};
    for (final list in _allData.values) {
      for (final e in list) { types.add(e.type); }
    }
    return types;
  }

  List<MapEntry<String, List<_MeEntry>>> get _sortedFloors {
    final floors = _allData.entries.toList()
      ..sort((a, b) {
        final ai = _floorOrder.indexOf(a.key);
        final bi = _floorOrder.indexOf(b.key);
        if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
        return a.key.compareTo(b.key);
      });

    if (_search.isEmpty && _typeFilter.isEmpty && _floorFilter.isEmpty) return floors;

    return floors.where((f) {
      if (_floorFilter.isNotEmpty && f.key != _floorFilter) return false;
      final items = f.value.where((e) {
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          if (!e.type.toLowerCase().contains(q)) return false;
        }
        if (_typeFilter.isNotEmpty && e.type != _typeFilter) return false;
        return true;
      }).toList();
      return items.isNotEmpty;
    }).toList();
  }

  int get _totalItems {
    int count = 0;
    for (final list in _allData.values) {
      for (final e in list) { count += e.qty; }
    }
    return count;
  }

  bool _exporting = false;

  Future<void> _openScanner(bool eng) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'QR scanner is available on the Android app'
            : 'Pengimbas QR hanya tersedia dalam aplikasi Android'),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }
    final r = await Navigator.of(context).push<QrScanResult>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (r == null || !mounted) return;
    setState(() {
      _floorFilter = r.floor.isEmpty ? _floorFilter : r.floor;
      _searchCtrl.text = r.type.isEmpty ? _searchCtrl.text : r.type;
      _search = _searchCtrl.text;
      _typeFilter = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(eng
          ? 'Scanned: ${r.type} (Floor ${r.floor}) — showing matches'
          : 'Diimbas: ${r.type} (Aras ${r.floor}) — memaparkan padanan'),
    ));
  }

  Future<void> _exportExcel(bool eng) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final now = DateTime.now();
      final fileDate = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final rows = <List<String>>[];
      for (final f in _sortedFloors) {
        for (final e in f.value) {
          rows.add([f.key, e.system, e.type, '${e.qty}']);
        }
      }
      final bytes = await ExcelService.build([
        ExcelSheet(
          name: 'Inventory',
          headers: const ['Aras', 'Sistem', 'Jenis (Type)', 'Kuantiti'],
          rows: rows,
        ),
      ]);
      final fileName = 'Inventory_$fileDate.xlsx';
      final local = await DocDeliver.saveLocal('Inventory', fileName, bytes);
      final ok = await RepoService.writeRawFile(
          'Reports/Inventory/$fileName', base64Encode(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (local.isNotEmpty
                ? (eng ? 'Saved: $local' : 'Disimpan: $local')
                : (eng
                    ? 'Saved in database (Reports/Inventory)'
                    : 'Disimpan dalam database (Reports/Inventory)'))
            : (eng ? 'Export ok but save failed' : 'Eksport berjaya tetapi simpan gagal')),
      ));
      if (ok) {
        await DocDeliver.offerOpen(
          context,
          repoPath: 'Reports/Inventory/$fileName',
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

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Asset Inventory' : 'Inventori Aset'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: eng ? 'Scan asset QR' : 'Imbas QR aset',
            onPressed: () => _openScanner(eng),
          ),
          if (!_loading && _error == null)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.table_chart_rounded),
              tooltip: eng ? 'Export to Excel' : 'Eksport ke Excel',
              onPressed: _exporting ? null : () => _exportExcel(eng),
            ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('$_totalItems', style: const TextStyle(fontWeight: FontWeight.w600)),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    onPressed: _load,
                  ),
                ],
              ),
            )
          : _buildContent(eng, isDark),
    );
  }

  Widget _buildContent(bool eng, bool isDark) {
    final sorted = _sortedFloors;
    return Column(
      children: [
        const HttpErrorBanner(),
        _buildSearch(eng),
        _buildFilters(eng),
        _buildSummary(eng, sorted),
        Expanded(child: _buildList(sorted, eng, isDark)),
      ],
    );
  }

  Widget _buildSearch(bool eng) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: eng ? 'Search asset type...' : 'Cari jenis aset...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _search.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); },
              )
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }

  Widget _buildFilters(bool eng) {
    final types = _allTypes.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _filterChip(eng ? 'Floor' : 'Aras', _floorFilter, _floorOrder, (v) => setState(() => _floorFilter = v ?? '')),
          const SizedBox(width: 8),
          _filterChip(eng ? 'Type' : 'Jenis', _typeFilter, types, (v) => setState(() => _typeFilter = v ?? '')),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, String current, List<String> options, ValueSetter<String?> onSelected) {
    return FilterChip(
      label: Text(current.isEmpty ? label : current),
      selected: current.isNotEmpty,
      onSelected: (_) {
        if (current.isNotEmpty) {
          onSelected('');
        } else {
          showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(100, 200, 100, 200),
            items: options.map((o) => PopupMenuItem(value: o, child: Text(o))).toList(),
          ).then(onSelected);
        }
      },
    );
  }

  Widget _buildSummary(bool eng, List<MapEntry<String, List<_MeEntry>>> sorted) {
    final floorCount = sorted.length;
    final typeCount = _allTypes.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.bar_chart_rounded, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(eng
            ? '$floorCount floors, $typeCount asset types'
            : '$floorCount aras, $typeCount jenis aset',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const Spacer(),
          if (_search.isNotEmpty)
            Text(_search, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildList(List<MapEntry<String, List<_MeEntry>>> sorted, bool eng, bool isDark) {
    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(eng ? 'No matches' : 'Tiada padanan', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final entry = sorted[i];
        final floor = entry.key;
        final items = entry.value;
        return _FloorCard(floor: floor, items: items, eng: eng, isDark: isDark);
      },
    );
  }
}

class _MeEntry {
  final String system;
  final String type;
  final int qty;
  const _MeEntry({this.system = '', required this.type, required this.qty});
}

class _FloorCard extends StatelessWidget {
  final String floor;
  final List<_MeEntry> items;
  final bool eng;
  final bool isDark;

  const _FloorCard({
    required this.floor,
    required this.items,
    required this.eng,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final floorNum = floor.replaceAll('L', '');
    final total = items.fold(0, (s, e) => s + e.qty);
    items.sort((a, b) => b.qty.compareTo(a.qty));

    // group by system, preserving legend order 1.0..9.0
    const sysOrder = [
      '1.0', '2.0', '3.0', '4.0', '5.0', '6.0', '7.0', '8.0', '9.0',
    ];
    int sysRank(String system) {
      final idx = sysOrder.indexWhere((s) => system.startsWith(s));
      return idx < 0 ? 99 : idx;
    }
    final groups = <String, List<_MeEntry>>{};
    for (final e in items) {
      final key = e.system.isEmpty ? 'Other' : e.system;
      groups.putIfAbsent(key, () => []).add(e);
    }
    final groupKeys = groups.keys.toList()
      ..sort((a, b) {
        final ai = sysRank(a); final bi = sysRank(b);
        if (ai != bi) return ai.compareTo(bi);
        return a.compareTo(b);
      });

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(floorNum,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(eng ? 'Floor $floorNum' : 'Aras $floorNum',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$total ${eng ? 'items' : 'item'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                )),
            ),
          ],
        ),
        children: [
          for (final key in groupKeys) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(key,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            ...groups[key]!.map((e) => _assetRow(e, context)),
          ],
        ],
      ),
    );
  }

  Widget _assetRow(_MeEntry e, BuildContext context) {
    final icon = _iconForType(e.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _colorForType(e.type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(e.type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
            tooltip: eng ? 'QR sticker' : 'Label QR',
            onPressed: () => _showQr(context, floor, e),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _colorForType(e.type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${e.qty}', style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _colorForType(e.type),
            )),
          ),
          const SizedBox(width: 4),
          Text('unit${e.qty > 1 ? 's' : ''}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Color _colorForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('chiller')) return const Color(0xFF0891B2);
    if (t.contains('cooling tower')) return const Color(0xFF0EA5E9);
    if (t.contains('ahu') || t.contains('fcu') || t.contains('vav') || t.contains('pac') || t.contains('fan')) return const Color(0xFF16A34A);
    if (t.contains('pump')) return const Color(0xFF2563EB);
    if (t.contains('db') || t.contains('panel') || t.contains('switch') || t.contains('msb') || t.contains('ssb')) return const Color(0xFF9333EA);
    if (t.contains('tank') || t.contains('water') || t.contains('rain')) return const Color(0xFF0D9488);
    if (t.contains('lift')) return const Color(0xFFCA8A04);
    if (t.contains('cctv') || t.contains('camera') || t.contains('system') || t.contains('display') || t.contains('audio') || t.contains('sound') || t.contains('conference')) return const Color(0xFF7C3AED);
    if (t.contains('light') || t.contains('luminaries')) return const Color(0xFFD97706);
    if (t.contains('sprinkler') || t.contains('hose') || t.contains('fire') || t.contains('wet riser')) return Color(0xFFDC2626);
    if (t.contains('genset') || t.contains('generator')) return Color(0xFFB91C1C);
    if (t.contains('solar') || t.contains('pv') || t.contains('photovoltaic')) return Color(0xFFCA8A04);
    if (t.contains('cable') || t.contains('busduct') || t.contains('bust duct')) return Color(0xFF4F46E5);
    if (t.contains('metering')) return Color(0xFF0891B2);
    return const Color(0xFF64748B);
  }

  Future<void> _showQr(BuildContext context, String floor, _MeEntry e) async {
    final payload = 'JKR FM ASSET\nFloor: $floor\nSystem: ${e.system}\n'
        'Type: ${e.type}\nQty: ${e.qty}';
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.type,
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('${floor} · ${e.system} · ${e.qty}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: QrImageView(
                  data: payload,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D7377)),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(eng ? 'Save QR PNG' : 'Simpan QR PNG'),
                onPressed: () async {
                  final byteData = await QrPainter(
                    data: payload,
                    version: QrVersions.auto,
                    gapless: true,
                  ).toImageData(600, format: ImageByteFormat.png);
                  if (byteData == null || !ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  final safe = e.type.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
                  final fileName = 'QR_${safe}_${floor.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.png';
                  final bytes = byteData.buffer.asUint8List();
                  final local = await DocDeliver.saveLocal('QR Stickers', fileName, bytes);
                  final ok = await RepoService.writeRawFile(
                      'Reports/QR/$fileName', base64Encode(bytes));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                        ? (local.isNotEmpty
                            ? (eng ? 'QR saved: $local' : 'QR disimpan: $local')
                            : (eng
                                ? 'QR saved in database (Reports/QR)'
                                : 'QR disimpan dalam database (Reports/QR)'))
                        : (eng ? 'QR ok but save failed' : 'QR berjaya tetapi simpan gagal')),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('chiller') || t.contains('ac unit') || t.contains('acsu')) return Icons.ac_unit_rounded;
    if (t.contains('cooling tower')) return Icons.water_drop_rounded;
    if (t.contains('ahu') || t.contains('fcu') || t.contains('vav') || t.contains('pac') || t.contains('fan')) return Icons.air_rounded;
    if (t.contains('pump')) return Icons.water_drop_rounded;
    if (t.contains('db') || t.contains('panel') || t.contains('switch') || t.contains('msb') || t.contains('ssb')) return Icons.electrical_services_rounded;
    if (t.contains('tank') || t.contains('water storage') || t.contains('rain') || t.contains('grey')) return Icons.water_drop_rounded;
    if (t.contains('lift')) return Icons.elevator_rounded;
    if (t.contains('cctv') || t.contains('camera')) return Icons.videocam_rounded;
    if (t.contains('display') || t.contains('audio') || t.contains('video') || t.contains('sound') || t.contains('conference') || t.contains('visual') || t.contains('info channel') || t.contains('pa system') || t.contains('pabx') || t.contains('smatv')) return Icons.speaker_rounded;
    if (t.contains('light') || t.contains('luminaries')) return Icons.light_rounded;
    if (t.contains('sprinkler') || t.contains('hose') || t.contains('fire') || t.contains('wet riser') || t.contains('extinguisher')) return Icons.fire_extinguisher_rounded;
    if (t.contains('genset') || t.contains('generator')) return Icons.power_rounded;
    if (t.contains('solar') || t.contains('pv') || t.contains('photovoltaic')) return Icons.solar_power_rounded;
    if (t.contains('cable') || t.contains('busduct') || t.contains('bust duct')) return Icons.cable_rounded;
    if (t.contains('metering')) return Icons.speed_rounded;
    if (t.contains('earthing')) return Icons.power_rounded;
    if (t.contains('boom gate')) return Icons.door_front_door_rounded;
    if (t.contains('panic button')) return Icons.notification_important_rounded;
    if (t.contains('water heater')) return Icons.water_drop_rounded;
    if (t.contains('pabx') || t.contains('telephone')) return Icons.phone_rounded;
    if (t.contains('battery')) return Icons.battery_full_rounded;
    if (t.contains('ups')) return Icons.battery_charging_full_rounded;
    if (t.contains('capacitor') || t.contains('cap bank')) return Icons.energy_savings_leaf_rounded;
    if (t.contains('socket') || t.contains('sso') || t.contains('switch')) return Icons.power_rounded;
    if (t.contains('roller shutter') || t.contains('shutter')) return Icons.curtains_rounded;
    if (t.contains('exhaust')) return Icons.air_rounded;
    if (t.contains('conditioner') || t.contains('air cond')) return Icons.ac_unit_rounded;
    if (t.contains('sump')) return Icons.water_drop_rounded;
    if (t.contains('motor')) return Icons.precision_manufacturing_rounded;
    if (t.contains('vrf')) return Icons.ac_unit_rounded;
    if (t.contains('vfd') || t.contains('vsd')) return Icons.speed_rounded;
    if (t.contains('gondola')) return Icons.construction_rounded;
    return Icons.inventory_2_rounded;
  }
}