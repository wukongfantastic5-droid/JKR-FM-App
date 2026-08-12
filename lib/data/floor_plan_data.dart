import 'dart:ui';

const _bmEn = {
  'tandas': 'toilet', 'tanki': 'tank', 'tangki': 'tank',
  'bilik': 'room', 'pejabat': 'office', 'pam': 'pump',
  'lif': 'lift', 'angkat': 'lift',
  'pintu': 'door', 'tingkap': 'window',
  'meja': 'desk', 'kerusi': 'chair', 'almari': 'cabinet',
  'katil': 'bed', 'lampu': 'lamp', 'kipas': 'fan',
  'paip': 'pipe', 'sinki': 'basin', 'dapur': 'kitchen',
  'tangga': 'stair', 'cermin': 'mirror', 'rak': 'shelf',
  'pengering': 'dryer', 'tangan': 'hand',
  'motor': 'motor',
  'wanita': 'women', 'lelaki': 'men', 'oku': 'disabled',
  'rosak': 'broken', 'bocor': 'leak', 'berkarat': 'rust',
  'suis': 'switch', 'sabun': 'soap',
  'pecah': 'broken', 'tersumbat': 'blocked', 'bising': 'noise',
  'pemadam': 'extinguisher', 'api': 'fire',
};

// English variants folded onto the same token so EN and BM complaints
// converge during matching (e.g. lampu / lamp / light / bulb). Kept narrow
// on purpose: "lighting" and "luminaries" are NOT folded into "lamp", so a
// toilet-lamp complaint (LAMPU TANDAS) only hits the LAMP asset inside
// TANDAS and never bleeds into the LIGHTING / LUMINARIES asset.
const _enSyn = {
  'light': 'lamp', 'lights': 'lamp', 'bulb': 'lamp',
  'woman': 'women', 'ladies': 'women',
  'male': 'men',
  'leaking': 'leak', 'rusty': 'rust',
  'spoilt': 'broken', 'spoiled': 'broken',
  'sink': 'basin',
  'clogged': 'blocked', 'blockage': 'blocked',
  'noisy': 'noise',
};

const _stopWords = {'room', 'area', 'unit', 'level', 'floor', 'toilet', 'tandas'};

String normalizeAssetText(String s) {
  final words = s.toLowerCase().split(RegExp(r'[\s_\-/\n]+'));
  final normalized = words.map((w) {
    final mapped = _bmEn[w] ?? w;
    return _enSyn[mapped] ?? mapped;
  }).join(' ');
  return normalized;
}

bool textMatchesAsset(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  final al = normalizeAssetText(a), bl = normalizeAssetText(b);
  if (al.contains(bl) || bl.contains(al)) return true;
  final aw = al.split(RegExp(r'[\s_\-/\n]+')).where((w) => w.length >= 3 && !_stopWords.contains(w)).toList();
  final bw = bl.split(RegExp(r'[\s_\-/\n]+')).where((w) => w.length >= 3 && !_stopWords.contains(w)).toList();
  for (final wa in aw) {
    for (final wb in bw) {
      if (wa.contains(wb) || wb.contains(wa) || wa.startsWith(wb) || wb.startsWith(wa)) return true;
    }
  }
  return false;
}

/// Returns the SINGLE asset keyword a complaint text is really about, or
/// null when no specific asset is named. This stops a ticket from lighting
/// up every overlapping asset (e.g. "SUIS LAMPU ... NAK TERCABUT" is a
/// SWITCH issue — not a LAMP issue, and not a fireman switch).
/// Priority order matters: compounds like "suis lampu" / "light switch"
/// are switches; "lampu tandas" alone is a lamp.
String? resolveAssetSubject(String text) {
  final h = normalizeAssetText(text);
  const keywords = [
    'switch', 'lamp', 'dryer', 'fan', 'bowl', 'urinal', 'basin',
    'blind spot mirror', 'mirror', 'nozzle', 'tile', 'blower', 'soap', 'dispenser',
    'supply', 'extinguisher', 'hose', 'pump', 'tank', 'chiller',
    'ahu', 'fcu', 'lift', 'door', 'window', 'stair', 'rail',
  ];
  for (final k in keywords) {
    if (RegExp(r'\b' + RegExp.escape(k) + r'\b').hasMatch(h)) return k;
  }
  return null;
}

