import 'package:cloud_firestore/cloud_firestore.dart';

/// An inventory item. Deliberately minimal — code, name, description and the
/// running stock figure are all the requirement calls for.
///
/// [currentStock] is never written directly by UI code: it is only ever
/// changed inside the transaction in MovementRepository, so that the figure
/// and the movement that explains it are written together or not at all.
class Item {
  final String id;
  final String code;
  final String name;
  final String description;
  final int currentStock;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Item({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.currentStock = 0,
    this.createdAt,
    this.updatedAt,
  });

  Item copyWith({
    String? code,
    String? name,
    String? description,
    int? currentStock,
  }) => Item(
    id: id,
    code: code ?? this.code,
    name: name ?? this.name,
    description: description ?? this.description,
    currentStock: currentStock ?? this.currentStock,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, Object?> toFirestore() => {
    'code': code,
    'name': name,
    'description': description,
    'currentStock': currentStock,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Fields an admin may edit. Excludes `currentStock` so the item form can
  /// never overwrite a figure that a concurrent movement just changed.
  Map<String, Object?> toDefinitionUpdate() => {
    'code': code,
    'name': name,
    'description': description,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory Item.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Item(
      id: doc.id,
      code: (data['code'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      currentStock: (data['currentStock'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
