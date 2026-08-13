import 'package:flutter/material.dart';
import '../data/asset_floors.dart';
import '../data/asset_systems.dart';
import '../localization.dart';
import '../services/repo_service.dart';
import 'inventory_screen.dart';

class TopViewScreen extends StatefulWidget {
  final String floorKey;

  const TopViewScreen({super.key, required this.floorKey});

  @override
  State<TopViewScreen> createState() => _TopViewScreenState();
}

class _SectionState {
  final AssetSystem system;
  final List<_Entry> entries;
  int get qty {
    var s = 0;
    for (final e in entries) { s += e.qty; }
    return s;
  }

  _SectionState({required this.system, required this.entries});
}

class _Entry {
  final String type;
  final int qty;
  const _Entry({required this.type, required this.qty});
}

class _TopViewScreenState extends State<TopViewScreen> {
  bool _loading = true;
  List<_SectionState> _sections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sections = <_SectionState>[];

    try {
      final data = await RepoService.readFile('me_assets.json');
      if (data is Map<String, dynamic>) {
        final raw = (data[widget.floorKey] as List? ?? const [])
            .cast<Map<String, dynamic>>();

        final perSystem = <AssetSystem, List<_Entry>>{};
        for (final e in raw) {
          final sys = systemFor(e['system'] as String? ?? '');
          perSystem.putIfAbsent(sys, () => []).add(_Entry(
            type: e['type'] as String,
            qty: e['qty'] as int,
          ));
        }

        for (final s in assetSystems) {
          final entries = perSystem[s] ?? const <_Entry>[];
          if (entries.isNotEmpty) {
            sections.add(_SectionState(system: s, entries: entries));
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _sections = sections;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final core = assetFloorCore(widget.floorKey);
    final zone = assetFloorZone(widget.floorKey);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eng ? 'Floor $core · Top view' : 'Aras $core · Pandangan atas'),
            if (zone.isNotEmpty)
              Text(zone,
                style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.outline)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_list_rounded),
            tooltip: eng ? 'Full asset list' : 'Senarai aset penuh',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InventoryScreen(initialFloor: widget.floorKey)),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildBody(eng, isDark),
    );
  }

  Widget _buildBody(bool eng, bool isDark) {
    return Column(
      children: [
        _buildSlab(eng, isDark),
        Expanded(child: _buildSections(eng)),
      ],
    );
  }

  Widget _buildSlab(bool eng, bool isDark) {
    final present = _sections.where((s) => s.qty > 0).toList();
    final total = present.fold(0, (acc, s) => acc + s.qty);
    final core = assetFloorCore(widget.floorKey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          SizedBox(
            height: 230,
            width: double.infinity,
            child: CustomPaint(
              painter: _SlabPainter(
                segments: present.map((s) => (s.system, s.qty)).toList(),
                core: core,
                total: total,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            eng
              ? 'Top view — rounded building plan, one segment per system'
              : 'Pandangan atas — pelan bangunan bulat, satu segmen setiap sistem',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSections(bool eng) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _sections.length,
      itemBuilder: (ctx, i) => _sectionCard(_sections[i], eng, ctx),
    );
  }

  Widget _sectionCard(_SectionState s, bool eng, BuildContext context) {
    final has = s.qty > 0;
    final color = has ? s.system.color : s.system.color.withValues(alpha: 0.35);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        shape: const Border(),
        collapsedShape: const Border(),
        enabled: has,
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: has ? color.withValues(alpha: 0.14) : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(s.system.icon, size: 20, color: color),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.system.short,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: has ? null : Theme.of(context).colorScheme.outline,
              )),
            if (s.system.full.isNotEmpty)
              Text(s.system.full,
                style: TextStyle(
                  fontSize: 10,
                  color: has
                    ? Theme.of(context).colorScheme.outline
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
                )),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: has ? color.withValues(alpha: 0.14) : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: has
            ? Text('${s.qty}',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color))
            : Text(eng ? '0' : '0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
                )),
        ),
        children: !has
            ? [
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    eng
                      ? 'No assets recorded for this system on this floor.'
                      : 'Tiada aset direkodkan untuk sistem ini di aras ini.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ]
            : [
                for (final e in s.entries) _entryRow(e, color, context),
              ],
      ),
    );
  }

  Widget _entryRow(_Entry e, Color color, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(_iconForType(e.type), size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(e.type, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text('${e.qty}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('chiller') || t.contains('air cond') || t.contains('ac unit')) return Icons.ac_unit_rounded;
    if (t.contains('cooling tower') || t.contains('tank') || t.contains('water')) return Icons.water_drop_rounded;
    if (t.contains('ahu') || t.contains('fcu') || t.contains('vav') || t.contains('pac') || t.contains('fan') || t.contains('vrf') || t.contains('jet') || t.contains('vent')) return Icons.air_rounded;
    if (t.contains('pump')) return Icons.water_drop_rounded;
    if (t.contains('panel') || t.contains('switch') || t.contains('db') || t.contains('msb')) return Icons.electrical_services_rounded;
    if (t.contains('lift')) return Icons.elevator_rounded;
    if (t.contains('sprinkler') || t.contains('hose') || t.contains('fire') || t.contains('wet riser') || t.contains('extinguisher') || t.contains('hydrant')) return Icons.fire_extinguisher_rounded;
    if (t.contains('shutter') || t.contains('curtain')) return Icons.curtains_rounded;
    if (t.contains('sump') || t.contains('dryer')) return Icons.water_drop_rounded;
    if (t.contains('kitchen') || t.contains('lpg') || t.contains('hood')) return Icons.restaurant_rounded;
    if (t.contains('gondola')) return Icons.construction_rounded;
    if (t.contains('irrigation') || t.contains('grey') || t.contains('rain')) return Icons.water_drop_rounded;
    return Icons.inventory_2_rounded;
  }
}

class _SlabPainter extends CustomPainter {
  final List<(AssetSystem, int)> segments;
  final String core;
  final int total;
  final bool isDark;

  _SlabPainter({required this.segments, required this.core, required this.total, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 4;
    final ringW = radius * 0.55;
    final rect = Rect.fromCircle(center: c, radius: radius - ringW / 2);

    // Slab background
    final bg = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? const Color(0xFF2A3446) : const Color(0xFFE9F0F0);
    canvas.drawCircle(c, radius, bg);

    // Rounded building outline
    canvas.drawCircle(c, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = isDark ? const Color(0xFF4A5A72) : const Color(0xFF9FB8BA));

    if (total == 0 || segments.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Tiada aset',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      return;
    }

    // One ring segment per system, sized by asset share
    var start = -3.141592653589793 / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringW
      ..strokeCap = StrokeCap.butt;
    for (final (sys, qty) in segments) {
      final sweep = (qty / total) * 6.283185307179586;
      final gap = 0.03;
      stroke.color = sys.color;
      canvas.drawArc(rect, start + gap, sweep - gap * 2, false, stroke);
      start += sweep;
    }

    // Center label: floor core + total
    final coreTp = TextPainter(
      text: TextSpan(
        text: core,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : const Color(0xFF0D7377),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final qtyTp = TextPainter(
      text: TextSpan(
        text: '$total aset',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final blockH = coreTp.height + 4 + qtyTp.height;
    coreTp.paint(canvas, Offset(c.dx - coreTp.width / 2, c.dy - blockH / 2));
    qtyTp.paint(canvas, Offset(c.dx - qtyTp.width / 2, c.dy - blockH / 2 + coreTp.height + 4));
  }

  @override
  bool shouldRepaint(covariant _SlabPainter old) =>
    old.segments != segments || old.core != core || old.total != total || old.isDark != isDark;
}