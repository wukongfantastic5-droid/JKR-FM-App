import 'package:flutter/foundation.dart' show debugPrint;
import '../data/floor_plan_data.dart';
import 'repo_service.dart';
import 'complaint_service.dart';

class FloorPlanService {
  static final bool _debug = true;
  static final Map<String, FloorPlan> _cache = {};

  /// Drops cached floor plans so the next [getFloorPlan] re-applies the
  /// latest complaint statuses. Called after complaints are added/updated.
  static void invalidate([String? floor]) {
    if (floor == null) {
      _cache.clear();
    } else {
      _cache.remove(floor);
    }
  }

  static void _log(String msg) {
    if (_debug) debugPrint('[FloorPlan] $msg');
  }

  static Future<FloorPlan> getFloorPlan(String floor) async {
    if (_cache.containsKey(floor)) return _cache[floor]!;

    FloorPlan plan;
    try {
      final all = await RepoService.readFile('floorplans.json');
      if (all != null) {
        final map = all as Map<String, dynamic>;
        if (map.containsKey(floor)) {
          plan = FloorPlan.fromJson(map[floor] as Map<String, dynamic>);
        } else {
          plan = _generateDefault(floor);
        }
      } else {
        plan = _generateDefault(floor);
      }
    } catch (e) {
      _log('load floor $floor error: $e');
      plan = _generateDefault(floor);
    }

    _enrichFromFca(plan);
    await _applyComplaintStatuses(plan);
    _cache[floor] = plan;
    return plan;
  }

  static Future<void> _applyComplaintStatuses(FloorPlan plan) async {
    try {
      final tickets = await ComplaintService.getOpen(plan.floor);
      if (tickets.isEmpty) return;
      for (final ticket in tickets) {
        // Match the ticket against each asset using the asset name, its OCR
        // reference (e.g. "G.15.009- TANDAS WANITA") and the description
        // (e.g. "...LAMPU TANDAS WANITA TIDAK MENYALA...").
        final haystack = [ticket.assetName ?? '', ticket.description, ticket.issueType]
            .where((s) => s.isNotEmpty)
            .join(' ');
        for (final asset in plan.assets) {
          if (textMatchesAsset(asset.name, haystack) || textMatchesAsset(asset.type, haystack)) {
            if (ticket.status == 'open') {
              asset.status = 'down';
            } else if (ticket.status == 'in_progress') {
              asset.status = 'maintenance';
            }
            _log('ticket ${ticket.id} → ${asset.name} status=${asset.status}');
          }
        }
      }
    } catch (e) {
      _log('apply complaint statuses error: $e');
    }
  }

  static String? _ruangToAssetType(String ruang, String jenis) {
    final r = ruang.toLowerCase();
    if (r.contains('chiller')) return 'chiller';
    if (r.contains('cooling') || r.contains('cooling tower')) return 'cooling_tower';
    if (r.contains('ahu') || r.contains('pac')) return 'ahu';
    if (r.contains('fcu')) return 'fcu';
    if (r.contains('tandas') || r.contains('toilet')) return 'toilet';
    if (r.contains('pump') || r.contains('pam')) return 'pump';
    if (r.contains('panel')) return 'panel';
    if (r.contains('tank') || r.contains('tanki') || r.contains('tangki') || r.contains('water tank') || r.contains('rain water') || r.contains('grey water')) return 'tank';
    if (r.contains('lif') || r.contains('lift') || r.contains('motor lif')) return 'lift';
    if (r.contains('kipas') || r.contains('fan')) return 'fcu';
    if (r.contains('stair') || r.contains('tangga')) return 'staircase';
    if (r.contains('pantry') || r.contains('dapur')) return 'pantry';
    if (r.contains('office') || r.contains('pejabat')) return 'office';
    if (r.contains('meeting')) return 'meeting_room';
    if (r.contains('hose')) return 'door';
    if (r.contains('parking') || r.contains('park')) return 'parking';
    return null;
  }

  static bool _floorMatches(String aras, String targetFloor) {
    if (aras == targetFloor) return true;
    final cleaned = aras.replaceAll(RegExp(r'^LVL\s*', caseSensitive: false), '');
    final floors = cleaned.split(RegExp(r'[,;\s]+')).map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
    return floors.contains(targetFloor);
  }