class FloorAsset {
  String id;
  String name;
  String type;
  int x, y;
  int w, h;
  String status;
  String notes;
  String shape;
  List<Map<String, int>> points;

  FloorAsset({
    String? id,
    this.name = '',
    required this.type,
    required this.x,
    required this.y,
    this.w = 2,
    this.h = 2,
    this.status = 'good',
    this.notes = '',
    this.shape = 'rect',
    List<Map<String, int>>? points,
  }) : id = id ?? '${type}_${x}_$y',
       points = points ?? [];

  factory FloorAsset.fromJson(Map<String, dynamic> json) => FloorAsset(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    type: json['type'] as String,
    x: json['x'] as int,
    y: json['y'] as int,
    w: json['w'] as int? ?? 2,
    h: json['h'] as int? ?? 2,
    status: json['status'] as String? ?? 'good',
    notes: json['notes'] as String? ?? '',
    shape: json['shape'] as String? ?? 'rect',
    points: (json['points'] as List? ?? []).map((e) => Map<String, int>.from(e as Map)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'status': status,
    'notes': notes,
    'shape': shape,
    'points': points,
  };

  Color get color {
    switch (status) {
      case 'good': return const Color(0xFF22C55E);
      case 'down': return const Color(0xFFEF4444);
      case 'maintenance': return const Color(0xFFF59E0B);
      default: return const Color(0xFF94A3B8);
    }
  }
}

class FloorLabel {
  String text;
  int x, y;

  FloorLabel({required this.text, required this.x, required this.y});

  factory FloorLabel.fromJson(Map<String, dynamic> json) => FloorLabel(
    text: json['text'] as String,
    x: json['x'] as int,
    y: json['y'] as int,
  );

  Map<String, dynamic> toJson() => {'text': text, 'x': x, 'y': y};
}

class FloorPlan {
  final String floor;
  int gridW, gridH;
  List<FloorAsset> assets;
  List<FloorLabel> labels;

  FloorPlan({
    required this.floor,
    this.gridW = 20,
    this.gridH = 15,
    List<FloorAsset>? assets,
    List<FloorLabel>? labels,
  }) : assets = assets ?? [],
       labels = labels ?? [];

  factory FloorPlan.fromJson(Map<String, dynamic> json) => FloorPlan(
    floor: json['floor'] as String,
    gridW: json['gridW'] as int? ?? 20,
    gridH: json['gridH'] as int? ?? 15,
    assets: (json['assets'] as List? ?? []).map((e) => FloorAsset.fromJson(e as Map<String, dynamic>)).toList(),
    labels: (json['labels'] as List? ?? []).map((e) => FloorLabel.fromJson(e as Map<String, dynamic>)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'floor': floor,
    'gridW': gridW,
    'gridH': gridH,
    'assets': assets.map((e) => e.toJson()).toList(),
    'labels': labels.map((e) => e.toJson()).toList(),
  };

  static const assetTypeMeta = {
    'chiller': {'icon': '❄️', 'label': 'Chiller'},
    'cooling_tower': {'icon': '🏗️', 'label': 'Cooling Tower'},
    'ahu': {'icon': '🌀', 'label': 'AHU'},
    'fcu': {'icon': '❄', 'label': 'FCU'},
    'pump': {'icon': '💧', 'label': 'Pump'},
    'panel': {'icon': '⚡', 'label': 'Panel'},
    'tank': {'icon': '🛢️', 'label': 'Tank'},
    'escalator': {'icon': '📶', 'label': 'Escalator'},
    'lift': {'icon': '🛗', 'label': 'Lift'},
    'staircase': {'icon': '🪜', 'label': 'Staircase'},
    'toilet': {'icon': '🚻', 'label': 'Toilet'},
    'pantry': {'icon': '☕', 'label': 'Pantry'},
    'meeting_room': {'icon': '📋', 'label': 'Meeting Room'},
    'office': {'icon': '🪑', 'label': 'Office'},
    'parking': {'icon': '🚗', 'label': 'Parking'},
    'door': {'icon': '🚪', 'label': 'Door'},
    'custom': {'icon': '', 'label': 'Custom'},
  };
}
