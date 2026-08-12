class PmStatusEntry {
  final String id; // unique stable id (task key + date)
  final String date; // ISO date of the scheduled task, e.g. 2026-08-10
  final String month; // yyyy-mm
  final String sys;
  final String sub;
  final String item;
  final String desc;
  final String freq;
  final List<String> markers;
  String techId;
  String techName;
  String floor;
  String asset;
  String woNo; // last 4 digits of the work order number
  String status; // open | in_progress | closed
  String attendedAt;
  String startedAt;
  String closedAt;
  String findings;
  String remark;
  List<String> photos; // base64 jpeg

  bool get isClosed => status == 'closed';
  bool get isInProgress => status == 'in_progress';

  PmStatusEntry({
    required this.id,
    required this.date,
    required this.month,
    required this.sys,
    this.sub = '',
    required this.item,
    required this.desc,
    required this.freq,
    this.markers = const [],
    this.techId = '',
    this.techName = '',
    this.floor = '',
    this.asset = '',
    this.woNo = '',
    this.status = 'open',
    this.attendedAt = '',
    this.startedAt = '',
    this.closedAt = '',
    this.findings = '',
    this.remark = '',
    this.photos = const [],
  });

  String get sysCode => sys.split(' ').first.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'month': month,
    'sys': sys,
    'sub': sub,
    'item': item,
    'desc': desc,
    'freq': freq,
    'markers': markers,
    'techId': techId,
    'techName': techName,
    'floor': floor,
    'asset': asset,
    'woNo': woNo,
    'status': status,
    'attendedAt': attendedAt,
    'startedAt': startedAt,
    'closedAt': closedAt,
    'findings': findings,
    'remark': remark,
    'photos': photos,
  };

  factory PmStatusEntry.fromJson(Map<String, dynamic> j) => PmStatusEntry(
    id: j['id'] as String? ?? '',
    date: j['date'] as String? ?? '',
    month: j['month'] as String? ?? '',
    sys: j['sys'] as String? ?? '',
    sub: j['sub'] as String? ?? '',
    item: j['item'] as String? ?? '',
    desc: j['desc'] as String? ?? '',
    freq: j['freq'] as String? ?? '',
    markers: ((j['markers'] as List?) ?? []).map((e) => e.toString()).toList(),
    techId: j['techId'] as String? ?? '',
    techName: j['techName'] as String? ?? '',
    floor: j['floor'] as String? ?? '',
    asset: j['asset'] as String? ?? '',
    woNo: j['woNo'] as String? ?? '',
    status: j['status'] as String? ?? 'open',
    attendedAt: j['attendedAt'] as String? ?? '',
    startedAt: j['startedAt'] as String? ?? '',
    closedAt: j['closedAt'] as String? ?? '',
    findings: j['findings'] as String? ?? '',
    remark: j['remark'] as String? ?? '',
    photos: ((j['photos'] as List?) ?? []).map((e) => e.toString()).toList(),
  );
}