  static String _deriveAssetName(String ruang, String type) {
    final r = ruang.toLowerCase();
    final meta = FloorPlan.assetTypeMeta[type];
    final base = meta?['label'] ?? type;
    if (r.contains('tandas oku')) return 'Toilet OKU';
    if (r.contains('tandas lelaki dan perempuan')) return 'Toilet';
    if (r.contains('tandas lelaki')) return 'Toilet Lelaki';
    if (r.contains('tandas perempuan')) return 'Toilet Perempuan';
    if (r.contains('tandas')) return base;
    if (r.contains('motor lif') || r.contains('motor lift')) return 'Lift Motor';
    if (r.contains('water tank')) return 'Water Tank';
    if (r.contains('hose reel')) return 'Hose Reel';
    if (r.contains('rain water')) return 'Rain Water Tank';
    if (r.contains('grey water')) return 'Grey Water Tank';

    final bilikMatch = RegExp(r'bilik\s+(.+)', caseSensitive: false).firstMatch(ruang);
    if (bilikMatch != null) {
      final rest = bilikMatch.group(1)!.trim();
      final parts = rest.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (parts.length <= 3) {
        return parts.map((w) {
          if (w.length <= 3 && w == w.toUpperCase()) return w;
          return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
        }).join(' ');
      }
    }
    if (type == 'custom') {
      final cleaned = ruang.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
      return cleaned.split(RegExp(r'\s+')).map((w) {
        if (w.length <= 3 && w == w.toUpperCase()) return w;
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      }).join(' ');
    }
    return base;
  }

  static void _enrichFromFca(FloorPlan plan) {
    try {
      final items = RepoService.fcaItems;
      int xOffset = 0;
      for (final fca in items) {
        if (!_floorMatches(fca.aras, plan.floor)) continue;

        final type = _ruangToAssetType(fca.ruang, fca.jenis) ?? 'custom';

        bool alreadyExists = false;
        for (final asset in plan.assets) {
          if (textMatchesAsset(asset.name, fca.ruang) || textMatchesAsset(asset.type, fca.jenis)) {
            alreadyExists = true;
            break;
          }
        }
        if (alreadyExists) continue;

        final name = _deriveAssetName(fca.ruang, type);
        final existingOfType = plan.assets.where((a) => a.type == type).length;
        final sameName = plan.assets.where((a) => textMatchesAsset(a.name, name)).length;
        final finalName = sameName > 0 ? '$name ${existingOfType + 1}' : name;

        final x = (plan.gridW - 3 - xOffset).clamp(0, plan.gridW - 3);
        final y = (plan.gridH - 3).clamp(0, plan.gridH - 2);
        xOffset = (xOffset + 3) % 12;

        plan.assets.add(FloorAsset(
          name: finalName,
          type: type,
          x: x, y: y, w: 2, h: 2,
        ));
        _log('added "$finalName" ($type) from FCA #${fca.id}');
      }
    } catch (e) {
      _log('enrich error: $e');
    }
  }

  static Future<void> saveFloorPlan(FloorPlan plan) async {
    _cache[plan.floor] = plan;
    try {
      final all = await RepoService.readFile('floorplans.json');
      final map = all is Map<String, dynamic> ? Map<String, dynamic>.from(all) : <String, dynamic>{};
      map[plan.floor] = plan.toJson();
      await RepoService.writeFile('floorplans.json', map);
      _log('saved floor ${plan.floor}');
    } catch (e) {
      _log('save error: $e');
    }
  }

  static FloorPlan _generateDefault(String floor) {
    if (_isMechanical(floor)) return _mechanicalFloor(floor);
    if (_isParking(floor)) return _parkingFloor(floor);
    if (_isBasement(floor)) return _officeFloor(floor);
    return _officeFloor(floor);
  }

  static bool _isMechanical(String f) {
    const mechanical = {'18','25','26','28','31','32','33','34','36','37'};
    return mechanical.contains(f);
  }

  static bool _isParking(String f) {
    const parking = {'P1','P2','P4A','P5','P5A','P6'};
    return parking.contains(f);
  }

  static bool _isBasement(String f) {
    const basement = {'B1','B2'};
    return basement.contains(f);
  }

