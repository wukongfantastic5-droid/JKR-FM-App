class SparePartSupplier {
  String id;
  String name;
  String whatsapp;
  String location;
  bool recommended;

  SparePartSupplier({
    String? id,
    this.name = '',
    this.whatsapp = '',
    this.location = '',
    this.recommended = false,
  }) : id = id ?? 's${DateTime.now().millisecondsSinceEpoch}';

  factory SparePartSupplier.fromJson(Map<String, dynamic> json) =>
      SparePartSupplier(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        location: json['location'] as String? ?? '',
        recommended: json['recommended'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'whatsapp': whatsapp,
        'location': location,
        'recommended': recommended,
      };
}

class SparePart {
  String id;
  String name;
  int quantity;
  String photoBase64;
  String updatedAt;
  List<SparePartSupplier> suppliers;

  SparePart({
    String? id,
    this.name = '',
    this.quantity = 0,
    this.photoBase64 = '',
    String? updatedAt,
    List<SparePartSupplier>? suppliers,
  })  : id = id ?? 'p${DateTime.now().millisecondsSinceEpoch}',
        updatedAt = updatedAt ?? DateTime.now().toIso8601String(),
        suppliers = suppliers ?? [];

  factory SparePart.fromJson(Map<String, dynamic> json) => SparePart(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 0,
        photoBase64: json['photoBase64'] as String? ?? '',
        updatedAt: json['updatedAt'] as String?,
        suppliers: (json['suppliers'] as List? ?? [])
            .map((s) => SparePartSupplier.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'photoBase64': photoBase64,
        'updatedAt': updatedAt,
        'suppliers': suppliers.map((s) => s.toJson()).toList(),
      };

  SparePartSupplier? get recommendedSupplier {
    for (final s in suppliers) {
      if (s.recommended) return s;
    }
    return suppliers.isNotEmpty ? suppliers.first : null;
  }
}