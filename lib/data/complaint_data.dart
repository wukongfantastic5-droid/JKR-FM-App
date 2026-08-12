class ComplaintTicket {
  final String id;
  final int seqId;
  final String userId;
  final String complainerName;
  final String? complainerPhone;
  final String? reportedAt;
  final String floor;
  final String issueType;
  final String? workCategory;
  final String? priority;
  final String? noRuj;
  final String? assetName;
  final String? assignedAsset;
  final String description;
  final String status;
  final String? evidenceFile;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ComplaintTicket({
    String? id,
    this.seqId = 0,
    required this.userId,
    required this.complainerName,
    this.complainerPhone,
    this.reportedAt,
    required this.floor,
    required this.issueType,
    this.workCategory,
    this.priority,
    this.noRuj,
    this.assetName,
    this.assignedAsset,
    required this.description,
    this.status = 'open',
    this.evidenceFile,
    DateTime? createdAt,
    this.updatedAt,
  }) : id = id ?? 'cmp_${DateTime.now().millisecondsSinceEpoch}',
       createdAt = createdAt ?? DateTime.now();

  factory ComplaintTicket.fromJson(Map<String, dynamic> json) => ComplaintTicket(
    id: json['id'] as String,
    seqId: json['seqId'] as int? ?? 0,
    userId: json['userId'] as String,
    complainerName: json['complainerName'] as String? ?? '',
    complainerPhone: json['complainerPhone'] as String?,
    reportedAt: json['reportedAt'] as String?,
    floor: json['floor'] as String,
    issueType: json['issueType'] as String,
    workCategory: json['workCategory'] as String?,
    priority: json['priority'] as String?,
    noRuj: json['noRuj'] as String?,
    assetName: json['assetName'] as String?,
    assignedAsset: json['assignedAsset'] as String?,
    description: json['description'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    evidenceFile: json['evidenceFile'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'seqId': seqId,
    'userId': userId,
    'complainerName': complainerName,
    if (complainerPhone != null) 'complainerPhone': complainerPhone,
    if (reportedAt != null) 'reportedAt': reportedAt,
    'floor': floor,
    'issueType': issueType,
    if (workCategory != null) 'workCategory': workCategory,
    if (priority != null) 'priority': priority,
    if (noRuj != null) 'noRuj': noRuj,
    if (assetName != null) 'assetName': assetName,
    if (assignedAsset != null && assignedAsset!.isNotEmpty) 'assignedAsset': assignedAsset,
    'description': description,
    'status': status,
    if (evidenceFile != null) 'evidenceFile': evidenceFile,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  ComplaintTicket copyWith({
    String? status,
    DateTime? updatedAt,
    String? evidenceFile,
    String? description,
    String? assignedAsset,
    bool clearAssignedAsset = false,
  }) => ComplaintTicket(
    id: id,
    seqId: seqId,
    userId: userId,
    complainerName: complainerName,
    complainerPhone: complainerPhone,
    reportedAt: reportedAt,
    floor: floor,
    issueType: issueType,
    workCategory: workCategory,
    priority: priority,
    noRuj: noRuj,
    assetName: assetName,
    assignedAsset: clearAssignedAsset ? null : (assignedAsset ?? this.assignedAsset),
    description: description ?? this.description,
    status: status ?? this.status,
    evidenceFile: evidenceFile ?? this.evidenceFile,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}
