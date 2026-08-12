import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization.dart';
import '../services/floor_plan_service.dart';
import '../services/repo_service.dart';
import '../services/performance.dart';
import '../services/complaint_service.dart';
import '../data/floor_plan_data.dart';
import '../data/fca_data.dart';
import '../data/complaint_data.dart';

class FloorPlanViewScreen extends StatefulWidget {
  final String floor;
  const FloorPlanViewScreen({super.key, required this.floor});

  @override
  State<FloorPlanViewScreen> createState() => _FloorPlanViewScreenState();
}

class _FloorPlanViewScreenState extends State<FloorPlanViewScreen> {
  FloorPlan? _plan;
  bool _loading = true;
  List<FcaItem> _fcaItems = [];
  List<ComplaintTicket> _openTickets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _plan = await FloorPlanService.getFloorPlan(widget.floor);
    _fcaItems = RepoService.fcaItems.where((f) => f.aras == widget.floor).toList();
    _openTickets = await ComplaintService.getOpen(widget.floor);
    if (mounted) setState(() => _loading = false);
  }

  bool _ticketMatchesAsset(ComplaintTicket t, FloorAsset asset) {
    final haystack = [t.assetName ?? '', t.description, t.issueType]
        .where((s) => s.isNotEmpty)
        .join(' ');
    return _textMatches(asset.name, haystack) || _textMatches(asset.type, haystack);
  }

  Set<int> _fcaAssetIndices() {
    if (_plan == null) return {};
    final hits = <int>{};
    for (int i = 0; i < _plan!.assets.length; i++) {
      final a = _plan!.assets[i];
      for (final f in _fcaItems) {
        if (_textMatches(a.name, f.ruang) || _textMatches(a.type, f.jenis)) {
          hits.add(i);
          break;
        }
      }
    }
    return hits;
  }

  bool _textMatches(String a, String b) => textMatchesAsset(a, b);



  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${eng ? 'Floor' : 'Aras'} ${widget.floor}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: eng ? 'Edit Floor Plan' : 'Ubah Pelan',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FloorPlanEditorScreen(floor: widget.floor, plan: _plan!),
            )).then((_) => _load()),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildCanvas(eng),
    );
  }

  Widget _buildCanvas(bool eng) {
    final plan = _plan!;
    final size = _canvasSize();
    final center = size / 2;
    final radius = size / 2 - 4;

    return Center(
      child: SizedBox(
        width: size, height: size,
        child: InteractiveViewer(
          minScale: 0.5, maxScale: 4.0, constrained: false,
          child: GestureDetector(
            onTapDown: (d) => _handleTap(d.localPosition, center, radius, plan, eng),
            child: CustomPaint(
              size: Size(size, size),
              painter: _FloorPlanPainter(
                plan: plan, canvasSize: size, eng: eng,
                fcaAssetIndices: _fcaAssetIndices(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _canvasSize() {
    final mq = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    return math.min(mq.width - 8, mq.height - kToolbarHeight - pad.top - pad.bottom - 8);
  }

  void _handleTap(Offset pos, double center, double radius, FloorPlan plan, bool eng) {
    if ((pos - Offset(center, center)).distance > radius) return;
    for (final asset in plan.assets) {
      final r = _assetRect(asset, center, radius, plan.gridW, plan.gridH);
      if (pos.dx >= r.left && pos.dx <= r.right && pos.dy >= r.top && pos.dy <= r.bottom) {
        _showAssetDetail(asset, eng);
        return;
      }
    }
  }

  Rect _assetRect(FloorAsset a, double c, double r, int gw, int gh) {
    final ax = c - r + (a.x / gw) * r * 2;
    final ay = c - r + (a.y / gh) * r * 2;
    return Rect.fromLTWH(ax, ay, (a.w / gw) * r * 2, (a.h / gh) * r * 2);
  }

  void _showAssetDetail(FloorAsset asset, bool eng) {
    final linked = _fcaItems.where((f) =>
      _textMatches(asset.name, f.ruang) || _textMatches(asset.type, f.jenis)
    ).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Text(FloorPlan.assetTypeMeta[asset.type]?['icon'] ?? '📦', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name.isNotEmpty ? asset.name : asset.type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(FloorPlan.assetTypeMeta[asset.type]?['label'] ?? asset.type, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: asset.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(_statusLabel(asset.status, eng), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: asset.color)),
              ),
            ]),
            if (linked.isNotEmpty) ...[
              const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 8),
              Text(eng ? 'Related Issues' : 'Isu Berkaitan', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...linked.map((f) => GestureDetector(
                onTap: () { Navigator.of(ctx).pop(); _showFcaDetail(f, eng); },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(width: 3, height: 32, decoration: BoxDecoration(
                      color: f.status == 'open' ? const Color(0xFFEF4444) : f.status == 'in_progress' ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.kerosakan, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(f.ruang, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    )),
                    Icon(Icons.chevron_right_rounded, size: 18, color: const Color(0xFF0D7377).withValues(alpha: 0.5)),
                  ]),
                ),
              )),
            ],
            if (_openTickets.where((t) => _ticketMatchesAsset(t, asset)).isNotEmpty) ...[
              const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 8),
              Text(eng ? 'Complaints' : 'Aduan', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ..._openTickets.where((t) => _ticketMatchesAsset(t, asset)).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 3, height: 32, decoration: BoxDecoration(
                    color: t.status == 'open' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.noRuj ?? '#${t.seqId}', maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  )),
                ]),
              )),
            ],
            if (asset.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(asset.notes, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: Text(eng ? 'Delete Asset' : 'Padam Asset', style: const TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                onPressed: () { Navigator.of(ctx).pop(); _confirmDelete(asset, eng); },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFcaDetail(FcaItem fca, bool eng) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(child: Container(margin: const EdgeInsets.only(top: 4, bottom: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 8),
              // Status badge
              Row(children: [
                _fcaBadge(fca.status, eng),
                const SizedBox(width: 8),
                _fcaBadge(fca.priority, eng),
                if (fca.displayAssetType.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7377).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(fca.displayAssetType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF0D7377))),
                  ),
                ],
                const Spacer(),
                Text('#${fca.bil}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 16),
              // Problem
              Text(eng ? 'Issue' : 'Kerosakan', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(fca.kerosakan, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              // Room & Floor
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eng ? 'Room' : 'Ruang', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(fca.ruang, style: const TextStyle(fontSize: 14)),
                  ],
                )),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eng ? 'Floor' : 'Aras', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(fca.aras, style: const TextStyle(fontSize: 14)),
                  ],
                )),
              ]),
              // Type
              if (fca.jenis.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(eng ? 'Type' : 'Jenis', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(fca.jenis, style: const TextStyle(fontSize: 14)),
              ],
              // JKR Request
              if (fca.jkrRequest.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(eng ? 'JKR Request' : 'Permohonan JKR', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(fca.jkrRequest, style: const TextStyle(fontSize: 14)),
              ],
              // Date
              if (fca.tarikh.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(eng ? 'Date' : 'Tarikh', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(fca.tarikh, style: const TextStyle(fontSize: 14)),
              ],
              // Solution
              if (fca.solution.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(eng ? 'Solution' : 'Penyelesaian', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(fca.solution, style: const TextStyle(fontSize: 14)),
              ],
              // Image
              if (fca.imageFile.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(eng ? 'Image Evidence' : 'Bukti Gambar', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImageFullscreen(fca.imageUrl, eng),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 220,
                      child: Image.network(
                        fca.imageUrl,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 220,
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(eng ? 'Loading...' : 'Muat naik...', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, stack) => Container(
                        height: 220,
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_not_supported_rounded, size: 32, color: Colors.grey.shade400),
                              const SizedBox(height: 4),
                              Text(eng ? 'Tap to retry' : 'Tekan untuk cuba lagi', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 4),
                Center(child: Text(eng ? 'Tap image to zoom' : 'Tekan gambar untuk zum', style: TextStyle(fontSize: 10, color: Colors.grey.shade400))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImageFullscreen(String url, bool eng) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text(''),
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (_, _, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                      const SizedBox(height: 8),
                      Text(eng ? 'Failed to load image' : 'Gagal muat gambar', style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fcaBadge(String label, bool eng) {
    final color = switch (label) {
      'open' => const Color(0xFFEF4444),
      'in_progress' => const Color(0xFFF59E0B),
      'closed' => const Color(0xFF22C55E),
      'high' => const Color(0xFFEF4444),
      'medium' => const Color(0xFFF59E0B),
      'low' => const Color(0xFF22C55E),
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(label.replaceAll('_', ' '), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _confirmDelete(FloorAsset target, bool eng) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete Asset' : 'Padam Asset'),
        content: Text(eng ? "Delete '${target.name.isNotEmpty ? target.name : target.type}'?" : "Padam '${target.name.isNotEmpty ? target.name : target.type}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(eng ? 'Cancel' : 'Batal')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              _plan!.assets.removeWhere((a) => a.id == target.id);
              Navigator.of(ctx).pop();
              setState(() {});
              FloorPlanService.saveFloorPlan(_plan!);
            }, child: Text(eng ? 'Delete' : 'Padam'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status, bool eng) {
    switch (status) {
      case 'good': return eng ? 'Good' : 'Baik';
      case 'down': return eng ? 'Down' : 'Rosak';
      case 'maintenance': return eng ? 'Maintenance' : 'Senggara';
      default: return status;
    }
  }
}

// ─── EDITOR SCREEN ──────────────────────────────────────────────────────────

class FloorPlanEditorScreen extends StatefulWidget {
  final String floor;
  final FloorPlan plan;
  const FloorPlanEditorScreen({super.key, required this.floor, required this.plan});

  @override
  State<FloorPlanEditorScreen> createState() => _FloorPlanEditorScreenState();
}

class _FloorPlanEditorScreenState extends State<FloorPlanEditorScreen> {
  late FloorPlan _plan;
  String? _selectedType;
  String? _selectedStatus;
  final _nameCtrl = TextEditingController();

  // Drag state
  int? _dragAssetIdx;
  double _dragX = 0, _dragY = 0;
  bool _isDragging = false;
  DateTime? _lastDragUpdate;

  // Resize state
  String? _resizeHandle;
  double _resizeStartX = 0, _resizeStartY = 0;
  int _resizeOrigX = 0, _resizeOrigY = 0, _resizeOrigW = 0, _resizeOrigH = 0;
  DateTime? _lastResizeUpdate;

  // Select state
  int? _selIdx;

  // Draw tool
  String? _drawTool; // line, circle, rect
  int _drawStep = 0;
  int _drawX1 = 0, _drawY1 = 0;

  // Debounced save queue
  late final AsyncSaveQueue _saveQueue;

  Set<int> get _fcaAssetIndices {
    final hits = <int>{};
    final items = RepoService.fcaItems.where((f) => f.aras == widget.floor).toList();
    for (int i = 0; i < _plan.assets.length; i++) {
      final a = _plan.assets[i];
      for (final f in items) {
        if (_textMatchesAsset(a.name, f.ruang) || _textMatchesAsset(a.type, f.jenis)) {
          hits.add(i);
          break;
        }
      }
    }
    return hits;
  }

  bool _textMatchesAsset(String a, String b) => textMatchesAsset(a, b);

  // Framebuffer for canvas (static background cache)
  final _canvasPainterCache = PainterCache();

  static const _handleSize = 8.0;
  static const _handleHalf = _handleSize / 2;

  Future<void> _doSave() => FloorPlanService.saveFloorPlan(_plan);

  void _autoSave() => _saveQueue.schedule();

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _saveQueue = AsyncSaveQueue(delay: const Duration(seconds: 1), saveFn: _doSave);
  }

  @override
  void dispose() {
    _saveQueue.dispose();
    _canvasPainterCache.clear();
    _nameCtrl.dispose();
    super.dispose();
  }

  double _canvasSize() {
    final mq = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    return math.min(mq.width - 8, mq.height - kToolbarHeight - pad.top - pad.bottom - _paletteHeight() - 8);
  }

  double _paletteHeight() {
    final toolH = _drawTool != null ? 28.0 : 0.0;
    final hintH = _selectedType != null ? 28.0 : 0.0;
    final selH = _selIdx != null ? 34.0 : 0.0;
    return 80 + toolH + hintH + selH;
  }

  Rect _assetRect(FloorAsset a, double c, double r) {
    final ax = c - r + (a.x / _plan.gridW) * r * 2;
    final ay = c - r + (a.y / _plan.gridH) * r * 2;
    return Rect.fromLTWH(ax, ay, (a.w / _plan.gridW) * r * 2, (a.h / _plan.gridH) * r * 2);
  }

  // Returns handle name if pos is on a handle of the selected asset
  String? _hitHandle(Offset pos, double c, double r) {
    if (_selIdx == null || _selIdx! >= _plan.assets.length) return null;
    final a = _plan.assets[_selIdx!];
    final rect = _assetRect(a, c, r);
    const handles = {'tl': Offset(0,0), 'tr': Offset(1,0), 'bl': Offset(0,1), 'br': Offset(1,1),
                     'tm': Offset(0.5,0), 'bm': Offset(0.5,1), 'ml': Offset(0,0.5), 'mr': Offset(1,0.5)};
    for (final h in handles.entries) {
      final hx = rect.left + h.value.dx * rect.width;
      final hy = rect.top + h.value.dy * rect.height;
      if ((pos - Offset(hx, hy)).distance <= _handleHalf + 4) return h.key;
    }
    return null;
  }

  int _hitTest(Offset pos, double c, double r) {
    for (int i = _plan.assets.length - 1; i >= 0; i--) {
      final a = _plan.assets[i];
      final rect = _assetRect(a, c, r);
      if (pos.dx >= rect.left && pos.dx <= rect.right && pos.dy >= rect.top && pos.dy <= rect.bottom) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final size = _canvasSize();
    final center = size / 2;
    final radius = size / 2 - 4;

    return Scaffold(
      appBar: AppBar(
        title: Text('${eng ? 'Edit Floor' : 'Ubah Aras'} ${widget.floor}'),
        actions: [
          IconButton(icon: const Icon(Icons.save_rounded), onPressed: () async {
            final sm = ScaffoldMessenger.of(context);
            final nav = Navigator.of(context);
            await _saveQueue.flush();
            await _doSave();
            if (!mounted) return;
            sm.showSnackBar(SnackBar(content: Text(eng ? 'Floor plan saved!' : 'Pelan aras disimpan!'), behavior: SnackBarBehavior.floating));
            nav.pop();
          }),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildCanvas(size, center, radius, eng)),
          RepaintBoundary(child: _buildPalette(eng)),
        ],
      ),
    );
  }

  bool _isResizing() => _resizeHandle != null;

  void _handleTapUp(Offset pos, double center, double radius, bool eng) {
    if (_isDragging || _isResizing()) return;
    if ((pos - Offset(center, center)).distance > radius) return;

    // Drawing mode
    if (_drawTool != null) {
      final gx = ((pos.dx - (center - radius)) / (radius * 2) * _plan.gridW).round().clamp(0, _plan.gridW - 1);
      final gy = ((pos.dy - (center - radius)) / (radius * 2) * _plan.gridH).round().clamp(0, _plan.gridH - 1);
      if (_drawStep == 0) {
        setState(() { _drawX1 = gx; _drawY1 = gy; _drawStep = 1; });
      } else {
        final minX = math.min(_drawX1, gx);
        final minY = math.min(_drawY1, gy);
        final maxX = math.max(_drawX1, gx);
        final maxY = math.max(_drawY1, gy);
        setState(() {
          _plan.assets.add(FloorAsset(
            name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '${_drawTool}_$_drawX1$_drawY1',
            type: 'custom', shape: _drawTool!, x: minX, y: minY,
            w: math.max(maxX - minX + 1, 1), h: math.max(maxY - minY + 1, 1),
            status: _selectedStatus ?? 'good',
            points: [{'x': _drawX1, 'y': _drawY1}, {'x': gx, 'y': gy}],
          ));
          _drawStep = 0;
          _drawTool = null;
        });
        _autoSave();
      }
      return;
    }

    // Check asset hit
    final hit = _hitTest(pos, center, radius);
    if (hit >= 0) {
      setState(() {
        _selIdx = _selIdx == hit ? null : hit;
        if (_selIdx != null) {
          _nameCtrl.text = _plan.assets[_selIdx!].name;
          _selectedStatus = _plan.assets[_selIdx!].status;
        }
      });
    } else if (_selectedType != null) {
      final gx = ((pos.dx - (center - radius)) / (radius * 2) * _plan.gridW).round().clamp(0, _plan.gridW - 2);
      final gy = ((pos.dy - (center - radius)) / (radius * 2) * _plan.gridH).round().clamp(0, _plan.gridH - 2);
      final isCustom = _selectedType == 'custom';
      final defaultName = isCustom ? 'Custom_$gx$gy' : '${_selectedType}_$gx$gy';
      setState(() {
        _plan.assets.add(FloorAsset(
          name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : defaultName,
          type: _selectedType!, x: gx, y: gy, status: _selectedStatus ?? 'good',
        ));
      });
      _autoSave();
    } else {
      setState(() => _selIdx = null);
    }
  }

  void _handleLongPressStart(Offset pos, double center, double radius) {
    // First check resize handles on selected asset
    if (_selIdx != null) {
      final handle = _hitHandle(pos, center, radius);
      if (handle != null) {
        final a = _plan.assets[_selIdx!];
        setState(() {
          _resizeHandle = handle;
          _resizeStartX = pos.dx;
          _resizeStartY = pos.dy;
          _resizeOrigX = a.x;
          _resizeOrigY = a.y;
          _resizeOrigW = a.w;
          _resizeOrigH = a.h;
        });
        return;
      }
    }
    // Then check asset body for drag
    final hit = _hitTest(pos, center, radius);
    if (hit < 0) return;
    setState(() {
      _selIdx = null;
      _dragAssetIdx = hit;
      _dragX = _plan.assets[hit].x.toDouble();
      _dragY = _plan.assets[hit].y.toDouble();
      _isDragging = true;
    });
  }

  void _handleLongPressMove(Offset pos, double center, double radius) {
    if (_isResizing()) {
      final now = DateTime.now();
      if (_lastResizeUpdate != null && now.difference(_lastResizeUpdate!).inMilliseconds < 30) return;
      _lastResizeUpdate = now;
      _resizeUpdate(pos, center, radius);
    } else if (_isDragging) {
      if (_dragAssetIdx == null) return;
      final now = DateTime.now();
      if (_lastDragUpdate != null && now.difference(_lastDragUpdate!).inMilliseconds < 30) return;
      _lastDragUpdate = now;
      final gx = ((pos.dx - (center - radius)) / (radius * 2) * _plan.gridW).round().clamp(0, _plan.gridW - 2);
      final gy = ((pos.dy - (center - radius)) / (radius * 2) * _plan.gridH).round().clamp(0, _plan.gridH - 2);
      setState(() { _dragX = gx.toDouble(); _dragY = gy.toDouble(); });
    }
  }

  void _handleLongPressEnd(double center, double radius) {
    if (_isResizing()) {
      setState(() { _resizeHandle = null; });
      _autoSave();
    } else if (_isDragging) {
      if (_dragAssetIdx == null) return;
      setState(() {
        _plan.assets[_dragAssetIdx!].x = _dragX.round();
        _plan.assets[_dragAssetIdx!].y = _dragY.round();
        _isDragging = false;
        _dragAssetIdx = null;
      });
      _autoSave();
    }
  }

  void _resizeUpdate(Offset pos, double center, double radius) {
    if (_selIdx == null || _resizeHandle == null) return;
    final a = _plan.assets[_selIdx!];
    final dx = ((pos.dx - _resizeStartX) / (radius * 2) * _plan.gridW).round();
    final dy = ((pos.dy - _resizeStartY) / (radius * 2) * _plan.gridH).round();

    int newX = _resizeOrigX, newY = _resizeOrigY, newW = _resizeOrigW, newH = _resizeOrigH;

    switch (_resizeHandle!) {
      case 'tl': newX = _resizeOrigX + dx; newY = _resizeOrigY + dy; newW = _resizeOrigW - dx; newH = _resizeOrigH - dy; break;
      case 'tr': newY = _resizeOrigY + dy; newW = _resizeOrigW + dx; newH = _resizeOrigH - dy; break;
      case 'bl': newX = _resizeOrigX + dx; newW = _resizeOrigW - dx; newH = _resizeOrigH + dy; break;
      case 'br': newW = _resizeOrigW + dx; newH = _resizeOrigH + dy; break;
      case 'tm': newY = _resizeOrigY + dy; newH = _resizeOrigH - dy; break;
      case 'bm': newH = _resizeOrigH + dy; break;
      case 'ml': newX = _resizeOrigX + dx; newW = _resizeOrigW - dx; break;
      case 'mr': newW = _resizeOrigW + dx; break;
    }

    if (newW < 1) { newW = 1; newX = _resizeOrigX + _resizeOrigW - 1; }
    if (newH < 1) { newH = 1; newY = _resizeOrigY + _resizeOrigH - 1; }

    setState(() {
      a.x = newX.clamp(0, _plan.gridW - 1);
      a.y = newY.clamp(0, _plan.gridH - 1);
      a.w = newW.clamp(1, _plan.gridW - a.x);
      a.h = newH.clamp(1, _plan.gridH - a.y);
    });
  }

  Widget _buildCanvas(double size, double center, double radius, bool eng) {
    return RepaintBoundary(
      child: Center(
        child: SizedBox(
          width: size, height: size,
          child: InteractiveViewer(
            minScale: 0.5, maxScale: 4.0, constrained: false,
            panEnabled: !_isDragging && !_isResizing(),
            child: GestureDetector(
              onTapUp: (d) => _handleTapUp(d.localPosition, center, radius, eng),
              onLongPressStart: (d) => _handleLongPressStart(d.localPosition, center, radius),
              onLongPressMoveUpdate: (_isDragging || _isResizing()) ? (d) => _handleLongPressMove(d.localPosition, center, radius) : null,
              onLongPressEnd: (_isDragging || _isResizing()) ? (d) => _handleLongPressEnd(center, radius) : null,
              child: CustomPaint(
                size: Size(size, size),
                painter: _FloorPlanPainter(
                  plan: _plan, canvasSize: size, eng: eng, showGrid: true,
                  dragIdx: _dragAssetIdx, dragOffset: _isDragging ? Offset(_dragX, _dragY) : null,
                  selIdx: _selIdx, resizeHandle: _resizeHandle, drawTool: _drawTool, drawStep: _drawStep,
                  fcaAssetIndices: _fcaAssetIndices,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPalette(bool eng) {
    return Container(
      height: _paletteHeight(),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              // Draw tools
              ..._drawToolChips(eng),
              // Asset type chips
              ...FloorPlan.assetTypeMeta.entries.map((e) {
                final active = _selectedType == e.key;
                return GestureDetector(
                  onTap: () => setState(() { _selectedType = active ? null : e.key; _drawTool = null; _drawStep = 0; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF0D7377) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      if ((e.value['icon'] as String).isNotEmpty) Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(e.value['icon'] as String, style: const TextStyle(fontSize: 14)),
                      ),
                      Text(e.value['label'] as String, style: TextStyle(fontSize: 10, color: active ? Colors.white : Colors.grey.shade700)),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            _statusBtn('good', '🟢'), _statusBtn('down', '🔴'), _statusBtn('maintenance', '🟡'),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: eng ? 'Asset name' : 'Nama asset',
                isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              style: const TextStyle(fontSize: 12),
            )),
            if (_dragAssetIdx != null || _selIdx != null)
              Padding(padding: const EdgeInsets.only(left: 4), child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                onPressed: () {
                  final idx = _dragAssetIdx ?? _selIdx;
                   if (idx != null && idx < _plan.assets.length) {
                     setState(() { _plan.assets.removeAt(idx); _dragAssetIdx = null; _isDragging = false; _selIdx = null; });
                     _autoSave();
                   }
                 },
               )),
             if (_selIdx != null && _selIdx! < _plan.assets.length)
               Padding(padding: const EdgeInsets.only(left: 4), child: IconButton(
                 icon: Icon(Icons.check_rounded, size: 18, color: const Color(0xFF0D7377)),
                 tooltip: eng ? 'Update' : 'Kemas kini',
                 onPressed: () {
                   setState(() {
                     _plan.assets[_selIdx!].name = _nameCtrl.text;
                     _plan.assets[_selIdx!].status = _selectedStatus ?? _plan.assets[_selIdx!].status;
                     _selIdx = null;
                   });
                   _autoSave();
                 },
              )),
          ]),
        ),
        if (_drawTool != null && _drawStep == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Icon(Icons.edit, size: 12, color: const Color(0xFF0D7377)),
              const SizedBox(width: 4),
              Text(eng ? 'Tap again to finish shape' : 'Tekan lagi untuk selesai', style: TextStyle(fontSize: 10, color: const Color(0xFF0D7377))),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 14, color: Colors.red),
                onPressed: () => setState(() { _drawTool = null; _drawStep = 0; }),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
        if (_drawTool == null && _selectedType != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Icon(Icons.touch_app, size: 12, color: const Color(0xFF0D7377)),
              const SizedBox(width: 4),
              Text(eng ? 'Tap plan to place' : 'Tekan pelan untuk letak', style: TextStyle(fontSize: 10, color: const Color(0xFF0D7377))),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF0D7377)),
                tooltip: eng ? 'Add at centre' : 'Tambah di tengah',
                onPressed: () {
                  final cx = _plan.gridW ~/ 2; final cy = _plan.gridH ~/ 2;
                  final isCustom = _selectedType == 'custom';
                  final defaultName = isCustom ? 'Custom_$cx$cy' : '${_selectedType}_$cx$cy';
                   setState(() { _plan.assets.add(FloorAsset(
                     name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : defaultName,
                     type: _selectedType!, x: cx, y: cy, status: _selectedStatus ?? 'good',
                   )); });
                   _autoSave();
                 },
              ),
            ]),
          ),
        if (_selIdx != null && _selIdx! < _plan.assets.length)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                label: Text(eng ? 'Delete this asset' : 'Padam asset ini', style: const TextStyle(fontSize: 11, color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 2), minimumSize: Size.zero, visualDensity: VisualDensity.compact),
                onPressed: () { setState(() { _plan.assets.removeAt(_selIdx!); _selIdx = null; }); _autoSave(); },
              ),
            ),
          ),
      ]),
    );
  }

  List<Widget> _drawToolChips(bool eng) {
    final tools = [
      {'key': 'line', 'icon': '━', 'label': eng ? 'Line' : 'Garis'},
      {'key': 'rect', 'icon': '▭', 'label': eng ? 'Rect' : 'Segiempat'},
      {'key': 'circle', 'icon': '●', 'label': eng ? 'Circle' : 'Bulatan'},
    ];
    return tools.map((t) {
      final active = _drawTool == t['key'];
      return GestureDetector(
        onTap: () => setState(() { _drawTool = active ? null : t['key']; _drawStep = 0; _selectedType = null; }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF7C3AED) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Text(t['icon'] as String, style: TextStyle(fontSize: 12, color: active ? Colors.white : Colors.grey.shade700)),
            const SizedBox(width: 3),
            Text(t['label'] as String, style: TextStyle(fontSize: 10, color: active ? Colors.white : Colors.grey.shade700)),
          ]),
        ),
      );
    }).toList();
  }

  Widget _statusBtn(String status, String icon) {
    final active = _selectedStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = active ? null : status),
      child: Container(
        padding: const EdgeInsets.all(4), margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? Colors.grey.shade200 : null, borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: Colors.grey.shade400) : null,
        ),
        child: Text(icon, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

// ─── PAINTER ─────────────────────────────────────────────────────────────────

class _FloorPlanPainter extends CustomPainter {
  final FloorPlan plan;
  final double canvasSize;
  final bool eng;
  final bool showGrid;
  final int? dragIdx;
  final Offset? dragOffset;
  final int? selIdx;
  final String? resizeHandle;
  final String? drawTool;
  final int drawStep;
  final Set<int> fcaAssetIndices;

  _FloorPlanPainter({
    required this.plan, required this.canvasSize, required this.eng,
    this.showGrid = false, this.dragIdx, this.dragOffset, this.selIdx,
    this.resizeHandle, this.drawTool, this.drawStep = 0,
    this.fcaAssetIndices = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(canvasSize / 2, canvasSize / 2);
    final r = canvasSize / 2 - 4;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFF0F4F8));

    // Shadow
    canvas.drawCircle(Offset(c.dx + 3, c.dy + 4), r + 2, Paint()
      ..color = Colors.black.withValues(alpha: 0.08)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Outer wall
    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(center: Alignment.center, radius: 1, colors: const [Color(0xFFE2E8F0), Color(0xFFF1F5F9)])
        .createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF64748B)..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawCircle(c, r - 6, Paint()..color = const Color(0xFF94A3B8).withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1);

    // Core
    final coreR = r * 0.28;
    canvas.drawCircle(c, coreR, Paint()..color = const Color(0xFFD1D5DB));
    canvas.drawCircle(c, coreR, Paint()..color = const Color(0xFF9CA3AF)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final hatch = Paint()..color = const Color(0xFF9CA3AF).withValues(alpha: 0.2)..strokeWidth = 0.5;
    for (int a = 0; a < 360; a += 30) {
      final rad = a * math.pi / 180;
      canvas.drawLine(Offset(c.dx + math.cos(rad) * coreR * 0.2, c.dy + math.sin(rad) * coreR * 0.2),
                      Offset(c.dx + math.cos(rad) * coreR, c.dy + math.sin(rad) * coreR), hatch);
    }

    // Rings
    for (final f in [0.45, 0.62, 0.79]) {
      canvas.drawCircle(c, r * f, Paint()..color = const Color(0xFFCBD5E1).withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // Quadrants
    for (int q = 0; q < 4; q++) {
      final rad = q * math.pi / 2;
      canvas.drawLine(c, Offset(c.dx + math.cos(rad) * (r - 6), c.dy + math.sin(rad) * (r - 6)),
                      Paint()..color = const Color(0xFFCBD5E1).withValues(alpha: 0.2)..strokeWidth = 0.5);
    }

    // NSEW
    final cardStyle = TextStyle(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600);
    for (final entry in [{'l':'N','dx':0.0,'dy':-1.0},{'l':'S','dx':0.0,'dy':1.0},{'l':'E','dx':1.0,'dy':0.0},{'l':'W','dx':-1.0,'dy':0.0}]) {
      final tp = TextPainter(text: TextSpan(text: entry['l'] as String, style: cardStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(c.dx + (entry['dx'] as double) * (r + 14) - tp.width / 2, c.dy + (entry['dy'] as double) * (r + 14) - tp.height / 2));
    }

    // Draw tool preview
    if (drawTool != null && drawStep == 1) {
      canvas.drawCircle(c, r * 0.6, Paint()..color = const Color(0xFF7C3AED).withValues(alpha: 0.05));
      final tp = TextPainter(
        text: TextSpan(text: 'Tap second point', style: TextStyle(fontSize: 10, color: const Color(0xFF7C3AED))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - coreR * 0.3));
    }

    // Grid
    if (showGrid) {
      final gp = Paint()..color = Colors.grey.withValues(alpha: 0.1)..strokeWidth = 0.5;
      for (int x = 0; x <= plan.gridW; x++) {
        final px = c.dx - r + (x / plan.gridW) * r * 2;
        canvas.drawLine(Offset(px, c.dy - r), Offset(px, c.dy + r), gp);
      }
      for (int y = 0; y <= plan.gridH; y++) {
        final py = c.dy - r + (y / plan.gridH) * r * 2;
        canvas.drawLine(Offset(c.dx - r, py), Offset(c.dx + r, py), gp);
      }
    }

    // Assets
    for (int i = 0; i < plan.assets.length; i++) {
      final asset = plan.assets[i];
      final isDragging = i == dragIdx;
      final isSelected = i == selIdx;

      double ax, ay;
      if (isDragging && dragOffset != null) {
        ax = c.dx - r + (dragOffset!.dx / plan.gridW) * r * 2;
        ay = c.dy - r + (dragOffset!.dy / plan.gridH) * r * 2;
      } else {
        ax = c.dx - r + (asset.x / plan.gridW) * r * 2;
        ay = c.dy - r + (asset.y / plan.gridH) * r * 2;
      }
      final aw = (asset.w / plan.gridW) * r * 2;
      final ah = (asset.h / plan.gridH) * r * 2;

      if ((Offset(ax + aw/2, ay + ah/2) - c).distance > r) continue;

      final hasFca = fcaAssetIndices.contains(i);
      _drawAsset(canvas, asset, ax, ay, aw, ah, isDragging, isSelected, hasFca, c, r);
    }

    // Resize handles on selected asset
    if (selIdx != null && selIdx! < plan.assets.length) {
      final a = plan.assets[selIdx!];
      final rect = Rect.fromLTWH(
        c.dx - r + (a.x / plan.gridW) * r * 2,
        c.dy - r + (a.y / plan.gridH) * r * 2,
        (a.w / plan.gridW) * r * 2,
        (a.h / plan.gridH) * r * 2,
      );
      _drawResizeHandles(canvas, rect);
    }

    // Centre label
    final cl = TextPainter(
      text: TextSpan(text: 'Level ${plan.floor}', style: TextStyle(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    cl.paint(canvas, Offset(c.dx - cl.width / 2, c.dy - cl.height / 2));
  }

  Color _assetFillColor(FloorAsset asset, bool hasFca) {
    if (hasFca && asset.status == 'good') return const Color(0xFFEF4444);
    return asset.color;
  }

  Color _assetBorderColor(FloorAsset asset, bool hasFca) {
    if (hasFca && asset.status == 'good') return const Color(0xFFDC2626);
    if (hasFca) return const Color(0xFFEF4444);
    return asset.color;
  }

  void _drawAsset(Canvas canvas, FloorAsset asset, double ax, double ay, double aw, double ah, bool isDragging, bool isSelected, bool hasFca, Offset c, double r) {
    final shape = asset.shape;

    if (shape == 'line') {
      final pts = asset.points;
      if (pts.length >= 2) {
        final x1 = c.dx - r + (pts[0]['x']! / plan.gridW) * r * 2 + (aw / pts.length); // approximate
        final y1 = c.dy - r + (pts[0]['y']! / plan.gridH) * r * 2 + (ah / pts.length);
        final x2 = c.dx - r + (pts[1]['x']! / plan.gridW) * r * 2 + (aw / pts.length);
        final y2 = c.dy - r + (pts[1]['y']! / plan.gridH) * r * 2 + (ah / pts.length);
        final linePaint = Paint()
          ..color = _assetBorderColor(asset, hasFca).withValues(alpha: isDragging ? 0.8 : 0.6)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
      }
      return;
    }

    final corner = math.min(aw, ah) / 4;

    if (shape == 'circle') {
      final center = Offset(ax + aw / 2, ay + ah / 2);
      final radius = math.min(aw, ah) / 2;
      if (isSelected) {
        canvas.drawCircle(center, radius + 2, Paint()..color = const Color(0xFF0D7377).withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      }
      if (isDragging) {
        canvas.drawCircle(Offset(center.dx + 3, center.dy + 3), radius, Paint()..color = Colors.black.withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
      canvas.drawCircle(center, radius, Paint()..color = _assetFillColor(asset, hasFca).withValues(alpha: isDragging ? 0.5 : 0.3));
      canvas.drawCircle(center, radius, Paint()..color = _assetBorderColor(asset, hasFca).withValues(alpha: isDragging ? 0.8 : 0.6)..style = PaintingStyle.stroke..strokeWidth = isDragging ? 2.5 : 1.5);

      final icon = FloorPlan.assetTypeMeta[asset.type]?['icon'] ?? '';
      if (icon.isNotEmpty) {
        final fontSize = math.min(aw, ah).clamp(10, 24).toDouble();
        final ip = TextPainter(text: TextSpan(text: icon, style: TextStyle(fontSize: fontSize)), textDirection: TextDirection.ltr)..layout();
        ip.paint(canvas, Offset(center.dx - ip.width / 2, center.dy - ip.height / 2 + 2));
      }
      final label = asset.name.isNotEmpty ? asset.name : asset.type;
      final lp = TextPainter(text: TextSpan(text: label, style: TextStyle(fontSize: 8, color: Colors.grey.shade700)), textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: aw);
      lp.paint(canvas, Offset(ax + 2, ay + ah - lp.height - 2));
      return;
    }

    // rect shape (default)
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(ax, ay, aw, ah), Radius.circular(corner));

    if (isSelected) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ax - 2, ay - 2, aw + 4, ah + 4), Radius.circular(corner + 1)),
        Paint()..color = const Color(0xFF0D7377).withValues(alpha: 0.25)..strokeWidth = 2.5..style = PaintingStyle.stroke);
    }
    if (isDragging) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ax + 3, ay + 3, aw, ah), Radius.circular(corner)),
        Paint()..color = Colors.black.withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    canvas.drawRRect(rect, Paint()..color = _assetFillColor(asset, hasFca).withValues(alpha: isDragging ? 0.5 : 0.3));
    canvas.drawRRect(rect, Paint()..color = _assetBorderColor(asset, hasFca).withValues(alpha: isDragging ? 0.8 : 0.6)..style = PaintingStyle.stroke..strokeWidth = isDragging ? 2.5 : 1.5);

    final icon = FloorPlan.assetTypeMeta[asset.type]?['icon'] ?? '';
    if (icon.isNotEmpty) {
      final fontSize = math.min(aw, ah).clamp(10, 24).toDouble();
      final ip = TextPainter(text: TextSpan(text: icon, style: TextStyle(fontSize: fontSize)), textDirection: TextDirection.ltr)..layout();
      ip.paint(canvas, Offset(ax + (aw - ip.width) / 2, ay + 2));
    }

    final label = isDragging ? '${dragOffset!.dx.round()},${dragOffset!.dy.round()}' : (asset.name.isNotEmpty ? asset.name : asset.type);
    final lp = TextPainter(text: TextSpan(text: label, style: TextStyle(fontSize: 8, color: Colors.grey.shade700)), textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: aw);
    lp.paint(canvas, Offset(ax + 2, ay + ah - lp.height - 2));
  }

  void _drawResizeHandles(Canvas canvas, Rect rect) {
    final handlePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = const Color(0xFF0D7377)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final positions = [
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.left, rect.bottom),
      Offset(rect.right, rect.bottom),
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
    ];
    final hSize = 8.0;
    for (final pos in positions) {
      final r = Rect.fromCenter(center: pos, width: hSize, height: hSize);
      canvas.drawRect(r, handlePaint);
      canvas.drawRect(r, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPlanPainter old) =>
    old.plan != plan || old.canvasSize != canvasSize || old.showGrid != showGrid ||
    old.dragIdx != dragIdx || old.dragOffset != dragOffset || old.selIdx != selIdx ||
    old.resizeHandle != resizeHandle || old.drawTool != drawTool || old.drawStep != drawStep ||
    old.fcaAssetIndices.length != fcaAssetIndices.length ||
    !old.fcaAssetIndices.containsAll(fcaAssetIndices);
}
