import 'dart:async';
import 'package:flutter/material.dart';
import '../localization.dart';
import '../providers/theme_provider.dart';
import '../services/repo_service.dart';
import '../data/asset_floors.dart';
import 'top_view_screen.dart';

class BuildingViewScreen extends StatefulWidget {
  const BuildingViewScreen({super.key});

  @override
  State<BuildingViewScreen> createState() => _BuildingViewScreenState();
}

class _BuildingViewScreenState extends State<BuildingViewScreen> {
  int? _selectedFloorIndex;
  List<FloorInfo> _floors = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Real-time: refresh asset data while this screen is visible.
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final byFloor = <String, List<AssetEntry>>{};
    try {
      final data = await RepoService.readFile('me_assets.json');
      if (data is Map<String, dynamic>) {
        for (final entry in data.entries) {
          final list = (entry.value as List).cast<Map<String, dynamic>>();
          byFloor[entry.key] = list.map((e) => AssetEntry(
            system: e['system'] as String? ?? '',
            type: e['type'] as String,
            qty: e['qty'] as int,
          )).toList();
        }
      }
    } catch (_) {}

    final next = _buildFullFloorList(byFloor);
    if (!mounted) return;
    setState(() {
      _floors = next;
      _loading = false;
    });
  }

  List<FloorInfo> _buildFullFloorList(Map<String, List<AssetEntry>> byFloor) {
    return [
      for (final key in assetFloorOrder)
        _makeFloor(key, byFloor[key] ?? const []),
    ];
  }

  FloorInfo _makeFloor(String key, List<AssetEntry> entries) {
    var qty = 0;
    final systems = <String>{};
    for (final e in entries) {
      qty += e.qty;
      if (e.system.isNotEmpty) systems.add(e.system);
    }
    return FloorInfo(floor: key, assetQty: qty, systemCount: systems.length);
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = ThemeProvider.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Bangunan JKR (41 Level)' : 'Bangunan JKR (41 Aras)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _floors.isEmpty
          ? Center(child: Text(eng ? 'No floor data' : 'Tiada data aras'))
          : Column(
              children: [
                _buildLegend(eng, isDark),
                Expanded(child: _buildTower(eng, isDark)),
              ],
            ),
    );
  }

  Widget _buildLegend(bool eng, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFB8D5D6), Color(0xFF0D7377)],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              eng
                  ? 'Ketik satu aras untuk lihat asetnya'
                  : 'Tap a floor to view its assets',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _floorH = 32;

  Widget _buildTower(bool eng, bool isDark) {
    return SingleChildScrollView(
      child: GestureDetector(
        onTapDown: (details) {
          final y = details.localPosition.dy;
          final idx = (y / _floorH).floor();
          if (idx >= 0 && idx < _floors.length) {
            setState(() => _selectedFloorIndex = idx);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TopViewScreen(floorKey: _floors[idx].floor),
              ),
            ).then((_) => _load(quiet: true));
          }
        },
        child: RepaintBoundary(
          child: SizedBox(
            height: _floors.length * _floorH,
            child: CustomPaint(
              size: Size(double.infinity, _floors.length * _floorH),
              painter: _TowerPainter(
                floors: _floors,
                selectedIdx: _selectedFloorIndex,
                isDark: isDark,
                floorH: _floorH,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AssetEntry {
  final String system;
  final String type;
  final int qty;

  const AssetEntry({this.system = '', required this.type, required this.qty});
}

class FloorInfo {
  final String floor;
  final int assetQty;
  final int systemCount;

  FloorInfo({required this.floor, required this.assetQty, required this.systemCount});
}

class _TowerPainter extends CustomPainter {
  final List<FloorInfo> floors;
  final int? selectedIdx;
  final bool isDark;
  final double floorH;

  _TowerPainter({
    required this.floors,
    required this.selectedIdx,
    required this.isDark,
    required this.floorH,
  });

  // Cached paints to avoid recreateShader per frame
  static final _skyLight = Paint()..shader = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFFB8D8F0), Color(0xFFE8F4FD)],
  ).createShader(Rect.largest);

  static final _skyDark = Paint()..shader = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
  ).createShader(Rect.largest);

  static final _groundPaint = Paint()..shader = LinearGradient(
    colors: [Color(0xFF2EA87A), Color(0xFF1B8A5C)],
  ).createShader(Rect.largest);

  static final Map<String, Paint> _bandPaintCache = {};

  Paint _getBandPaint(Color base) {
    final key = base.toARGB32().toRadixString(16);
    if (_bandPaintCache.containsKey(key)) return _bandPaintCache[key]!;
    final p = Paint()..shader = LinearGradient(
      begin: Alignment.centerLeft, end: Alignment.centerRight,
      colors: [
        base.withValues(alpha: 0.75),
        base.withValues(alpha: 0.45),
        base.withValues(alpha: 0.65),
        base.withValues(alpha: 0.9),
      ],
      stops: [0.0, 0.25, 0.65, 1.0],
    ).createShader(Rect.largest);
    _bandPaintCache[key] = p;
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final buildingW = w * 0.7;
    final offsetX = (w - buildingW) / 2;

    // Sky
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, size.height),
      isDark ? _skyDark : _skyLight,
    );

    var maxQty = 0;
    for (final f in floors) {
      if (f.assetQty > maxQty) maxQty = f.assetQty;
    }
    if (maxQty == 0) maxQty = 1;

    for (int i = 0; i < floors.length; i++) {
      final info = floors[i];
      final y = i * floorH;
      final rect = Rect.fromLTWH(offsetX, y, buildingW, floorH - 1);

      final Color base;
      if (info.assetQty == 0) {
        base = isDark ? const Color(0xFF3A4356) : const Color(0xFFC4CDD6);
      } else {
        final f = (info.assetQty / maxQty).clamp(0.15, 1.0);
        base = Color.lerp(const Color(0xFF7FB3B6), const Color(0xFF0D7377), f)!;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        _getBandPaint(base),
      );

      // Selected highlight
      if (i == selectedIdx) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2,
        );
      }

      // Floor label inside the band: core (bold) + zone hint (tiny)
      final core = assetFloorCore(info.floor);
      final zone = assetFloorZone(info.floor);
      final coreTp = TextPainter(
        text: TextSpan(
          text: core,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final zoneTp = TextPainter(
        text: TextSpan(
          text: zone,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 7.5,
            fontWeight: FontWeight.w500,
            overflow: TextOverflow.ellipsis,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: buildingW * 0.55);
      final labelH = coreTp.height + zoneTp.height;
      coreTp.paint(
        canvas,
        Offset(
          offsetX + (buildingW - coreTp.width) / 2,
          y + (floorH - labelH) / 2 - 1,
        ),
      );
      zoneTp.paint(
        canvas,
        Offset(
          offsetX + (buildingW - zoneTp.width) / 2,
          y + (floorH - labelH) / 2 + coreTp.height - 1,
        ),
      );

      // Asset quantity chip on the right edge of the band.
      if (info.assetQty > 0) {
        final qtyTp = TextPainter(
          text: TextSpan(
            text: '${info.assetQty}',
            style: TextStyle(
              color: const Color(0xFF0D7377),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final chipW = qtyTp.width + 12;
        final chipH = 16.0;
        final chipX = offsetX + buildingW - chipW - 5;
        final chipY = y + (floorH - chipH) / 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(chipX, chipY, chipW, chipH),
            const Radius.circular(8),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
        qtyTp.paint(canvas, Offset(chipX + 6, chipY + (chipH - qtyTp.height) / 2));
      }
    }

    // Building outline
    canvas.drawRect(
      Rect.fromLTWH(offsetX, 0, buildingW, floors.length * floorH),
      Paint()..color = Colors.white.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // Ground line with greenery hint
    final groundY = floors.length * floorH;
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, 4),
      _groundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TowerPainter old) =>
    old.floors != floors || old.selectedIdx != selectedIdx || old.isDark != isDark;
}