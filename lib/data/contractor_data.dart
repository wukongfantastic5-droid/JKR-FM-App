class Contractor {
  String id;
  String name;
  String system;
  String contact;
  String whatsapp;
  String location;
  String ppmDate;
  String ppmTime;
  String reportStatus;
  String reportFile;
  String reportFileName;
  String reportUploadedAt;
  String password;
  bool pmLocked;
  String updatedAt;

  Contractor({
    String? id,
    this.name = '',
    this.system = '',
    this.contact = '',
    this.whatsapp = '',
    this.location = '',
    this.ppmDate = '',
    this.ppmTime = '',
    this.reportStatus = 'pending',
    this.reportFile = '',
    this.reportFileName = '',
    this.reportUploadedAt = '',
    this.password = '123456',
    this.pmLocked = false,
    String? updatedAt,
  })  : id = id ?? 'c${DateTime.now().millisecondsSinceEpoch}',
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  factory Contractor.fromJson(Map<String, dynamic> json) => Contractor(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        system: json['system'] as String? ?? '',
        contact: json['contact'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        location: json['location'] as String? ?? '',
        ppmDate: json['ppmDate'] as String? ?? '',
        ppmTime: json['ppmTime'] as String? ?? '',
        reportStatus: json['reportStatus'] as String? ?? 'pending',
        reportFile: json['reportFile'] as String? ?? '',
        reportFileName: json['reportFileName'] as String? ?? '',
        reportUploadedAt: json['reportUploadedAt'] as String? ?? '',
        password: json['password'] as String? ?? '123456',
        pmLocked: json['pmLocked'] as bool? ?? false,
        updatedAt: json['updatedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'system': system,
        'contact': contact,
        'whatsapp': whatsapp,
        'location': location,
        'ppmDate': ppmDate,
        'ppmTime': ppmTime,
        'reportStatus': reportStatus,
        'reportFile': reportFile,
        'reportFileName': reportFileName,
        'reportUploadedAt': reportUploadedAt,
        'password': password,
        'pmLocked': pmLocked,
        'updatedAt': updatedAt,
      };

  /// Login uses email type: <NAME>@gmail.com (e.g. HITACHI@gmail.com).
  String get email => '${name.trim()}@gmail.com';

  bool get reportSent => reportStatus == 'sent';

  bool get hasReportFile => reportFile.isNotEmpty;

  /// True when the monthly PM visit is not yet scheduled (no concrete date).
  bool get visitUnscheduled => ppmDate.isEmpty;

  /// Root folder for every contractor report in the repo.
  static const String rootFolder = 'Contractor_Report';

  /// Clean folder name (no chars that break GitHub paths).
  static String folderName(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.isEmpty ? 'CONTRACTOR' : s.toUpperCase();
  }

  /// repo path folder: Contractor_Report/ALIMAK/Gondola System/05 July 2026
  static String reportFolder(Contractor c, DateTime date) {
    final months = const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '$rootFolder/${folderName(c.name)}/${folderName(c.system)}/'
        '$day $month ${date.year}';
  }

  static const Map<String, String> systemGroups = {
    'Lift': 'Lift',
    'Gondola': 'Gondola',
    'BMS': 'BMS',
    'Fire Fighting System': 'Fire Fighting System',
    'Precision Air Conditioning (PAC) System': 'Precision Air Conditioning (PAC) System',
    'ACMV System': 'ACMV System',
  };

  static const String file = 'contractors.json';
  static const List<Map<String, String>> seed = [
    {'name': 'HITACHI', 'system': 'Lift'},
    {'name': 'ALIMAK', 'system': 'Gondola'},
    {'name': 'SDC', 'system': 'BMS'},
    {'name': 'SEMARAK', 'system': 'Fire Fighting System'},
    {'name': 'IGSP', 'system': 'Precision Air Conditioning (PAC) System'},
    {'name': 'CARRIER', 'system': 'ACMV System'},
  ];
}