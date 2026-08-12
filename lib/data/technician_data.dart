class PpmItem {
  final String system;
  final String section;
  final String item;
  final String task;
  final List<String> freq;
  final int? w; // weekly anchor: weekday 1=Mon..7=Sun
  final int? m; // monthly anchor: day of month
  final Map<String, int> anchors; // '3M'/'6M'/'Y'/'5Y' -> day of month
  final int dm; // 0 = none, 1 = every workday, 2 = only on the item's M date

  PpmItem({
    required this.system,
    required this.section,
    required this.item,
    required this.task,
    required this.freq,
    this.w,
    this.m,
    this.anchors = const {},
    this.dm = 0,
  });

  factory PpmItem.fromJson(Map<String, dynamic> json) => PpmItem(
    system: json['system'] as String? ?? '',
    section: json['section'] as String? ?? '',
    item: json['item'] as String? ?? '',
    task: json['task'] as String? ?? '',
    freq: (json['freq'] as List? ?? []).map((e) => e as String).toList(),
    w: json['w'] as int?,
    m: json['m'] as int?,
    anchors: (json['a'] as Map? ?? {}).map((k, v) => MapEntry(k as String, v as int)),
    dm: json['dm'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'system': system,
    'section': section,
    'item': item,
    'task': task,
    'freq': freq,
    'w': w,
    'm': m,
    'a': anchors,
    'dm': dm,
  };
}

class Technician {
  final String id;
  String name;
  String email;
  String password;
  int age;
  String phone;
  String icNumber;
  String photoPath;
  bool isOnline;
  String lastSeen;
  String createdAt;
  String updatedAt;
  String role; // technician | supervisor

  Technician({
    required this.id,
    this.name = '',
    this.email = '',
    this.password = '',
    this.age = 0,
    this.phone = '',
    this.icNumber = '',
    this.photoPath = '',
    this.isOnline = false,
    this.lastSeen = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.role = 'technician',
  });

  factory Technician.fromJson(Map<String, dynamic> json) => Technician(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    password: json['password'] as String? ?? '',
    age: json['age'] as int? ?? 0,
    phone: json['phone'] as String? ?? '',
    icNumber: json['icNumber'] as String? ?? '',
    photoPath: json['photoPath'] as String? ?? '',
    isOnline: json['isOnline'] as bool? ?? false,
    lastSeen: json['lastSeen'] as String? ?? '',
    createdAt: json['createdAt'] as String? ?? '',
    updatedAt: json['updatedAt'] as String? ?? '',
    role: json['role'] as String? ?? 'technician',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'password': password,
    'age': age,
    'phone': phone,
    'icNumber': icNumber,
    'photoPath': photoPath,
    'isOnline': isOnline,
    'lastSeen': lastSeen,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'role': role,
  };
}

class ScheduleItem {
  final DateTime date;
  final String techId;
  final String system;
  final String section;
  final String item;
  final String task;
  final String freq;
  final String id;
  String status; // pending, in_progress, completed

  ScheduleItem({
    required this.date,
    required this.techId,
    required this.system,
    required this.section,
    required this.task,
    required this.freq,
    this.item = '',
    String? id,
    this.status = 'pending',
  }) : id = id ?? '${date.toIso8601String()}_${techId}_${task.hashCode}';

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
    date: DateTime.parse(json['date'] as String),
    techId: json['techId'] as String,
    system: json['system'] as String? ?? '',
    section: json['section'] as String? ?? '',
    item: json['item'] as String? ?? '',
    task: json['task'] as String? ?? '',
    freq: json['freq'] as String? ?? '',
    id: json['id'] as String?,
    status: json['status'] as String? ?? 'pending',
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'techId': techId,
    'system': system,
    'section': section,
    'item': item,
    'task': task,
    'freq': freq,
    'id': id,
    'status': status,
  };
}