  static FloorPlan _mechanicalFloor(String floor) {
    return FloorPlan(
      floor: floor,
      assets: [
        FloorAsset(name: 'Chiller 1', type: 'chiller', x: 1, y: 1, w: 4, h: 3),
        FloorAsset(name: 'Chiller 2', type: 'chiller', x: 6, y: 1, w: 4, h: 3),
        FloorAsset(name: 'AHU-01', type: 'ahu', x: 12, y: 1, w: 3, h: 2),
        FloorAsset(name: 'AHU-02', type: 'ahu', x: 16, y: 1, w: 3, h: 2),
        FloorAsset(name: 'Cooling Tower', type: 'cooling_tower', x: 1, y: 5, w: 5, h: 3),
        FloorAsset(name: 'Pump Set', type: 'pump', x: 8, y: 5, w: 3, h: 2),
        FloorAsset(name: 'Panel Utama', type: 'panel', x: 12, y: 4, w: 3, h: 2),
        FloorAsset(name: 'FCU-01', type: 'fcu', x: 16, y: 4, w: 2, h: 2),
        FloorAsset(name: 'Tanki Air', type: 'tank', x: 3, y: 9, w: 3, h: 3),
        FloorAsset(name: 'Staircase', type: 'staircase', x: 0, y: 0, w: 1, h: 16),
        FloorAsset(name: 'Lift', type: 'lift', x: 19, y: 3, w: 1, h: 2),
        FloorAsset(name: 'Toilet', type: 'toilet', x: 16, y: 7, w: 2, h: 2),
        FloorAsset(name: 'Pantry', type: 'pantry', x: 12, y: 7, w: 3, h: 2),
      ],
      labels: [
        FloorLabel(text: 'CHILLER ROOM', x: 2, y: 1),
        FloorLabel(text: 'CT AREA', x: 2, y: 5),
      ],
    );
  }

  static FloorPlan _officeFloor(String floor) {
    return FloorPlan(
      floor: floor,
      assets: [
        FloorAsset(name: 'Lift A', type: 'lift', x: 0, y: 1, w: 1, h: 2),
        FloorAsset(name: 'Lift B', type: 'lift', x: 0, y: 4, w: 1, h: 2),
        FloorAsset(name: 'Staircase', type: 'staircase', x: 0, y: 7, w: 1, h: 3),
        FloorAsset(name: 'Open Office', type: 'office', x: 2, y: 1, w: 8, h: 5),
        FloorAsset(name: 'Meeting Room A', type: 'meeting_room', x: 11, y: 1, w: 4, h: 2),
        FloorAsset(name: 'Meeting Room B', type: 'meeting_room', x: 16, y: 1, w: 3, h: 2),
        FloorAsset(name: 'Pantry', type: 'pantry', x: 11, y: 4, w: 3, h: 2),
        FloorAsset(name: 'Toilet', type: 'toilet', x: 15, y: 4, w: 2, h: 2),
        FloorAsset(name: 'Manager Room', type: 'office', x: 18, y: 4, w: 2, h: 2),
        FloorAsset(name: 'Stor', type: 'door', x: 11, y: 7, w: 2, h: 2),
        FloorAsset(name: 'FCU-01', type: 'fcu', x: 2, y: 7, w: 2, h: 1),
        FloorAsset(name: 'FCU-02', type: 'fcu', x: 5, y: 7, w: 2, h: 1),
        FloorAsset(name: 'Panel', type: 'panel', x: 18, y: 1, w: 1, h: 1),
      ],
      labels: [
        FloorLabel(text: 'OFFICE', x: 4, y: 2),
        FloorLabel(text: 'LIFT LOBBY', x: 0, y: 0),
      ],
    );
  }

  static FloorPlan _parkingFloor(String floor) {
    return FloorPlan(
      floor: floor,
      gridW: 20,
      gridH: 12,
      assets: [
        FloorAsset(name: 'Lift A', type: 'lift', x: 0, y: 1, w: 1, h: 2),
        FloorAsset(name: 'Staircase', type: 'staircase', x: 0, y: 4, w: 1, h: 3),
        FloorAsset(name: 'Parking Row A', type: 'parking', x: 3, y: 0, w: 16, h: 2),
        FloorAsset(name: 'Parking Row B', type: 'parking', x: 3, y: 3, w: 16, h: 2),
        FloorAsset(name: 'Parking Row C', type: 'parking', x: 3, y: 6, w: 16, h: 2),
        FloorAsset(name: 'Parking Row D', type: 'parking', x: 3, y: 9, w: 16, h: 2),
        FloorAsset(name: 'Panel', type: 'panel', x: 18, y: 0, w: 1, h: 1),
      ],
      labels: [
        FloorLabel(text: 'PARKING', x: 10, y: 4),
        FloorLabel(text: 'LIFT', x: 0, y: 1),
      ],
    );
  }
}
