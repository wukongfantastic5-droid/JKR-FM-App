class InventoryItem {
  final String id;
  String name;
  String type;
  String floor;
  String location;
  String status;
  String notes;
  String imageFile;
  String fcaRef;

  InventoryItem({
    String? id,
    this.name = '',
    this.type = '',
    this.floor = '',
    this.location = '',
    this.status = 'unknown',
    this.notes = '',
    this.imageFile = '',
    this.fcaRef = '',
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? '',
    floor: json['floor'] as String? ?? '',
    location: json['location'] as String? ?? '',
    status: json['status'] as String? ?? 'unknown',
    notes: json['notes'] as String? ?? '',
    imageFile: json['imageFile'] as String? ?? '',
    fcaRef: json['fcaRef'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'floor': floor,
    'location': location,
    'status': status,
    'notes': notes,
    'imageFile': imageFile,
    'fcaRef': fcaRef,
  };
}
