import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import '../utils/validators.dart';
import 'collections.dart';

class ItemCodeTakenException implements Exception {
  final String code;
  ItemCodeTakenException(this.code);
}

/// Item definitions. Note that nothing here writes `currentStock` — that
/// belongs to MovementRepository's transaction alone.
class ItemRepository {
  final FirebaseFirestore _db;

  ItemRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  JsonCollection get _items => _db.collection(Collections.items);

  Stream<List<Item>> watchAll() {
    return _items
        .orderBy('code')
        .snapshots()
        .map((snap) => snap.docs.map(Item.fromFirestore).toList());
  }

  Future<List<Item>> fetchAll() async {
    final snap = await _items.orderBy('code').get();
    return snap.docs.map(Item.fromFirestore).toList();
  }

  Future<Item?> findByCode(String code) async {
    final snap = await _items
        .where('code', isEqualTo: normalizeItemCode(code))
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Item.fromFirestore(snap.docs.first);
  }

  /// Firestore has no unique constraint, so uniqueness of the item code is
  /// enforced by using the code itself as the document id: a duplicate is a
  /// collision on an existing document rather than a second row.
  Future<Item> create({
    required String code,
    required String name,
    required String description,
    int openingStock = 0,
  }) async {
    final normalized = normalizeItemCode(code);
    final ref = _items.doc(normalized);

    final existing = await ref.get();
    if (existing.exists) {
      throw ItemCodeTakenException(normalized);
    }

    await ref.set({
      'code': normalized,
      'name': name.trim(),
      'description': description.trim(),
      'currentStock': openingStock,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return Item.fromFirestore(await ref.get());
  }

  /// Updates the item's definition only. The code is the document id and so
  /// is immutable — changing it would orphan the item's movement history.
  Future<void> updateDefinition({
    required String itemId,
    required String name,
    required String description,
  }) {
    return _items.doc(itemId).update({
      'name': name.trim(),
      'description': description.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String itemId) => _items.doc(itemId).delete();
}
