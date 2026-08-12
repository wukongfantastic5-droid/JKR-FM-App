import 'dart:async';
import 'package:flutter/material.dart';
import '../localization.dart';
import '../providers/theme_provider.dart';
import '../services/repo_service.dart';
import '../services/complaint_service.dart';
import '../data/fca_data.dart';
import 'engineering_demo_screen.dart';

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
    // Real-time: refresh complaint statuses while this screen is visible.
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final items = RepoService.fcaItems;
    final floorMap = <String, List<FcaItem>>{};
    for (final item in items) {
      floorMap.putIfAbsent(item.aras, () => []).add(item);
    }

    // Complaint counts per floor (open / in-progress).
    final ticketCounts = <String, List<int>>{};
    try {
      final tickets = await ComplaintService.load();
      for (final t in tickets) {
        if (t.status == 'open' || t.status == 'in_progress') {
          final counts = ticketCounts.putIfAbsent(t.floor, () => [0, 0]);
          if (t.status == 'open') {
            counts[0]++;
          } else {
            counts[1]++;
          }
        }
      }
    } catch (_) {}

    final next = _buildFullFloorList(floorMap, ticketCounts);
    if (!mounted) return;
    setState(() {
      _floors = next;
      _loading = false;
    });
  }

  List<FloorInfo> _buildFullFloorList(Map<String, List<FcaItem>> floorMap, Map<String, List<int>> ticketCounts) {
    final result = <FloorInfo>[];

    // Upper tower floors 37 → 1
    for (int i = 37; i >= 1; i--) {
      final key = i.toString();
      final fcaItems = floorMap[key] ?? [];
      result.add(_makeFloor(key, fcaItems, ticketCounts[key]));
    }

    // Lower levels (top to bottom): M, G, P (P1–P7 combined), B1, B2
    // Actual JKR building setup: tower 1–37, mezzanine M, ground G,
    // parking podium P1–P7 shown as one "P" band, basement B1 then B2.
    for (final level in ['M', 'G', 'P', 'B1', 'B2']) {
      final fcaItems = floorMap[level] ?? [];
      result.add(_makeFloor(level, fcaItems, ticketCounts[level]));
    }

    return result;
  }

  FloorInfo _makeFloor(String key, List<FcaItem> fcaItems, List<int>? ticketCounts) {
    final open = fcaItems.where((i) => i.status == 'open').length;
    final inProgress = fcaItems.where((i) => i.status == 'in_progress').length;
    final closed = fcaItems.where((i) => i.status == 'closed').length;
    return FloorInfo(
      floor: key,
      open: open,
      inProgress: inProgress,
      closed: closed,
      items: fcaItems,
      ticketOpen: ticketCounts?[0] ?? 0,
      ticketInProgress: ticketCounts?[1] ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = ThemeProvider.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Bangunan JKR (36 Level)' : 'Bangunan JKR (36 Aras)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _floors.isEmpty
          ? Center(child: Text(eng ? 'No floor data' : 'Tiada data aras'))
          : Stack(
              children: [
                _buildTower(eng, isDark),
                if (!_loading)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _demoButton(eng: eng),
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
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EngineeringDemoScreen(floor: _floors[idx].floor)),
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

   Widget _demoButton({required bool eng}) {
     return GestureDetector(
       onTap: () => Navigator.of(context).push(
         MaterialPageRoute(builder: (_) => const EngineeringDemoScreen(floor: '34')),
       ),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
         decoration: BoxDecoration(
           color: const Color(0xFF0D7377).withValues(alpha: 0.9),
           borderRadius: const BorderRadius.only(
             topRight: Radius.circular(12),
             bottomRight: Radius.circular(12),
           ),
           boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(2, 2))],
         ),
         child: RotatedBox(
           quarterTurns: 3,
           child: Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Icon(Icons.grid_on_rounded, color: Colors.white, size: 16),
               const SizedBox(width: 6),
               Text(eng ? 'CAD DEMO' : 'DEMO CAD',
                 style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
             ],
           ),
         ),
       ),
     );
   }
 }

class FloorInfo {
  final String floor;
  final int open;
  final int inProgress;
  final int closed;
  final int ticketOpen;
  final int ticketInProgress;
  final List<FcaItem> items;

  FloorInfo({
    required this.floor,
    required this.open,
    required this.inProgress,
    required this.closed,
    required this.items,
    this.ticketOpen = 0,
    this.ticketInProgress = 0,
  });
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

    for (int i = 0; i < floors.length; i++) {
      final info = floors[i];
      final y = i * floorH;
      final rect = Rect.fromLTWH(offsetX, y, buildingW, floorH - 1);

      final base = info.ticketOpen > 0
        ? const Color(0xFFEF4444)
        : info.ticketInProgress > 0
          ? const Color(0xFFF59E0B)
          : info.open > 0
            ? const Color(0xFFEF4444)
            : info.inProgress > 0
              ? const Color(0xFFF59E0B)
              : const Color(0xFF22C55E);

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

      // Floor label INSIDE the band, centered
      final tp = TextPainter(
        text: TextSpan(
          text: info.floor,
          style: TextStyle(
            color: i == selectedIdx ? Colors.white : Colors.white.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          offsetX + (buildingW - tp.width) / 2,
          y + (floorH - tp.height) / 2 - 1,
        ),
      );

      // Complaint count badge on the right edge of the band.
      final ticketCount = info.ticketOpen + info.ticketInProgress;
      if (ticketCount > 0) {
        final badge = TextPainter(
          text: TextSpan(
            text: '● $ticketCount',
            style: TextStyle(
              color: info.ticketOpen > 0 ? const Color(0xFFFFE3E3) : const Color(0xFFFFF3D6),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        badge.paint(
          canvas,
          Offset(offsetX + buildingW - badge.width - 6, y + (floorH - badge.height) / 2),
        );
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
