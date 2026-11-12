import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/movement.dart';
import '../utils/business_date.dart';
import '../utils/validators.dart';
import 'collections.dart';

/// Raised when a dispatch would take stock below zero. Carries the figures so
/// the UI can tell the operator exactly what is available.
class InsufficientStockException implements Exception {
  final String itemName;
  final int available;
  final int requested;

  InsufficientStockException({
    required this.itemName,
    required this.available,
    required this.requested,
  });

  @override
  String toString() =>
      'Only $available in stock for $itemName, tried to dispatch $requested';
}

class ItemMissingException implements Exception {
  final String itemId;
  ItemMissingException(this.itemId);
}

/// The one and only write path for stock.
///
/// Every change to `items.currentStock` happens inside the transaction below,
/// paired with the immutable `movements` document that explains it. Nothing
/// else in the app writes that field, so the running figure and the ledger
/// can never disagree — even if the app is killed mid-write, or two people
/// move the same item from two devices at the same moment.
class MovementRepository {
  final FirebaseFirestore _db;

  MovementRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  JsonCollection get _movements => _db.collection(Collections.movements);
  JsonCollection get _items => _db.collection(Collections.items);

  /// Records stock coming in, against the store's selected working day. The
  /// caller is responsible for having checked that a day is open —
  /// firestore.rules enforces it independently.
  Future<Movement> recordInward({
    required String itemId,
    required int quantity,
    required String referenceNumber,
    required AppUser user,
    required String shiftId,
    String? businessDate,
    bool lateEntry = false,
  }) {
    assert(quantity > 0, 'Inward quantity must be positive');
    return _record(
      itemId: itemId,
      delta: quantity,
      type: MovementType.inward,
      referenceNumber: referenceNumber,
      user: user,
      shiftId: shiftId,
      businessDate: businessDate,
      lateEntry: lateEntry,
    );
  }

  /// Records stock going out, against the selected working day. Same
  /// precondition as [recordInward].
  Future<Movement> recordDispatch({
    required String itemId,
    required int quantity,
    required String referenceNumber,
    required AppUser user,
    required String shiftId,
    String? businessDate,
  }) {
    assert(quantity > 0, 'Dispatch quantity is given as a positive number');
    return _record(
      itemId: itemId,
      delta: -quantity,
      type: MovementType.dispatch,
      referenceNumber: referenceNumber,
      user: user,
      shiftId: shiftId,
      businessDate: businessDate,
    );
  }

  /// Writes an auditor's correction into stock. Signed: positive when the
  /// physical count was higher than the books, negative when lower.
  Future<Movement> recordAuditAdjustment({
    required String itemId,
    required int delta,
    required String referenceNumber,
    required AppUser user,
    String? shiftId,
    String? businessDate,
  }) {
    assert(delta != 0, 'An adjustment of zero is not a movement');
    return _record(
      itemId: itemId,
      delta: delta,
      type: MovementType.auditAdjustment,
      referenceNumber: referenceNumber,
      user: user,
      shiftId: shiftId,
      businessDate: businessDate,
    );
  }

  Future<Movement> _record({
    required String itemId,
    required int delta,
    required MovementType type,
    required String referenceNumber,
    required AppUser user,
    String? shiftId,
    String? businessDate,
    bool lateEntry = false,
  }) async {
    final reference = normalizeReferenceNumber(referenceNumber);
    final referenceError = validateReferenceNumber(reference);
    if (referenceError != null) {
      throw ArgumentError(referenceError);
    }

    final date = businessDate ?? todayBusinessDate();
    final itemRef = _items.doc(itemId);
    final movementRef = _movements.doc();

    await _db.runTransaction((txn) async {
      final itemSnap = await txn.get(itemRef);
      if (!itemSnap.exists) {
        throw ItemMissingException(itemId);
      }
      final itemData = itemSnap.data() ?? const <String, dynamic>{};
      final currentStock = (itemData['currentStock'] as num?)?.toInt() ?? 0;
      final resulting = currentStock + delta;

      if (resulting < 0) {
        throw InsufficientStockException(
          itemName: (itemData['name'] as String?) ?? itemId,
          available: currentStock,
          requested: delta.abs(),
        );
      }

      final movement = Movement(
        id: movementRef.id,
        itemId: itemId,
        itemCode: (itemData['code'] as String?) ?? '',
        itemName: (itemData['name'] as String?) ?? '',
        businessDate: date,
        shiftId: shiftId,
        type: type,
        delta: delta,
        resultingStock: resulting,
        referenceNumber: reference,
        userId: user.uid,
        username: user.username,
        userName: user.displayName,
        userRole: user.role.wireName,
        lateEntry: lateEntry,
      );

      // Both writes, or neither.
      txn.update(itemRef, {
        'currentStock': resulting,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      txn.set(movementRef, movement.toFirestore());
    });

    final written = await movementRef.get();
    return Movement.fromFirestore(written);
  }

  /// Every movement filed under a business date, oldest first — the input the
  /// closing report is built from.
  Future<List<Movement>> forBusinessDate(String businessDate) async {
    final snap = await _movements
        .where('businessDate', isEqualTo: businessDate)
        .orderBy('createdAt')
        .get();
    return snap.docs.map(Movement.fromFirestore).toList();
  }

  /// The whole ledger, newest first, for the read-only transactions view.
  Stream<List<Movement>> watchRecent({int limit = 200}) {
    return _movements
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Movement.fromFirestore).toList());
  }

  Stream<List<Movement>> watchForBusinessDate(String businessDate) {
    return _movements
        .where('businessDate', isEqualTo: businessDate)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Movement.fromFirestore).toList());
  }

  Stream<List<Movement>> watchRecentForItem(String itemId, {int limit = 25}) {
    return _movements
        .where('itemId', isEqualTo: itemId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Movement.fromFirestore).toList());
  }

  Stream<List<Movement>> watchRecentForUser(String userId, {int limit = 25}) {
    return _movements
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Movement.fromFirestore).toList());
  }
}
