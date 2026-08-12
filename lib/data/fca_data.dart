class FcaItem {
  final int id;
  final int bil;
  final String aras;
  String ruang;
  final String kerosakan;
  final String jenis;
  final String pengesahan;
  final String tarikh;
  String status;
  String priority;
  String jkrRequest;
  String solution;
  String solvedAt;
  final String imageFile;
  String instanceName;
  String assetType;

  FcaItem({
    required this.id,
    required this.bil,
    required this.aras,
    required this.ruang,
    required this.kerosakan,
    required this.jenis,
    this.pengesahan = '',
    this.tarikh = '',
    this.status = 'open',
    this.priority = 'medium',
    this.jkrRequest = '',
    this.solution = '',
    this.solvedAt = '',
    this.imageFile = '',
    this.instanceName = '',
    this.assetType = '',
  });

  factory FcaItem.fromJson(Map<String, dynamic> json) => FcaItem(
    id: json['id'] as int? ?? 0,
    bil: json['bil'] as int? ?? 0,
    aras: json['aras'] as String? ?? '',
    ruang: json['ruang'] as String? ?? '',
    kerosakan: json['kerosakan'] as String? ?? '',
    jenis: json['jenis'] as String? ?? '',
    pengesahan: json['pengesahan'] as String? ?? '',
    tarikh: json['tarikh'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    priority: json['priority'] as String? ?? 'medium',
    jkrRequest: json['jkrRequest'] as String? ?? '',
    solution: json['solution'] as String? ?? '',
    solvedAt: json['solvedAt'] as String? ?? '',
    imageFile: json['imageFile'] as String? ?? '',
    instanceName: json['instanceName'] as String? ?? '',
    assetType: json['assetType'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bil': bil,
    'aras': aras,
    'ruang': ruang,
    'kerosakan': kerosakan,
    'jenis': jenis,
    'pengesahan': pengesahan,
    'tarikh': tarikh,
    'status': status,
    'priority': priority,
    'jkrRequest': jkrRequest,
    'solution': solution,
    'solvedAt': solvedAt,
    'imageFile': imageFile,
    if (instanceName.isNotEmpty) 'instanceName': instanceName,
    if (assetType.isNotEmpty) 'assetType': assetType,
  };

  String get statusLabel {
    switch (status) {
      case 'open': return 'Open';
      case 'in_progress': return 'In Progress';
      case 'closed': return 'Closed';
      default: return status;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'high': return 'High';
      case 'medium': return 'Medium';
      case 'low': return 'Low';
      default: return priority;
    }
  }

  static const List<String> knownAssetTypes = [
    'AHU', 'FCU', 'VRF', 'VAV', 'VSD', 'PAC', 'ACSU', 'CHWP',
    'HEAT EXCHANGER', 'HEAT RECOVERY WHEEL', 'COOLING TOWER',
    'AIR COOLED CHILLER', 'AIR CURTAIN', 'FAN', 'AIR FILTER', 'EL',
    'REFRIGERANT LEAK DETECTOR',
    'FIRE FIGHTING', 'FM 200', 'VESDA', 'SPRINKLER PUMP',
    'SPRINKLER CONTROL PANEL', 'HOSE REEL PUMP',
    'HOSE REEL PUMP CONTROL PANEL', 'HYDRANT PILLAR',
    'WET RISER PUMP', 'WET RISER CONTROL PANEL',
    'WET CHEMICAL SYSTEM',
    'LIFT', 'LIFT HIGHZONE', 'LIFT LOWZONE',
    'GONDOLA',
    'WATER PUMP', 'COLD WATER PUMP',
    'DOMESTIC COLD WATER BOOSTER PUMP',
    'WATER TANK', 'WATER FILTER', 'WATER TREATMENT',
    'KITCHEN EXHAUST HOOD',
    'TANDAS',
    'ROLLER SHUTTER', 'HAND DRYER', 'PANIC BUTTON',
    'INSTANT WATER HEATER', 'AUDIO VISUAL', 'VISUAL PROJECTION',
    'SMATV', 'PABX', 'BOOM GATE', 'EXIT SIGN', 'LIGHTING',
    'GRID CONNECTED PHOTOVOLTAIC(PV)', 'SOLAR INVERTER',
    'METERING (VOLT & AMPS)', 'CAP BANK', 'DB', 'MSB', 'SSB',
    'RMU', 'TX', 'UPS', 'ACB', 'S/S/O', 'LV ROOM',
    'SWITCH ROOM HV', 'SYSTEM',
  ];

  String get imageUrl => imageFile.isNotEmpty
      ? 'https://raw.githubusercontent.com/wukongfantastic5-droid/Database-JKR/main/fca_images/$imageFile'
      : '';

  String get displayAssetType {
    if (assetType.isNotEmpty) return assetType;
    if (instanceName.isEmpty) return '';
    final upper = instanceName.toUpperCase();
    // Try longest match first
    final sorted = List<String>.from(knownAssetTypes)..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sorted) {
      if (upper.startsWith(key)) return key;
    }
    // Fallback: first word before parenthesis or space
    return instanceName.split(RegExp(r'[\s\(]')).first;
  }
}
