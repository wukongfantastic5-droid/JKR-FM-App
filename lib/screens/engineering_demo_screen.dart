import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../glossary.dart';
import '../localization.dart';
import '../data/complaint_data.dart';
import '../data/fca_data.dart';
import '../data/floor_plan_data.dart';
import '../services/complaint_service.dart';
import '../services/repo_service.dart';

const _ringMax = 7.5;
const _cell = 60.0;
const _wallW = 4.0;
const _planSize = _ringMax * 2 * _cell; // 900

/// Live values re-derived for a detail sheet on every status change.
typedef _DetailRecompute = ({
  String status,
  Color color,
  List<ComplaintTicket> tickets,
  List<FcaItem> fcaItems,
}) Function();

class EngineeringDemoScreen extends StatefulWidget {
  final String floor;
  const EngineeringDemoScreen({super.key, required this.floor});

  @override
  State<EngineeringDemoScreen> createState() => _EngineeringDemoScreenState();
}

class _EngineeringDemoScreenState extends State<EngineeringDemoScreen> {
  List<_RoomSector> _rooms = [];
  bool _loading = true;
  String? _floorTotal;
  String? _dataSource;
  final _transformController = TransformationController();
  List<ComplaintTicket> _openTickets = [];
  List<FcaItem> _fcaItems = [];
  Size? _viewSize;
  bool _fitted = false;
  bool _designMode = false;
  final _labelDesigns = <String, _LabelDesign>{};
  Timer? _refreshTimer;
  /// Bumped whenever statuses are re-derived so pushed screens (asset type
  /// list, instance grid, detail sheets) rebuild with live statuses instead
  /// of the values captured when they were opened.
  final ValueNotifier<int> _statusVersion = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadDesign();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshStatuses());
  }

  Future<void> _refreshStatuses() async {
    try {
      final tickets = await ComplaintService.getOpen(widget.floor);
      _openTickets = tickets;
      final fcaRaw = await RepoService.readFile('fca.json');
      if (fcaRaw is List) {
        _fcaItems = fcaRaw
            .map((f) => FcaItem.fromJson(f as Map<String, dynamic>))
            .where((f) => f.aras == widget.floor && f.status != 'closed')
            .toList();
      }
      _applyAllStatuses();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Re-derives every room's status/pins from the in-memory [_openTickets]
  /// and [_fcaItems] — no network. Called after a local edit so the plan
  /// updates instantly.
  void _applyAllStatuses() {
    for (final room in _rooms) {
      room.status = 'good';
      room.linkedTickets.clear();
      room.issueCount = 0;
    }
    _applyStatuses(_rooms);
    _applyFcaStatuses(_rooms);
    for (final room in _rooms) {
      int count = room.linkedTickets.length;
      for (final fca in _fcaItems) {
        if (fca.status == 'open' || fca.status == 'in_progress') {
          if (_fcaMatchesSector(fca, room)) count++;
        }
      }
      room.issueCount = count;
    }
    _statusVersion.value++;
  }

  void _replaceTicketLocally(ComplaintTicket updated) {
    final idx = _openTickets.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _openTickets[idx] = updated;
    } else {
      _openTickets.add(updated);
    }
  }

  Future<void> _load() async {
    try {
      var data = await RepoService.readFile('me_assets_deep.json');
      data ??= await RepoService.readFile('me_assets_grouped.json');
      _openTickets = await ComplaintService.getOpen(widget.floor);
      final fcaRaw = await RepoService.readFile('fca.json');
      if (fcaRaw is List) {
        _fcaItems = fcaRaw
            .map((f) => FcaItem.fromJson(f as Map<String, dynamic>))
            .where((f) => f.aras == widget.floor && f.status != 'closed')
            .toList();
      }
      if (data != null) {
        _dataSource = 'grouped';
        final rooms = _buildSectors(data);        _applyStatuses(rooms);
        _applyFcaStatuses(rooms);
        for (final room in rooms) {
          int count = room.linkedTickets.length;
          for (final fca in _fcaItems) {
            if (fca.status == 'open' || fca.status == 'in_progress') {
              if (_fcaMatchesSector(fca, room)) count++;
            }
          }
          room.issueCount = count;
        }
        if (mounted) setState(() { _rooms = rooms; _loading = false; });
      } else {
        _dataSource = 'fallback (no data)';
        if (mounted) setState(() {
          _rooms = _isParkingFloor(widget.floor) ? _parkingSectors() : _fallback();
          _loading = false;
        });
      }
    } catch (e) {
      _dataSource = 'fallback (error: $e)';
      if (mounted) setState(() {
        _rooms = _isParkingFloor(widget.floor) ? _parkingSectors() : _fallback();
        _loading = false;
      });
    }
  }

  void _applyStatuses(List<_RoomSector> rooms) {
    for (final ticket in _openTickets) {
      // Combine the OCR asset ref, description and issue type so rooms like
      // "TANDAS WANITA" match tickets whose description mentions the asset
      // (e.g. "...LAMPU TANDAS WANITA TIDAK MENYALA...").
      final haystack = [ticket.assetName ?? '', ticket.description, ticket.issueType]
          .where((s) => s.isNotEmpty)
          .join(' ');
      // A ticket whose OCR asset reference names a specific room must only
      // mark THAT room (e.g. "G.33.008- TANDAS OKU" never marks the fire
      // fighting sector just because the description mentions "suis").
      for (final room in _roomsForTicket(rooms, ticket)) {
        bool match = _roomMatches(room, haystack);
        if (match) {
          if (ticket.status == 'open' && room.status != 'down') {
            room.status = 'down';
          } else if (ticket.status == 'in_progress' && room.status != 'maintenance') {
            room.status = 'maintenance';
          }
          room.linkedTickets.add(ticket);
        }
      }
    }
  }

  static const _genericRoomWords = {
    'TANDAS', 'TOILET', 'BILIK', 'ROOM', 'LOBBY', 'KORIDOR', 'CORRIDOR',
  };

  /// True when the ticket's OCR asset reference (e.g. "G.33.008- TANDAS OKU")
  /// points at this room. Tickets without an asset reference can match
  /// anywhere. Room words that are too generic ("TANDAS", "TOILET") alone do
  /// not pin the ticket, so "TANDAS WANITA" stays out of "TANDAS LELAKI".
  bool _ticketInRoom(ComplaintTicket t, _RoomSector room) {
    final assetNorm = (t.assetName ?? '').toUpperCase();
    if (assetNorm.trim().isEmpty) return true;
    final words = room.label.toUpperCase()
        .split(RegExp(r'[\s\(\)/,]+'))
        .where((w) => w.length >= 3 && !_genericRoomWords.contains(w))
        .toSet();
    if (words.isEmpty) return false;
    return words.any(assetNorm.contains);
  }

  bool _roomContainsInstance(_RoomSector room, String normName) {
    for (final inst in room.instances ?? []) {
      if (inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == normName) return true;
    }
    for (final g in room.typeGroups ?? []) {
      for (final inst in g.instances) {
        if (inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == normName) return true;
      }
    }
    return false;
  }

  /// Rooms a ticket may appear in: the room(s) named by its asset reference,
  /// the room(s) containing instances matching the ticket's subject, or every
  /// room when the reference names none.
  List<_RoomSector> _roomsForTicket(List<_RoomSector> rooms, ComplaintTicket t) {
    if ((t.assignedAsset ?? '').isNotEmpty) {
      final pin = t.assignedAsset!.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final pinnedRooms = rooms.where((r) => _roomContainsInstance(r, pin)).toList();
      if (pinnedRooms.isNotEmpty) return pinnedRooms;
    }
    final hit = rooms.where((r) => _ticketInRoom(t, r)).toList();
    if (hit.isNotEmpty) return hit;
    final subject = resolveAssetSubject(_ticketHaystack(t));
    if (subject != null) {
      final subjectRooms = rooms.where((r) => _roomHasSubject(r, subject)).toList();
      if (subjectRooms.isNotEmpty) return subjectRooms;
    }
    return rooms;
  }

  bool _roomHasSubject(_RoomSector room, String subject) {
    if (room.typeGroups != null) {
      for (final g in room.typeGroups!) {
        for (final inst in g.instances) {
          if (textMatchesAsset(inst.instanceName, subject)) return true;
        }
      }
    }
    if (room.instances != null) {
      for (final inst in room.instances!) {
        if (textMatchesAsset(inst.instanceName, subject)) return true;
      }
    }
    return false;
  }

  /// Tickets pinned to this instance (manual assignment wins), otherwise the
  /// room-restricted auto match resolved to the ticket's single subject.
  List<ComplaintTicket> _ticketsForInstance(String instanceName, _RoomSector room) {
    final instNorm = instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return _openTickets.where((t) {
      if ((t.assignedAsset ?? '').isNotEmpty) {
        return instNorm == t.assignedAsset!.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      }
      if (!_ticketInRoom(t, room)) return false;
      if (t.assetName != null) {
        final assetNorm = t.assetName!.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        if (instNorm == assetNorm) return true;
      }
      final subject = resolveAssetSubject(_ticketHaystack(t));
      if (subject != null) return textMatchesAsset(instanceName, subject);
      return textMatchesAsset(instanceName, _ticketHaystack(t));
    }).toList();
  }

  /// FCA items linked to [inst]: exact instanceName match when set, otherwise
  /// keyword matching with the parent sector's own words subtracted.
  List<FcaItem> _fcaForInstance(_AssetInstance inst, Set<String> sectorWords) {
    final instNorm = inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return _fcaItems.where((f) {
      if (f.instanceName.isNotEmpty) {
        final fcaNorm = f.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        return instNorm == fcaNorm;
      }
      final allFcaWords = <String>{};
      for (final src in [f.ruang, f.jenis, f.kerosakan]) {
        for (final w in src.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
          if (w.length >= 2) allFcaWords.add(w);
        }
      }
      var extraWords = allFcaWords.difference(sectorWords);
      extraWords = extraWords.where((w) => w.length > 2).toSet();
      if (extraWords.isEmpty) return false;
      for (final w in inst.instanceName.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
        if (w.length >= 2 && extraWords.contains(w)) return true;
        for (final kw in extraWords) {
          if (w.contains(kw) || kw.contains(w)) return true;
        }
      }
      return false;
    }).toList();
  }

  /// Live status of one specific asset: 'down' / 'maintenance' / 'good',
  /// recomputed from the current in-memory tickets and FCA items.
  (String, List<ComplaintTicket>, List<FcaItem>) _instanceStatus(
      _AssetInstance inst, _RoomSector restrictRoom, Set<String> sectorWords) {
    final tickets = _ticketsForInstance(inst.instanceName, restrictRoom);
    final fcas = _fcaForInstance(inst, sectorWords);
    final status = tickets.any((t) => t.status == 'open') || fcas.any((f) => f.status == 'open')
      ? 'down'
      : tickets.any((t) => t.status == 'in_progress') || fcas.any((f) => f.status == 'in_progress')
        ? 'maintenance'
        : 'good';
    return (status, tickets, fcas);
  }

  /// Worst status across a type group's instances ('down' beats 'maintenance'
  /// beats 'good').
  String _groupStatus(_AssetTypeGroup g, _RoomSector restrictRoom, Set<String> sectorWords) {
    String worst = 'good';
    for (final inst in g.instances) {
      final (s, _, _) = _instanceStatus(inst, restrictRoom, sectorWords);
      if (s == 'down') return 'down';
      if (s == 'maintenance') worst = 'maintenance';
    }
    return worst;
  }

  /// True when a room label, group or instance matches any part of [haystack]
  /// (asset name, description, issue type).
  bool _roomMatches(_RoomSector room, String haystack) {
    if (textMatchesAsset(room.label, haystack)) return true;
    if (room.typeGroups != null) {
      for (final g in room.typeGroups!) {
        for (final inst in g.instances) {
          if (textMatchesAsset(inst.instanceName, haystack)) return true;
        }
      }
    }
    if (room.instances != null) {
      for (final inst in room.instances!) {
        if (textMatchesAsset(inst.instanceName, haystack)) return true;
      }
    }
    return false;
  }

  /// Combined searchable text for a complaint ticket: OCR asset reference,
  /// description and issue type, so instances match regardless of whether
  /// the complaint is written in English or Malay (e.g. "LAMPU TANDAS" or
  /// "toilet lamp" both hit the LAMP instance).
  String _ticketHaystack(ComplaintTicket t) =>
      [t.assetName ?? '', t.description, t.issueType]
          .where((s) => s.isNotEmpty)
          .join(' ');

  void _applyFcaStatuses(List<_RoomSector> rooms) {
    for (final fca in _fcaItems) {
      if (fca.instanceName.isNotEmpty) {
        final fcaNorm = fca.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        for (final room in rooms) {
          bool match = false;
          if (room.typeGroups != null) {
            for (final g in room.typeGroups!) {
              for (final inst in g.instances) {
                if (inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == fcaNorm) {
                  match = true; break;
                }
              }
              if (match) break;
            }
          }
          if (!match && room.instances != null) {
            match = room.instances!.any((inst) =>
              inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == fcaNorm);
          }
          if (match) {
            if (fca.status == 'open' && room.status != 'down') room.status = 'down';
            else if (fca.status == 'in_progress' && room.status != 'maintenance') room.status = 'maintenance';
          }
        }
        continue;
      }
      // Fall back: build keywords from ruang, jenis, kerosakan
      final keywords = <String>{};
      for (final src in [fca.ruang, fca.jenis, fca.kerosakan]) {
        for (final w in src.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
          if (w.length >= 2) keywords.add(w);
        }
      }
      bool _instMatches(String name) {
        for (final w in name.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
          if (w.length >= 2 && keywords.contains(w)) return true;
          for (final kw in keywords) {
            if (w.contains(kw) || kw.contains(w)) return true;
          }
        }
        return false;
      }
      for (final room in rooms) {
        bool match = false;
        for (final w in room.label.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
          if (w.length >= 2 && keywords.contains(w)) { match = true; break; }
          for (final kw in keywords) {
            if (w.contains(kw) || kw.contains(w)) { match = true; break; }
          }
          if (match) break;
        }
        if (!match && room.typeGroups != null) {
          for (final g in room.typeGroups!) {
            for (final inst in g.instances) {
              if (_instMatches(inst.instanceName)) { match = true; break; }
            }
            if (match) break;
          }
        }
        if (!match && room.instances != null) {
          for (final inst in room.instances!) {
            if (_instMatches(inst.instanceName)) { match = true; break; }
          }
        }
        if (match) {
          if (fca.status == 'open' && room.status != 'down') {
            room.status = 'down';
          } else if (fca.status == 'in_progress' && room.status != 'maintenance') {
            room.status = 'maintenance';
          }
        }
      }
    }
  }

  bool _fcaMatchesSector(FcaItem fca, _RoomSector room) {
    if (fca.instanceName.isNotEmpty) {
      final fcaNorm = fca.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (room.typeGroups != null) {
        for (final g in room.typeGroups!) {
          for (final inst in g.instances) {
            if (inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == fcaNorm) return true;
          }
        }
      }
      if (room.instances != null) {
        return room.instances!.any((inst) =>
          inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == fcaNorm);
      }
      return false;
    }
    final keywords = <String>{};
    for (final src in [fca.ruang, fca.jenis, fca.kerosakan]) {
      for (final w in src.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
        if (w.length >= 2) keywords.add(w);
      }
    }
    bool _instMatches(String name) {
      for (final w in name.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
        if (w.length >= 2 && keywords.contains(w)) return true;
        for (final kw in keywords) {
          if (w.contains(kw) || kw.contains(w)) return true;
        }
      }
      return false;
    }
    for (final w in room.label.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
      if (w.length >= 2 && keywords.contains(w)) return true;
      for (final kw in keywords) {
        if (w.contains(kw) || kw.contains(w)) return true;
      }
    }
    if (room.typeGroups != null) {
      for (final g in room.typeGroups!) {
        for (final inst in g.instances) {
          if (_instMatches(inst.instanceName)) return true;
        }
      }
    }
    if (room.instances != null) {
      for (final inst in room.instances!) {
        if (_instMatches(inst.instanceName)) return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statusVersion.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _fitToScreen() {
    if (_fitted || _viewSize == null) return;
    _fitted = true;
    final vw = _viewSize!.width;
    final vh = _viewSize!.height;
    final scale = math.min(vw / _planSize, vh / _planSize);
    final dx = (vw - _planSize * scale) / 2;
    final dy = (vh - _planSize * scale) / 2;
    _transformController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  void _toggleDesignMode() {
    if (_designMode) _saveDesign();
    setState(() { _designMode = !_designMode; });
  }

  void _editLabel(_RoomSector r) {
    final existing = _labelDesigns[r.label];
    final tc = TextEditingController(text: existing?.text ?? r.label);
    double rotation = existing?.rotation ?? 0;
    double fontSize = existing?.fontSize ?? 12;
    double curvature = existing?.curvature ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Label'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: tc, decoration: const InputDecoration(labelText: 'Text')),
                const SizedBox(height: 12),
                Text('Rotation: ${rotation.toStringAsFixed(0)}°'),
                Slider(value: rotation, min: -180, max: 180, onChanged: (v) => setDialogState(() { rotation = v; })),
                const SizedBox(height: 8),
                Text('Font Size: ${fontSize.toStringAsFixed(1)}'),
                Slider(value: fontSize, min: 4, max: 24, onChanged: (v) => setDialogState(() { fontSize = v; })),
                const SizedBox(height: 8),
                Text('Curvature: ${curvature.toStringAsFixed(1)}'),
                Slider(value: curvature, min: -20, max: 20, onChanged: (v) => setDialogState(() { curvature = v; })),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                _labelDesigns[r.label] = _LabelDesign(tc.text, rotation, fontSize, curvature);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDesign() async {
    final json = jsonEncode(_labelDesigns.map((k, v) => MapEntry(k, v.toJson())));
    try {
      await RepoService.writeFile('label_design.json', json);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Design saved')));
    } catch (_) {}
  }

  void _autoDesign() {
    for (final r in _rooms) {
      final a1 = r.angleStart, a2 = r.angleEnd;
      final r1 = r.radiusStart, r2 = r.radiusEnd;
      final midR = (r1 + r2) / 2;
      final thickness = (r2 - r1) * _cell;
      final angleSpan = (a2 - a1).abs();
      final chordWidth = 2 * midR * _cell * math.sin(angleSpan / 2);
      if (chordWidth < 8 || thickness < 8) continue;

      final useRadial = thickness > chordWidth;
      final textLen = r.label.length;
      double fontSize;
      double curvature;
      if (useRadial) {
        fontSize = (thickness / (textLen * 0.6)).clamp(6.0, 22.0);
        curvature = 0;
      } else {
        fontSize = (chordWidth / (textLen * 0.6)).clamp(6.0, 22.0);
        curvature = (chordWidth / 25).clamp(3.0, 18.0);
      }

      _labelDesigns[r.label] = _LabelDesign(r.label, 0, fontSize, curvature);
    }
    _saveDesign();
    if (mounted) setState(() {});
  }

  void _loadDesign() {
    RepoService.readFile('label_design.json').then((json) {
      if (json != null && mounted) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        for (final e in map.entries) {
          _labelDesigns[e.key] = _LabelDesign.fromJson(e.value);
        }
      }
    });
  }

  static String _category(String type) {
    final t = type.toLowerCase();
    if (t.contains('chiller') || t.contains('cooling tower') || t.contains('pump') ||
        t.contains('chwp') || t.contains('cdwp') || t.contains('sump') ||
        t.contains('tank') || t.contains('expansion') || t.contains('storage')) return 'heavy';
    if (t.contains('ahu') || t.contains('fcu') || t.contains('acsu') || t.contains('vav') ||
        t.contains('pac') || t.contains('fan') || t.contains('air curtain') ||
        t.contains('vrf') || t.contains('air filter') || t.contains('heat recovery') ||
        t.contains('heat exchanger') || t.contains('exhaust') || t.contains('pressurisation') ||
        t.contains('smoke spill')) return 'hvac';
    if (t.contains('db') || t.contains('panel') || t.contains('switch') || t.contains('msb') ||
        t.contains('ssb') || t.contains('acb') || t.contains('vcb') || t.contains('rmu') ||
        t.contains('metering') || t.contains('cap bank') || t.contains('genset') ||
        t.contains('solar') || t.contains('inverter') || t.contains('ups') ||
        t.contains('battery') || t.contains('photovoltaic') || t.contains('feeder') ||
        t.contains('cable') || t.contains('busduct') || t.contains('earthing') ||
        t.contains('lighting') || t.contains('luminaries') || t.contains('exit') ||
        t.contains('socket') || t.contains('sso') || t.contains('lv room') ||
        t.contains('switch room') || t.contains('tx') || t.contains('transformer')) return 'elec';
    if (t.contains('fire') || t.contains('extinguisher') || t.contains('sprinkler') ||
        t.contains('hose') || t.contains('wet riser') || t.contains('roller shutter') ||
        t.contains('alarm') || t.contains('vesda') || t.contains('smoke') ||
        t.contains('fm 200') || t.contains('wet chemical') || t.contains('lpg')) return 'fire';
    return 'other';
  }

  static String _catName(String cat) {
    // Main categories
    if (mainCategoryOrder.contains(cat)) return cat;
    // Old legacy names
    switch (cat) {
      case 'lift': return 'Lift';
      case 'staircase': return 'Staircase';
      case 'chiller': case 'heavy': return 'Heavy Mech';
      case 'hvac': return 'ACMV';
      case 'elec': return 'Electrical';
      case 'fire': return 'Fire Safety';
      case 'pump': return 'Pump';
      case 'tank': return 'Tank';
      case 'ahu': return 'AHU';
      case 'fcu': return 'FCU';
      case 'panel': return 'Panel';
      case 'fan': return 'Fan';
      default: return 'Other';
    }
  }

  // ─── Sector generation (expanded per instance) ─────────────────────

  static const _parkingFloors = {'B1', 'B2', 'P1', 'P2', 'P4A', 'P5', 'P5A', 'P6'};

  bool _isParkingFloor(String floor) => _parkingFloors.contains(floor.toUpperCase());

  /// Building-view band label → JSON floor key in me_assets_deep.json:
  /// B1→LB1, B2→LB2, P→LP1 (parking podium), M→LM, G→LG, 36→L36, …
  static String _dataFloorKey(String floor) {
    switch (floor.toUpperCase()) {
      case 'B1': return 'LB1';
      case 'B2': return 'LB2';
      case 'P': return 'LP1';
      case 'M': return 'LM';
      case 'G': return 'LG';
      default:
        return floor.startsWith('L') ? floor : 'L$floor';
    }
  }

  List<_RoomSector> _buildSectors(dynamic data) {
    // Map the building-view band label to the JSON floor key:
    // B1→LB1, B2→LB2, P→LP1, M→LM, G→LG, 36→L36, …
    final floorKey = _dataFloorKey(widget.floor);
    final items = (data is Map<String, dynamic>) ? (data[floorKey] as List?) : null;
    if (items == null || items.isEmpty) {
      return _isParkingFloor(widget.floor) ? _parkingSectors() : _fallback();
    }

    // Deep structure: entries carry {system, type, code, qty}. Group yearly
    // sectors by SYSTEM (1.0 ACMV, 2.0 Fire Fighting, …) so each circle ring
    // is a system, and type groups hold the units (CH4, CHWP5, …).
    final isDeep = items.isNotEmpty && items.first is Map && (items.first as Map).containsKey('system');
    if (isDeep) {
      return _buildDeepSectors(items);
    }

    final sectors = <_RoomSector>[];

    // Group entries by main category
    final byMainCat = <String, List<Map<String, dynamic>>>{};
    for (final entry in items) {
      final type = entry['type'] as String;
      final mc = assetToMainCat[type] ?? 'OTHER MECHANICAL';
      byMainCat.putIfAbsent(mc, () => []).add(entry);
    }

    // Count total units
    int totalQty = 0;
    for (final entry in items) {
      totalQty += entry['qty'] as int;
    }
    _floorTotal = '$totalQty units';

    // Only categories that have assets on this floor
    final presentCats = mainCategoryOrder.where((c) => byMainCat.containsKey(c)).toList();
    if (presentCats.isEmpty) return _fallback();

    final count = presentCats.length;
    final span = (math.pi * 2 - 0.3) / count;
    double start = 0.15;
    const r1 = 2.2, r2 = 6.8;

    for (final cat in presentCats) {
      final end = start + span;
      final entries = byMainCat[cat]!;

      // Build type groups
      final typeGroups = entries.map((e) {
        final type = e['type'] as String;
        final qty = e['qty'] as int;
        final itemsList = e['items'] as List?;
        List<_AssetInstance> instances;
        if (itemsList != null) {
          instances = itemsList.map((name) => _AssetInstance(name, type, cat)).toList();
        } else if (qty > 1) {
          instances = List.generate(qty, (i) => _AssetInstance('$type ${i + 1}', type, cat));
        } else {
          instances = [_AssetInstance(type, type, cat)];
        }
        return _AssetTypeGroup(type: type, mainCat: cat, instances: instances);
      }).toList();

      final sector = _RoomSector(
        angleStart: start, angleEnd: end,
        radiusStart: r1, radiusEnd: r2,
        label: cat, type: cat, status: 'good',
        typeGroups: typeGroups,
      );
      sectors.add(sector);
      start = end + 0.06;
    }

    return sectors;
  }

  /// Build the circular plan from the deep structure
  /// {system: "1.0 ACMV", type: "AIR COOLED CHILLER", code: "CH4", qty: 1}.
  /// Each system becomes one ring (circle setup), each type becomes a tap
  /// group whose instances are the unit codes (CH4, CHWP5, …).
  List<_RoomSector> _buildDeepSectors(List<dynamic> rawItems) {
    final items = rawItems.cast<Map<String, dynamic>>();

    // Group by system, preserving the numeric order of the legend
    // (1.0, 2.0, 3.0, …).
    final bySystem = <String, List<Map<String, dynamic>>>{};
    final systemNum = <String, double>{};
    for (final e in items) {
      final sys = (e['system'] as String?) ?? 'OTHER MECHANICAL';
      bySystem.putIfAbsent(sys, () => []).add(e);
      final m = RegExp(r'^(\d+)\.').firstMatch(sys);
      systemNum[sys] = m != null ? double.parse(m.group(1)!) : 999;
    }

    int totalQty = 0;
    for (final e in items) {
      totalQty += (e['qty'] as num?)?.toInt() ?? 0;
    }
    _floorTotal = '$totalQty units';

    final present = bySystem.keys.toList()
      ..sort((a, b) => systemNum[a]!.compareTo(systemNum[b]!));
    if (present.isEmpty) return _fallback();

    final count = present.length;
    final span = (math.pi * 2 - 0.3) / count;
    double start = 0.15;
    const r1 = 2.2, r2 = 6.8;

    final sectors = <_RoomSector>[];
    for (final sys in present) {
      final end = start + span;

      // Group entries by type (sub-system). A type may appear once per
      // coded unit (e.g. two AIR COOLED CHILLER rows: CH4, CH5).
      final typeGroups = <String, List<Map<String, dynamic>>>{};
      for (final e in bySystem[sys]!) {
        final type = (e['type'] as String?) ?? 'OTHER';
        typeGroups.putIfAbsent(type, () => []).add(e);
      }

      final groups = <_AssetTypeGroup>[];
      typeGroups.forEach((type, rows) {
        final instances = <_AssetInstance>[];
        for (final row in rows) {
          final qty = (row['qty'] as num?)?.toInt() ?? 1;
          final code = row['code'] as String?;
          if (code != null && code.isNotEmpty) {
            instances.add(_AssetInstance(code, type, sys));
          } else if (qty > 1) {
            for (int i = 0; i < qty; i++) {
              instances.add(_AssetInstance('$type ${i + 1}', type, sys));
            }
          } else {
            instances.add(_AssetInstance(type, type, sys));
          }
        }
        instances.sort((a, b) => a.instanceName.compareTo(b.instanceName));
        groups.add(_AssetTypeGroup(type: type, mainCat: sys, instances: instances));
      });

      final sector = _RoomSector(
        angleStart: start, angleEnd: end,
        radiusStart: r1, radiusEnd: r2,
        label: sys, type: sys, status: 'good',
        typeGroups: groups,
      );
      sectors.add(sector);
      start = end + 0.06;
    }

    return sectors;
  }

  /// Parking levels (B2–P6) have no grouped M&E data, so generate a small
  /// inventory of the assets that actually exist on parking levels (AHU/FCU/
  /// chiller/cooling tower/lifts/pumps/hose reels/boom gates/roller shutters/
  /// blind spot mirrors) and build the plan through the SAME pipeline as the
  /// real floors — grouped by main asset category (ACMV, FIRE FIGHTING, LIFT,
  /// Cold Water Supply, OTHER MECHANICAL…) sorted per [mainCategoryOrder].
  /// Parking complaints (e.g. blind spot mirror alignment) show in
  /// OTHER MECHANICAL → PARKING → BLIND SPOT MIRROR.
  List<_RoomSector> _parkingSectors() {
    return _buildSectors({
      'L${widget.floor}': [
        {'type': 'AHU', 'qty': 2},
        {'type': 'FCU', 'qty': 3},
        {'type': 'FAN', 'qty': 2},
        {'type': 'AIR COOLED CHILLER', 'qty': 1},
        {'type': 'WATER COOLED CHILLER', 'qty': 1},
        {'type': 'COOLING TOWER', 'qty': 1},
        {'type': 'HOSE REEL', 'qty': 2},
        {'type': 'LIFT', 'qty': 2},
        {'type': 'WATER PUMP', 'qty': 2},
        {'type': 'WATER TANK', 'qty': 1},
        {'type': 'ROLLER SHUTTER', 'qty': 1},
        {'type': 'BOOM GATE', 'qty': 1},
        {
          'type': 'BLIND SPOT MIRROR',
          'qty': 2,
          'items': [
            'BLIND SPOT MIRROR 1',
            'BLIND SPOT MIRROR 2',
          ],
        },
      ],
    });
  }

  List<_RoomSector> _fallback() {
    _floorTotal = null;
    final p = _mkSect;
    return [
      p(-1.3, 1.3, 0, 1.8, 'Lift', 'lift', 'good'),
      p(math.pi - 1.3, math.pi + 1.3, 0, 1.8, 'Stair', 'staircase', 'good'),
      p(0.3, math.pi * 2 / 3 - 0.3, 2.2, 3.8, 'Chiller', 'chiller', 'good'),
      p(math.pi * 2 / 3 + 0.3, math.pi * 4 / 3 - 0.3, 2.2, 3.8, 'Pump Set', 'pump', 'good'),
      p(math.pi * 4 / 3 + 0.3, math.pi * 2 - 0.3, 2.2, 3.8, 'Tank', 'tank', 'good'),
      p(0.05, math.pi * 0.5 - 0.05, 4.0, 5.2, 'AHU', 'ahu', 'good'),
      p(math.pi * 0.5 + 0.05, math.pi * 1.0 - 0.05, 4.0, 5.2, 'FCU', 'fcu', 'good'),
      p(math.pi * 1.0 + 0.05, math.pi * 1.5 - 0.05, 4.0, 5.2, 'Panel', 'panel', 'good'),
      p(math.pi * 1.5 + 0.05, math.pi * 2 - 0.05, 4.0, 5.2, 'Fan', 'fan', 'good'),
    ];
  }

  _RoomSector _mkSect(double a1, double a2, double r1, double r2, String label, String type, String status) {
    return _RoomSector(angleStart: a1, angleEnd: a2, radiusStart: r1, radiusEnd: r2, label: label, type: type, status: status);
  }

  // ─── Tap handling ─────────────────────────────────────────────────

  void _handleTap(Offset pos) {
    const size = Size(_planSize, _planSize);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rel = pos - Offset(cx, cy);
    final dist = rel.distance;
    final maxR = math.min(size.width, size.height) / 2 - _wallW * 2;
    if (dist > maxR + 4) return;

    double tapAngle = math.atan2(rel.dy, rel.dx);

    for (final room in _rooms) {
      final r1 = room.radiusStart * _cell;
      final r2 = room.radiusEnd * _cell;
      if (dist < r1 || dist > r2) continue;

      double a = (tapAngle + 2 * math.pi) % (2 * math.pi);
      double s = (room.angleStart + 2 * math.pi) % (2 * math.pi);
      double e = (room.angleEnd + 2 * math.pi) % (2 * math.pi);

      bool inAngle;
      if (s <= e) {
        inAngle = a >= s && a <= e;
      } else {
        inAngle = a >= s || a <= e;
      }
      if (inAngle) {
        if (_designMode) {
          _editLabel(room);
        } else if (room.typeGroups != null && room.typeGroups!.isNotEmpty) {
          _showAssetTypeList(room);
        } else if (room.instances != null && room.instances!.isNotEmpty) {
          _showInstanceView(room);
        } else {
          _showDetail(room);
        }
        return;
      }
    }
  }

  void _showInstanceView(_RoomSector room, {_RoomSector? roomContext}) {
    final eng = LanguageProvider.isEnglish(context);
    // Sector used for ticket room-restriction: when a type-group view opens
    // this screen, its label is the asset type ("LAMP"), so pass the parent
    // sector down so tickets are still restricted to their own room.
    final restrictRoom = roomContext ?? room;
    // Compute the sector's own keywords so FCA instance matching subtracts them
    final sectorWords = room.label.toLowerCase().split(RegExp(r'[\s\(\)/,]+')).where((w) => w.length >= 2).toSet();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${room.label} · ${room.instances!.length} ${eng ? "units" : "unit"}'),
          ),
          // Rebuild on every status change so cards flip live while this
          // screen is on screen.
          body: AnimatedBuilder(
            animation: _statusVersion,
            builder: (_, __) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: room.instances!.map((inst) {
                  final (status, tickets, fcaForInstance) = _instanceStatus(inst, restrictRoom, sectorWords);
                  final color = _statusColor(status);
                  final w = (MediaQuery.of(ctx).size.width - 44) / 2;
                  return GestureDetector(
                    onTap: () => _showInstanceDetail(ctx, inst, restrictRoom, sectorWords, room.type, eng),
                    child: Container(
                      width: w,
                      height: 110,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(inst.instanceName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text(_statusLabel(status, eng), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                          ),
                          if (tickets.isNotEmpty || fcaForInstance.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('${tickets.length} ${eng ? "ticket(s)" : "tiket"}${fcaForInstance.isNotEmpty ? " · ${fcaForInstance.length} FCA" : ""}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    ));
  }

  void _showAssetTypeList(_RoomSector catSector) {
    final eng = LanguageProvider.isEnglish(context);
    // 9.0 Other Mechanical gets a TOILETS / ROLLER SHUTTER / GREY WATER /
    // RAIN WATER / OTHER sub-category layer before the raw type groups.
    final groups = catSector.typeGroups!;
    if (catSector.label.startsWith('9.0')) {
      _showNineSubcategories(catSector, groups, eng);
      return;
    }
    _pushTypeGroupPage(catSector, groups, catSector.label, eng);
  }

  /// Sub-category assignment for items inside the "9.0 Other Mechanical
  /// Equipment System" ring. Toilet/sanitary equipment (hand dryers, exhaust
  /// fans, WC, basins, …) lives under TOILETS; roller shutters, grey water,
  /// rain water and anything else get their own group so the plan reads the
  /// way the asset register groups them.
  static String _nineSubcategory(String type) {
    final u = type.toUpperCase();
    if (u.contains('ROLLER SHUTTER')) return 'roller';
    if (u.contains('GREY')) return 'grey';
    if (u.contains('RAIN')) return 'rain';
    const toiletKeys = [
      'WC', 'URINAL', 'BASIN', 'BIDET', 'SHOWER', 'TAP', 'SOAP',
      'HAND DRYER', 'EXHAUST FAN', 'FLUSH', 'TOWEL', 'RAIL', 'HOOK',
      'MOP', 'GRAB BAR', 'MIRROR', 'RUBBISH', 'GRATING', 'MODESTY',
      'PAPER', 'BABY CHANGE', 'ACCESSORY',
    ];
    if (toiletKeys.any((k) => u.contains(k))) return 'toilets';
    return 'other';
  }

  /// Collapses item groups that only differ by a trailing (M)/(F)/(D) unit
  /// suffix (e.g. "EXHAUST FAN (M)", "(F)", "(D)" -> one "EXHAUST FAN" card
  /// whose instances still carry the original names).
  static List<_AssetTypeGroup> _mergeTypeGroups(List<_AssetTypeGroup> groups) {
    final merged = <String, _AssetTypeGroup>{};
    final order = <String>[];
    for (final g in groups) {
      final base = g.type.replaceFirst(RegExp(r'\s*\([A-Z]\)$'), '').trim();
      final existing = merged[base];
      if (existing == null) {
        merged[base] = _AssetTypeGroup(type: base, mainCat: g.mainCat, instances: [...g.instances]);
        order.add(base);
      } else {
        existing.instances.addAll(g.instances);
      }
    }
    return [for (final k in order) merged[k]!];
  }

  void _showNineSubcategories(_RoomSector catSector, List<_AssetTypeGroup> groups, bool eng) {
    const cats = [
      ('toilets', 'TOILETS', 'Tandas', Icons.wc_rounded),
      ('roller', 'ROLLER SHUTTER', 'Gulung Aswara', Icons.curtains_rounded),
      ('grey', 'GREY WATER', 'Air Kelabu', Icons.water_drop_rounded),
      ('rain', 'RAIN WATER', 'Air Hujan', Icons.umbrella_rounded),
      ('other', 'OTHER MECHANICAL', 'Lain-lain Mekanikal', Icons.settings_rounded),
    ];
    final buckets = <String, List<_AssetTypeGroup>>{};
    for (final g in groups) {
      buckets.putIfAbsent(_nineSubcategory(g.type), () => []).add(g);
    }
    final present = cats.where((c) => (buckets[c.$1] ?? []).isNotEmpty).toList();
    final totalUnits = groups.fold<int>(0, (sum, g) => sum + g.instances.length);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) {
        return Scaffold(
          appBar: AppBar(
            title: Text(catSector.label),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_book_rounded),
                tooltip: eng ? 'Glossary' : 'Glosari',
                onPressed: () => showGlossary(context),
              ),
            ],
          ),
          body: AnimatedBuilder(
            animation: _statusVersion,
            builder: (_, __) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eng ? 'Select a sub-category' : 'Pilih sub-kategori',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 10),
                  for (final (id, en, bm, icon) in present) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        borderRadius: BorderRadius.circular(16),
                        elevation: 1,
                        shadowColor: Colors.black.withValues(alpha: 0.06),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _pushTypeGroupPage(
                            catSector,
                            buckets[id]!,
                            eng ? en : bm,
                            eng,
                            mergeUnits: true,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D7377).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(icon, color: const Color(0xFF0D7377), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(eng ? en : bm,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${buckets[id]!.fold<int>(0, (s, g) => s + g.instances.length)} '
                                        '${eng ? 'unit(s)' : 'unit'}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('${groups.length} ${eng ? 'item groups' : 'kumpulan item'} · $totalUnits unit',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        );
      },
    ));
  }

  /// Generic page listing `_AssetTypeGroup` cards (used both for a whole
  /// system and for a single 9.0 sub-category).
  void _pushTypeGroupPage(_RoomSector catSector, List<_AssetTypeGroup> groups, String title, bool eng,
      {bool mergeUnits = false}) {
    final sectorWords = catSector.label.toLowerCase().split(RegExp(r'[\s\(\)/,]+')).where((w) => w.length >= 2).toSet();
    final cards = mergeUnits ? _mergeTypeGroups(groups) : groups;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) {
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_book_rounded),
                tooltip: eng ? 'Glossary' : 'Glosari',
                onPressed: () => showGlossary(context),
              ),
            ],
          ),
          // Rebuild on every status change so group chips flip live.
          body: AnimatedBuilder(
            animation: _statusVersion,
            builder: (_, __) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cards.map((g) {
                  final gStatus = _groupStatus(g, catSector, sectorWords);
                  final color = _statusColor(gStatus);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      elevation: 1,
                      shadowColor: Colors.black.withValues(alpha: 0.06),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Wrap instances into a temporary _RoomSector for reuse
                          final tmp = _RoomSector(
                            angleStart: 0, angleEnd: 0,
                            radiusStart: 0, radiusEnd: 0,
                            label: g.type, type: catSector.type,
                            status: gStatus,
                            instances: g.instances,
                          );
                          _showInstanceView(tmp, roomContext: catSector);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42, height: 42,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(_iconForType(g.type), color: color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(g.type, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 2),
                                          Text('${g.instances.length} ${eng ? "unit(s)" : "unit"}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        gStatus == 'good' ? (eng ? 'OK' : 'Baik') :
                                        gStatus == 'down' ? (eng ? 'Down' : 'Rosak') :
                                        (eng ? 'Maint' : 'Senggara'),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    ));
  }

  /// FCA items belonging to this sector (exact instance match, else word
  /// match against the sector label).
  List<FcaItem> _fcaForSector(_RoomSector room) {
    return _fcaItems.where((f) {
      if (f.instanceName.isNotEmpty) {
        final fcaNorm = f.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        // Check typeGroups first
        if (room.typeGroups != null) {
          for (final g in room.typeGroups!) {
            for (final inst in g.instances) {
              if (inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == fcaNorm) return true;
            }
          }
        }
        // Then check instances
        if (room.instances != null) {
          return room.instances!.any((inst) =>
            inst.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == fcaNorm);
        }
        return false;
      }
      // Fall back: word-level match against sector label
      final words = <String>{};
      for (final src in [f.ruang, f.jenis, f.kerosakan]) {
        for (final w in src.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
          if (w.length >= 2) words.add(w);
        }
      }
      for (final w in room.label.toLowerCase().split(RegExp(r'[\s\(\)/,]+'))) {
        if (w.length >= 2 && words.contains(w)) return true;
        for (final kw in words) { if (w.contains(kw) || kw.contains(w)) return true; }
      }
      return false;
    }).toList();
  }

  void _showDetail(_RoomSector room) {
    _showDetailSheet(context, room.label, room.type, room.status, room.color, room.linkedTickets,
      recompute: () => (
        status: room.status,
        color: room.color,
        tickets: room.linkedTickets,
        fcaItems: _fcaForSector(room),
      ));
  }

  void _showInstanceDetail(BuildContext ctx, _AssetInstance inst, _RoomSector restrictRoom, Set<String> sectorWords, String type, bool eng) {
    _showDetailSheet(ctx, inst.instanceName, type, 'good', _statusColor('good'), const [], canEdit: true,
      recompute: () {
        final (status, tickets, fcaItems) = _instanceStatus(inst, restrictRoom, sectorWords);
        return (status: status, color: _statusColor(status), tickets: tickets, fcaItems: fcaItems);
      });
  }

  void _showDetailSheet(BuildContext ctx, String label, String type, String status, Color color, List<ComplaintTicket> tickets, {List<FcaItem> fcaItems = const [], bool canEdit = false, _DetailRecompute? recompute}) {
    final eng = LanguageProvider.isEnglish(ctx);
    final hasFca = fcaItems.isNotEmpty;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: tickets.isNotEmpty || hasFca ? 0.7 : 0.35,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        // Rebuild on every status change so the header chip, linked tickets
        // and FCA list stay live while the sheet is open.
        builder: (sheetCtx, scrollCtrl) => AnimatedBuilder(
          animation: _statusVersion,
          builder: (_, __) {
            final live = recompute?.call();
            final st = live?.status ?? status;
            final col = live?.color ?? color;
            final tk = live?.tickets ?? tickets;
            final fc = live?.fcaItems ?? fcaItems;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(child: Container(margin: const EdgeInsets.only(top: 4, bottom: 12), width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_iconForType(type), color: col, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(type == 'lift' || type == 'staircase' ? '' : _catName(type),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(_statusLabel(st, eng),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: col)),
                    ),
                    if (canEdit) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        tooltip: eng ? 'Edit status / related issues' : 'Ubah status / isu berkaitan',
                        onPressed: () => _showInstanceEditSheet(ctx, label, type, eng),
                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF0D7377)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('${eng ? "Floor" : "Aras"} ${widget.floor}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.category_rounded, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('${eng ? "Category" : "Kategori"}: ${_catName(type)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),

                  if (tk.isNotEmpty) ...[
                    const SizedBox(height: 16), const Divider(height: 1), const SizedBox(height: 12),
                    Text(eng ? 'Related Complaints (${tk.length})' : 'Aduan Berkaitan (${tk.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...tk.map((t) => _complaintCard(t, eng, sheetCtx)),
                  ],
                  if (fc.isNotEmpty) ...[
                    const SizedBox(height: 16), const Divider(height: 1), const SizedBox(height: 12),
                    Text(eng ? 'FCA Issues (${fc.length})' : 'Isu FCA (${fc.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...fc.map((f) => _fcaCard(f, eng)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Per-asset edit: change the status of the linked complaint/FCA issues and
  /// choose which complaint/FCA issue relates to this specific asset.
  void _showInstanceEditSheet(BuildContext ctx, String instName, String type, bool eng) {
    final instNorm = instName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final catName = _catName(type);
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Center(child: Container(margin: const EdgeInsets.only(top: 4, bottom: 12), width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  Row(children: [
                    Expanded(child: Text(instName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: eng ? 'Close' : 'Tutup',
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]),
                  Text('$catName · ${eng ? 'Floor' : 'Aras'} ${widget.floor}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  Text(eng ? 'Complaints on this floor' : 'Aduan di aras ini',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (_openTickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(eng ? 'No open complaints.' : 'Tiada aduan terbuka.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ),
                  ..._openTickets.map((t) => _editTicketRow(t, instNorm, instName, eng, setSheet, sheetCtx)),
                  const SizedBox(height: 16),
                  Text(eng ? 'FCA issues on this floor' : 'Isu FCA di aras ini',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (_fcaItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(eng ? 'No FCA issues.' : 'Tiada isu FCA.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ),
                  ..._fcaItems.map((f) => _editFcaRow(f, instNorm, instName, eng, setSheet, sheetCtx)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _editTicketRow(ComplaintTicket t, String instNorm, String instName, bool eng, StateSetter setSheet, BuildContext sheetCtx) {
    final linked = (t.assignedAsset ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '') == instNorm;
    return Row(
      children: [
        Checkbox(
          value: linked,
          visualDensity: VisualDensity.compact,
          onChanged: (v) async {
            final ok = await ComplaintService.update(
              t.id,
              clearAssignedAsset: v != true,
              assignedAsset: v == true ? instName : null,
            );
            if (!ok) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(eng ? 'Failed — check network' : 'Gagal — periksa rangkaian'),
                  backgroundColor: const Color(0xFFEF4444),
                ));
              }
              return;
            }
            _replaceTicketLocally(
              t.copyWith(assignedAsset: v == true ? instName : null, clearAssignedAsset: v != true));
            _applyAllStatuses();
            if (mounted) setState(() {});
            if (sheetCtx.mounted) setSheet(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(v == true
                  ? '${eng ? "Linked to" : "Dikaitkan ke"} $instName'
                  : (eng ? 'Unlinked' : 'Dilepaskan')),
              backgroundColor: const Color(0xFF0D7377),
              duration: const Duration(seconds: 1),
            ));
          },
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#${t.seqId} ${t.issueType}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(t.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (linked)
          DropdownButton<String>(
            value: t.status,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0D7377), fontWeight: FontWeight.w700),
            items: ['open', 'in_progress', 'resolved'].map((s) => DropdownMenuItem(
              value: s,
              child: Text(s == 'open' ? (eng ? 'Open' : 'Baru')
                  : s == 'in_progress' ? (eng ? 'In Progress' : 'Dalam Kerja')
                  : (eng ? 'Resolved' : 'Selesai')),
            )).toList(),
            onChanged: (v) async {
              if (v == null || v == t.status) return;
              final ok = await ComplaintService.update(t.id, status: v);
              if (!ok) return;
              _replaceTicketLocally(t.copyWith(status: v));
              _applyAllStatuses();
              if (mounted) setState(() {});
              if (sheetCtx.mounted) setSheet(() {});
            },
          ),
      ],
    );
  }

  Widget _editFcaRow(FcaItem f, String instNorm, String instName, bool eng, StateSetter setSheet, BuildContext sheetCtx) {
    final linked = f.instanceName.toLowerCase().replaceAll(RegExp(r'\s+'), '') == instNorm;
    return Row(
      children: [
        Checkbox(
          value: linked,
          visualDensity: VisualDensity.compact,
          onChanged: (v) async {
            f.instanceName = v == true ? instName : '';
            final ok = await RepoService.updateFcaItem(f);
            if (!ok) {
              f.instanceName = v == true ? '' : instName;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(eng ? 'Failed — check network' : 'Gagal — periksa rangkaian'),
                  backgroundColor: const Color(0xFFEF4444),
                ));
              }
              return;
            }
            _applyAllStatuses();
            if (mounted) setState(() {});
            if (sheetCtx.mounted) setSheet(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(v == true
                  ? '${eng ? "Linked to" : "Dikaitkan ke"} $instName'
                  : (eng ? 'Unlinked' : 'Dilepaskan')),
              backgroundColor: const Color(0xFF0D7377),
              duration: const Duration(seconds: 1),
            ));
          },
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#${f.bil} ${f.kerosakan}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${f.ruang} · ${f.jenis}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (linked)
          DropdownButton<String>(
            value: f.status,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0D7377), fontWeight: FontWeight.w700),
            items: ['open', 'in_progress', 'closed'].map((s) => DropdownMenuItem(
              value: s,
              child: Text(s == 'open' ? (eng ? 'Open' : 'Baru')
                  : s == 'in_progress' ? (eng ? 'In Progress' : 'Dalam Kerja')
                  : (eng ? 'Closed' : 'Selesai')),
            )).toList(),
            onChanged: (v) async {
              if (v == null || v == f.status) return;
              final prev = f.status;
              f.status = v;
              final ok = await RepoService.updateFcaItem(f);
              if (!ok) {
                f.status = prev;
                return;
              }
              _applyAllStatuses();
              if (mounted) setState(() {});
              if (sheetCtx.mounted) setSheet(() {});
            },
          ),
      ],
    );
  }

  Widget _complaintCard(ComplaintTicket t, bool eng, BuildContext ctx) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.status == 'open' ? const Color(0xFFEF4444).withValues(alpha: 0.15) :
                          t.status == 'in_progress' ? const Color(0xFFF59E0B).withValues(alpha: 0.15) :
                          const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('#${t.seqId}',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: t.status == 'open' ? const Color(0xFFEF4444) :
                           t.status == 'in_progress' ? const Color(0xFFF59E0B) :
                           const Color(0xFF22C55E),
                  )),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(t.issueType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.status == 'open' ? const Color(0xFFEF4444) :
                         t.status == 'in_progress' ? const Color(0xFFF59E0B) :
                         const Color(0xFF22C55E),
                ),
              ),
            ]),
            if (t.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(t.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            if ((t.assignedAsset ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.push_pin_rounded, size: 11, color: Color(0xFF0D7377)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text('${eng ? "Assigned to" : "Disemat ke"}: ${t.assignedAsset}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0D7377)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            if (t.evidenceFile != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showEvidence(t.evidenceFile!, eng),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 140,
                    child: _EvidenceImage(path: t.evidenceFile!),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline, size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(t.complainerName, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              const Spacer(),
              Text(_formatDate(t.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ],
        ),
      ),
    );
  }

  static const String _fcaImageBase = 'https://raw.githubusercontent.com/wukongfantastic5-droid/Database-JKR/main/fca_images/';

  Widget _fcaCard(FcaItem f, bool eng) {
    final hasImage = f.imageFile.isNotEmpty;
    final imageUrl = '$_fcaImageBase${f.imageFile}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: f.status == 'open' ? const Color(0xFFEF4444).withValues(alpha: 0.15) :
                          const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('#${f.bil}',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: f.status == 'open' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                  )),
              ),
              if (f.displayAssetType.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7377).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(f.displayAssetType, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFF0D7377))),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(child: Text(f.ruang, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: f.priority == 'high' ? const Color(0xFFDC2626).withValues(alpha: 0.12) :
                          f.priority == 'low' ? const Color(0xFF3B82F6).withValues(alpha: 0.12) :
                          const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  f.priorityLabel,
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: f.priority == 'high' ? const Color(0xFFDC2626) :
                           f.priority == 'low' ? const Color(0xFF3B82F6) :
                           const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: f.status == 'open' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(f.kerosakan, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (f.instanceName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.link_rounded, size: 11, color: Colors.indigo.shade400),
                const SizedBox(width: 3),
                Expanded(child: Text(f.instanceName, style: TextStyle(fontSize: 10, color: Colors.indigo.shade500, fontWeight: FontWeight.w500))),
              ]),
            ],
            if (f.jkrRequest.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.description_rounded, size: 11, color: Colors.blue.shade400),
                const SizedBox(width: 3),
                Text('JKR: ${f.jkrRequest}', style: TextStyle(fontSize: 10, color: Colors.blue.shade500)),
              ]),
            ],
            if (hasImage) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showFcaImage(imageUrl, eng),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      color: Colors.grey.shade100,
                      child: Center(child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32)),
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(height: 120, color: Colors.grey.shade50, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFcaImage(String url, bool eng) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, title: const Text('')),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Center(child: Text(eng ? 'Image not found' : 'Gambar tidak ditemui', style: const TextStyle(color: Colors.white)))),
          ),
        ),
      ),
    ));
  }

  void _showEvidence(String path, bool eng) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, title: const Text('')),
        body: Center(child: _EvidenceImage(path: path, fullscreen: true)),
      ),
    ));
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  IconData _iconForType(String type) {
    // Main categories
    if (mainCatIcons.containsKey(type)) return mainCatIcons[type]!;
    switch (type) {
      case 'lift': return Icons.elevator_rounded;
      case 'staircase': return Icons.stairs_rounded;
      case 'chiller': case 'heavy': return Icons.ac_unit_rounded;
      case 'cooling_tower': case 'tank': return Icons.water_drop_rounded;
      case 'pump': return Icons.water_drop_rounded;
      case 'ahu': case 'hvac': return Icons.air_rounded;
      case 'fcu': return Icons.ac_unit_rounded;
      case 'panel': case 'elec': return Icons.electrical_services_rounded;
      case 'fire': return Icons.fire_extinguisher_rounded;
      default: return Icons.inventory_2_rounded;
    }
  }

  String _statusLabel(String status, bool eng) {
    switch (status) {
      case 'good': return eng ? 'Good' : 'Baik';
      case 'down': return eng ? 'Down' : 'Rosak';
      case 'maintenance': return eng ? 'Maintenance' : 'Senggara';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'good': return const Color(0xFF22C55E);
      case 'down': return const Color(0xFFEF4444);
      case 'maintenance': return const Color(0xFFF59E0B);
      default: return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: Text('${eng ? "Floor" : "Aras"} ${widget.floor} — M&E'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: eng ? 'Glossary' : 'Glosari',
            onPressed: () => showGlossary(context),
          ),
          IconButton(
            icon: Icon(_designMode ? Icons.design_services : Icons.design_services_outlined, color: _designMode ? Colors.amber : null),
            tooltip: 'Toggle Design Mode',
            onPressed: _toggleDesignMode,
          ),
          if (_designMode)
            IconButton(
              icon: const Icon(Icons.auto_fix_high, color: Colors.amber),
              tooltip: 'Auto Design All',
              onPressed: _autoDesign,
            ),
          if (_designMode)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.amber),
              tooltip: 'Save Design',
              onPressed: _saveDesign,
            ),
          if (_floorTotal != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text(_floorTotal!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              ),
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _rooms.isEmpty
            ? Center(child: Text(eng ? 'No assets' : 'Tiada aset', style: TextStyle(color: Colors.grey.shade500)))
            : LayoutBuilder(
                builder: (ctx, constraints) {
                  _viewSize = constraints.biggest;
                  if (!_fitted) WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
                  return GestureDetector(
                    onTapDown: (details) {
                      final inv = Matrix4.inverted(_transformController.value);
                      final childPos = MatrixUtils.transformPoint(inv, details.localPosition);
                      _handleTap(childPos);
                    },
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.2,
                      maxScale: 4.0,
                      constrained: false,
                      child: SizedBox(
                        width: _planSize,
                        height: _planSize,
                        child: CustomPaint(
                          painter: _CircularPlanPainter(rooms: _rooms, isDark: isDark, labelDesigns: _labelDesigns),
                          size: const Size(_planSize, _planSize),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

// ─── Data classes ───────────────────────────────────────────────────────────

// ─── 9 main category definitions ──────────────────────────────────────

const List<String> mainCategoryOrder = [
  'ACMV', 'FIRE FIGHTING', 'LIFT', 'GONDOLA',
  'Cold Water Supply', 'Inspection Above Ceiling',
  'Kitchen Equipment', 'IRRIGATION SYSTEM', 'OTHER MECHANICAL',
];

const Map<String, IconData> mainCatIcons = {
  'ACMV': Icons.ac_unit_rounded,
  'FIRE FIGHTING': Icons.fire_extinguisher_rounded,
  'LIFT': Icons.elevator_rounded,
  'GONDOLA': Icons.precision_manufacturing_rounded,
  'Cold Water Supply': Icons.water_drop_rounded,
  'Inspection Above Ceiling': Icons.visibility_rounded,
  'Kitchen Equipment': Icons.restaurant_rounded,
  'IRRIGATION SYSTEM': Icons.grass_rounded,
  'OTHER MECHANICAL': Icons.build_circle_rounded,
};

const Map<String, String> assetToMainCat = {
  // ACMV
  'AHU': 'ACMV', 'FCU': 'ACMV', 'VRF': 'ACMV', 'VAV': 'ACMV',  'VSD': 'ACMV', 'PAC': 'ACMV', 'ACSU': 'ACMV', 'CHWP': 'ACMV',
  'HEAT EXCHANGER': 'ACMV', 'HEAT RECOVERY WHEEL': 'ACMV',
  'COOLING TOWER': 'ACMV', 'AIR COOLED CHILLER': 'ACMV',
  'CHILLER': 'ACMV', 'CHILLER PUMP': 'ACMV', 'WATER CHILLER': 'ACMV',
  'WATER COOLED CHILLER': 'ACMV',
  'AIR CURTAIN': 'ACMV', 'FAN': 'ACMV', 'AIR FILTER': 'ACMV',
  'EL': 'ACMV', 'REFRIGERANT LEAK DETECTOR': 'ACMV',
  // Fire Fighting
  'FIRE FIGHTING': 'FIRE FIGHTING', 'FM 200': 'FIRE FIGHTING',
  'VESDA': 'FIRE FIGHTING', 'SPRINKLER PUMP': 'FIRE FIGHTING',
  'SPRINKLER CONTROL PANEL': 'FIRE FIGHTING',
  'HOSE REEL PUMP': 'FIRE FIGHTING',
  'HOSE REEL PUMP CONTROL PANEL': 'FIRE FIGHTING',
  'HOSE REEL': 'FIRE FIGHTING',
  'HYDRANT PILLAR': 'FIRE FIGHTING',
  'WET RISER PUMP': 'FIRE FIGHTING',
  'WET RISER CONTROL PANEL': 'FIRE FIGHTING',
  'WET CHEMICAL SYSTEM': 'FIRE FIGHTING',
  // Lift
  'LIFT': 'LIFT', 'LIFT HIGHZONE': 'LIFT', 'LIFT LOWZONE': 'LIFT',
  // Gondola
  'GONDOLA': 'GONDOLA',
  // Cold Water Supply & Booster Pump
  'WATER PUMP': 'Cold Water Supply',
  'COLD WATER PUMP': 'Cold Water Supply',
  'DOMESTIC COLD WATER BOOSTER PUMP': 'Cold Water Supply',
  'WATER TANK': 'Cold Water Supply',
  'WATER FILTER': 'Cold Water Supply',
  'WATER TREATMENT': 'Cold Water Supply',
  // Kitchen Equipment
  'KITCHEN EXHAUST HOOD': 'Kitchen Equipment',
  // OTHER MECHANICAL — everything else
  'PARKING': 'OTHER MECHANICAL',
  'BLIND SPOT MIRROR': 'OTHER MECHANICAL',
  'TANDAS': 'OTHER MECHANICAL',
  'ROLLER SHUTTER': 'OTHER MECHANICAL',
  'HAND DRYER': 'OTHER MECHANICAL',
  'PANIC BUTTON': 'OTHER MECHANICAL',
  'INSTANT WATER HEATER': 'OTHER MECHANICAL',
  'AUDIO VISUAL': 'OTHER MECHANICAL',
  'VISUAL PROJECTION': 'OTHER MECHANICAL',
  'SMATV': 'OTHER MECHANICAL',
  'PABX': 'OTHER MECHANICAL',
  'BOOM GATE': 'OTHER MECHANICAL',
  'EXIT SIGN': 'OTHER MECHANICAL',
  'LIGHTING': 'OTHER MECHANICAL',
  'GRID CONNECTED PHOTOVOLTAIC(PV)': 'OTHER MECHANICAL',
  'SOLAR INVERTER': 'OTHER MECHANICAL',
  'METERING (VOLT & AMPS)': 'OTHER MECHANICAL',
  'CAP BANK': 'OTHER MECHANICAL',
  'DB': 'OTHER MECHANICAL', 'MSB': 'OTHER MECHANICAL',
  'SSB': 'OTHER MECHANICAL', 'RMU': 'OTHER MECHANICAL',
  'TX': 'OTHER MECHANICAL', 'UPS': 'OTHER MECHANICAL',
  'ACB': 'OTHER MECHANICAL', 'S/S/O': 'OTHER MECHANICAL',
  'LV ROOM': 'OTHER MECHANICAL',
  'SWITCH ROOM HV': 'OTHER MECHANICAL',
  'SYSTEM': 'OTHER MECHANICAL',
};

class _AssetTypeGroup {
  final String type;
  final String mainCat;
  List<_AssetInstance> instances;
  String status;

  _AssetTypeGroup({
    required this.type,
    required this.mainCat,
    required this.instances,
    this.status = 'good',
  });
}

class _AssetInstance {
  final String instanceName;
  final String baseType;
  final String cat;
  const _AssetInstance(this.instanceName, this.baseType, this.cat);
}

class _RoomSector {
  final double angleStart, angleEnd, radiusStart, radiusEnd;
  final String label, type;
  String status;
  Path? cachedPath;
  final List<ComplaintTicket> linkedTickets = [];
  List<_AssetInstance>? instances;
  List<_AssetTypeGroup>? typeGroups;
  int issueCount = 0;

  _RoomSector({
    required this.angleStart, required this.angleEnd,
    required this.radiusStart, required this.radiusEnd,
    required this.label, required this.type,
    required this.status,
    this.instances,
    this.typeGroups,
  });

  Color get color {
    switch (status) {
      case 'good': return const Color(0xFF22C55E);
      case 'down': return const Color(0xFFEF4444);
      case 'maintenance': return const Color(0xFFF59E0B);
      default: return const Color(0xFF94A3B8);
    }
  }
}

// ─── Evidence image widget ──────────────────────────────────────────────────

class _EvidenceImage extends StatefulWidget {
  final String path;
  final bool fullscreen;
  const _EvidenceImage({required this.path, this.fullscreen = false});

  @override
  State<_EvidenceImage> createState() => _EvidenceImageState();
}

class _EvidenceImageState extends State<_EvidenceImage> {
  String? _b64;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b64 = await ComplaintService.getEvidenceBase64(widget.path);
    if (mounted) setState(() { _b64 = b64; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_b64 == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.grey.shade400, size: 32),
            const SizedBox(height: 4),
            Text('Failed', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.fullscreen ? 0 : 8),
      child: Image.memory(
        base64Decode(_b64!),
        width: widget.fullscreen ? double.infinity : null,
        height: widget.fullscreen ? double.infinity : null,
        fit: widget.fullscreen ? BoxFit.contain : BoxFit.cover,
      ),
    );
  }
}

// ─── Painter ────────────────────────────────────────────────────────────────

class _CircularPlanPainter extends CustomPainter {
  final List<_RoomSector> rooms;
  final bool isDark;
  final Map<String, _LabelDesign> labelDesigns;

  _CircularPlanPainter({required this.rooms, required this.isDark, this.labelDesigns = const {}});

  Color get _bg => isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F0E8);
  Color get _grid => isDark ? const Color(0xFF2A2A4E) : const Color(0xFFE0D8CC);
  Color get _wall => isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2C2C2C);
  Color get _wallFill => isDark ? const Color(0xFF2A2A3E) : const Color(0xFFFFF8EE);
  Color get _label => Colors.white;
  Color get _labelShadow => isDark ? const Color(0x40000000) : const Color(0x60000000);

  late double _cx, _cy, _radius;

  @override
  void paint(Canvas canvas, Size size) {
    _cx = size.width / 2;
    _cy = size.height / 2;
    _radius = math.min(size.width, size.height) / 2 - _wallW * 2;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(_cx, _cy), radius: _radius + _wallW)));

    _drawBg(canvas, size);
    _drawPolarGrid(canvas);
    _drawRoomFills(canvas);
    _drawIssueBadges(canvas);
    _drawWalls(canvas);
    _drawPerimeter(canvas);
    _drawLabels(canvas);

    canvas.restore();
  }

  void _drawBg(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    canvas.drawOval(
      Rect.fromCircle(center: Offset(_cx, _cy), radius: _radius + _wallW),
      Paint()..color = _wallFill,
    );
  }

  void _drawPolarGrid(Canvas canvas) {
    final paint = Paint()..color = _grid..strokeWidth = 0.5;
    for (double r = 1; r <= _radius / _cell; r += 1) {
      canvas.drawCircle(Offset(_cx, _cy), r * _cell, paint);
    }
    for (int i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      canvas.drawLine(
        Offset(_cx, _cy),
        Offset(_cx + _radius * math.cos(angle), _cy + _radius * math.sin(angle)),
        paint,
      );
    }
  }

  Path _sectorPath(_RoomSector r) {
    final a1 = r.angleStart, a2 = r.angleEnd;
    final r1 = r.radiusStart * _cell, r2 = r.radiusEnd * _cell;
    final path = Path();
    if (r1 < 1) {
      path.moveTo(_cx, _cy);
      path.lineTo(_cx + r2 * math.cos(a1), _cy + r2 * math.sin(a1));
      path.arcTo(Rect.fromCircle(center: Offset(_cx, _cy), radius: r2), a1, a2 - a1, false);
      path.close();
    } else {
      path.moveTo(_cx + r2 * math.cos(a1), _cy + r2 * math.sin(a1));
      path.arcTo(Rect.fromCircle(center: Offset(_cx, _cy), radius: r2), a1, a2 - a1, false);
      path.lineTo(_cx + r1 * math.cos(a2), _cy + r1 * math.sin(a2));
      path.arcTo(Rect.fromCircle(center: Offset(_cx, _cy), radius: r1), a2, a1 - a2, false);
      path.close();
    }
    return path;
  }

  bool _pointInSector(Offset pt, _RoomSector r) {
    final dx = pt.dx - _cx;
    final dy = pt.dy - _cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final minR = r.radiusStart * _cell;
    final maxR = r.radiusEnd * _cell;
    if (dist < minR || dist > maxR) return false;
    double a = (math.atan2(dy, dx) + 2 * math.pi) % (2 * math.pi);
    double s = (r.angleStart + 2 * math.pi) % (2 * math.pi);
    double e = (r.angleEnd + 2 * math.pi) % (2 * math.pi);
    if (s <= e) return a >= s && a <= e;
    return a >= s || a <= e;
  }

  void _drawRoomFills(Canvas canvas) {
    for (final r in rooms) {
      canvas.drawPath(_sectorPath(r), Paint()..color = r.color.withValues(alpha: 0.25));
    }
  }

  void _drawIssueBadges(Canvas canvas) {
    for (final r in rooms) {
      if (r.issueCount <= 1) continue;
      final midA = (r.angleStart + r.angleEnd) / 2;
      final rPos = r.radiusEnd * _cell - 18;
      final px = _cx + rPos * math.cos(midA);
      final py = _cy + rPos * math.sin(midA);
      const badgeR = 12.0;
      canvas.drawCircle(Offset(px, py), badgeR, Paint()..color = const Color(0xFFEF4444));
      canvas.drawCircle(Offset(px, py), badgeR, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
      final tp = TextPainter(
        text: TextSpan(
          text: r.issueCount.toString(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(px - tp.width / 2, py - tp.height / 2));
    }
  }

  void _drawWalls(Canvas canvas) {
    for (final r in rooms) {
      canvas.drawPath(
        _sectorPath(r),
        Paint()..color = r.color..strokeWidth = _wallW..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawPerimeter(Canvas canvas) {
    canvas.drawCircle(
      Offset(_cx, _cy), _radius + _wallW / 2,
      Paint()..color = _wall..strokeWidth = _wallW * 2..style = PaintingStyle.stroke,
    );
  }

  void _drawLabels(Canvas canvas) {
    const padding = 6.0;
    for (final r in rooms) {
      final a1 = r.angleStart, a2 = r.angleEnd;
      final r1 = r.radiusStart * _cell, r2 = r.radiusEnd * _cell;

      final pts = <Offset>[
        Offset(r2 * math.cos(a1), r2 * math.sin(a1)),
        Offset(r2 * math.cos(a2), r2 * math.sin(a2)),
      ];
      if (r1 > 1) {
        pts.add(Offset(r1 * math.cos(a2), r1 * math.sin(a2)));
        pts.add(Offset(r1 * math.cos(a1), r1 * math.sin(a1)));
      }

      double cx = 0, cy = 0;
      for (final p in pts) { cx += p.dx; cy += p.dy; }
      cx /= pts.length;
      cy /= pts.length;

      final midR = (r.radiusStart + r.radiusEnd) / 2 * _cell;
      final thickness = (r.radiusEnd - r.radiusStart) * _cell;
      final angleSpan = (r.angleEnd - r.angleStart).abs();
      final chordWidth = 2 * midR * math.sin(angleSpan / 2);
      if (chordWidth < 4 || thickness < 4) continue;

      final midA = (a1 + a2) / 2;
      final useRadial = thickness > chordWidth;
      double textAngle = useRadial ? midA + math.pi / 2 : midA;
      double maxAvail = (useRadial ? thickness : chordWidth) - padding * 2;

      // Apply design override
      final design = labelDesigns[r.label];
      final label = design?.text ?? r.label;
      final rotationOffset = design != null ? design.rotation * math.pi / 180 : 0.0;
      textAngle += rotationOffset;

      double lx = _cx + cx;
      double ly = _cy + cy;

      if (design != null && design.curvature.abs() > 0.5) {
        // Bend text along an arc
        final arcRadius = midR + design.curvature * 3;
        final arcStart = midA - angleSpan * 0.4;
        final arcEnd = midA + angleSpan * 0.4;
        final chars = label.split('');
        final charSpacing = chars.length > 1 ? (arcEnd - arcStart) / (chars.length - 1) : 0.0;
        bool drawn = false;
        for (double fs = design.fontSize.clamp(6.0, 24.0); fs >= 5.0 && !drawn; fs -= 1.0) {
          bool allInside = true;
          for (int i = 0; i < chars.length; i++) {
            final ca = arcStart + i * charSpacing;
            final px = _cx + arcRadius * math.cos(ca);
            final py = _cy + arcRadius * math.sin(ca);
            if (!_pointInSector(Offset(px, py), r)) { allInside = false; break; }
          }
          if (allInside) {
            for (int i = 0; i < chars.length; i++) {
              final ca = arcStart + i * charSpacing;
              final px = _cx + arcRadius * math.cos(ca);
              final py = _cy + arcRadius * math.sin(ca);
              final tp = TextPainter(
                text: TextSpan(text: chars[i], style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: _label)),
                textDirection: ui.TextDirection.ltr,
              );
              tp.layout();
              canvas.save();
              canvas.translate(px, py);
              canvas.rotate(ca + math.pi / 2);
              tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
              canvas.restore();
            }
            drawn = true;
          }
        }
        if (!drawn) {
          // Tiny fallback
          final tp = TextPainter(text: TextSpan(text: label, style: TextStyle(fontSize: 5, fontWeight: FontWeight.w600, color: _label)), textDirection: ui.TextDirection.ltr);
          tp.layout();
          canvas.save(); canvas.translate(lx, ly); canvas.rotate(midA > math.pi / 2 && midA < 3 * math.pi / 2 ? midA + math.pi : midA);
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2)); canvas.restore();
        }
      } else if (design != null) {
        // Fixed font size from design with containment
        bool drawn = false;
        for (double fs = design.fontSize.clamp(6.0, 24.0); fs >= 5.0 && !drawn; fs -= 1.0) {
          for (int maxLines = 1; maxLines <= 3 && !drawn; maxLines++) {
            final tp = TextPainter(
              text: TextSpan(text: label, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: _label)),
              textDirection: ui.TextDirection.ltr, maxLines: maxLines,
            );
            tp.layout(maxWidth: math.max(maxAvail, 20));
            final halfW = tp.width / 2, halfH = tp.height / 2;
            final cosA = math.cos(textAngle), sinA = math.sin(textAngle);
            bool inside = true;
            for (final c in [Offset(-halfW, -halfH), Offset(halfW, -halfH), Offset(halfW, halfH), Offset(-halfW, halfH)]) {
              if (!_pointInSector(Offset(c.dx * cosA - c.dy * sinA + lx, c.dx * sinA + c.dy * cosA + ly), r)) {
                inside = false; break;
              }
            }
            if (inside) {
              double da = textAngle;
              if (midA > math.pi / 2 && midA < 3 * math.pi / 2) da += math.pi;
              canvas.save(); canvas.translate(lx, ly); canvas.rotate(da);
              tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2)); canvas.restore();
              drawn = true;
            }
          }
        }
        if (!drawn) {
          final tp = TextPainter(text: TextSpan(text: label, style: TextStyle(fontSize: 5, fontWeight: FontWeight.w600, color: _label)), textDirection: ui.TextDirection.ltr);
          tp.layout();
          canvas.save(); canvas.translate(lx, ly);
          canvas.rotate(midA > math.pi / 2 && midA < 3 * math.pi / 2 ? midA + math.pi : midA);
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2)); canvas.restore();
        }
      } else {
        // Auto-sizing
        bool drawn = false;
        for (int maxLines = 1; maxLines <= 3 && !drawn; maxLines++) {
          for (double size = _cell * 0.25; size >= 4.0 && !drawn; size -= 1.0) {
            final tp = TextPainter(
              text: TextSpan(text: label, style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: _label)),
              textDirection: ui.TextDirection.ltr,
              maxLines: maxLines,
            );
            tp.layout(maxWidth: math.max(maxAvail, 20));
            final halfW = tp.width / 2;
            final halfH = tp.height / 2;
            final cosA = math.cos(textAngle);
            final sinA = math.sin(textAngle);
            bool inside = true;
            for (final c in [
              Offset(-halfW, -halfH), Offset(halfW, -halfH),
              Offset(halfW, halfH), Offset(-halfW, halfH),
            ]) {
              final rx = c.dx * cosA - c.dy * sinA + lx;
              final ry = c.dx * sinA + c.dy * cosA + ly;
              if (!_pointInSector(Offset(rx, ry), r)) { inside = false; break; }
            }
            if (inside) {
              double da = textAngle;
              if (midA > math.pi / 2 && midA < 3 * math.pi / 2) da += math.pi;
              canvas.save();
              canvas.translate(lx, ly);
              canvas.rotate(da);
              tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
              canvas.restore();
              drawn = true;
            }
          }
        }
        if (!drawn) {
          final tp = TextPainter(
            text: TextSpan(text: label, style: TextStyle(fontSize: 6, fontWeight: FontWeight.w600, color: _label)),
            textDirection: ui.TextDirection.ltr,
          );
          tp.layout();
          canvas.save();
          canvas.translate(lx, ly);
          double da = midA;
          if (midA > math.pi / 2 && midA < 3 * math.pi / 2) da += math.pi;
          canvas.rotate(da);
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircularPlanPainter old) =>
    old.rooms != rooms || old.isDark != isDark || old.labelDesigns != labelDesigns;
}

// ─── Label design data for CAD mode ──────────────────────────────────────────

class _LabelDesign {
  String text;
  double rotation;
  double fontSize;
  double curvature;

  _LabelDesign(this.text, this.rotation, this.fontSize, this.curvature);

  Map<String, dynamic> toJson() => {
    'text': text, 'rotation': rotation, 'fontSize': fontSize, 'curvature': curvature,
  };

  factory _LabelDesign.fromJson(dynamic j) {
    final m = j as Map<String, dynamic>;
    return _LabelDesign(
      m['text'] as String? ?? '',
      (m['rotation'] as num?)?.toDouble() ?? 0,
      (m['fontSize'] as num?)?.toDouble() ?? 12,
      (m['curvature'] as num?)?.toDouble() ?? 0,
    );
  }
}