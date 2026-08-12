class UsageRecord {
  String id;
  String type; // 'part' | 'tool'
  String itemId;
  String itemName;
  int qtyUsed;
  String techId;
  String techName;
  String date;
  String remark;

  UsageRecord({
    required this.id,
    required this.type,
    required this.itemId,
    required this.itemName,
    required this.qtyUsed,
    required this.techId,
    required this.techName,
    required this.date,
    this.remark = '',
  });

  factory UsageRecord.fromJson(Map<String, dynamic> json) => UsageRecord(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'part',
        itemId: json['itemId'] as String? ?? '',
        itemName: json['itemName'] as String? ?? '',
        qtyUsed: json['qtyUsed'] as int? ?? 0,
        techId: json['techId'] as String? ?? '',
        techName: json['techName'] as String? ?? '',
        date: json['date'] as String? ?? '',
        remark: json['remark'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'itemId': itemId,
        'itemName': itemName,
        'qtyUsed': qtyUsed,
        'techId': techId,
        'techName': techName,
        'date': date,
        'remark': remark,
      };
}