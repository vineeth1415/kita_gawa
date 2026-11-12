import 'package:cloud_firestore/cloud_firestore.dart';

enum MovementType { inward, dispatch, auditAdjustment }

extension MovementTypeCodec on MovementType {
  String get wireName => switch (this) {
    MovementType.inward => 'inward',
    MovementType.dispatch => 'dispatch',
    MovementType.auditAdjustment => 'audit_adjustment',
  };

  String get label => switch (this) {
    MovementType.inward => 'Inward',
    MovementType.dispatch => 'Dispatch',
    MovementType.auditAdjustment => 'Audit adjustment',
  };
}

MovementType movementTypeFromWire(String? value) {
  for (final t in MovementType.values) {
    if (t.wireName == value) return t;
  }
  return MovementType.inward;
}

/// One append-only entry in the stock ledger.
///
/// Movements are never updated or deleted — firestore.rules denies both. A
/// mistake is corrected by posting an opposing movement, so the history of
/// what actually happened stays intact.
class Movement {
  final String id;
  final String itemId;
  final String itemCode;
  final String itemName;

  /// The calendar day this movement belongs to, from the operator's local
  /// clock. The closing report aggregates on this, not on [createdAt].
  final String businessDate;

  /// The working day this was posted into. Always set for store entries
  /// (nothing can be recorded without a selected day); may be null on an
  /// auditor's adjustment posted while no day is open.
  final String? shiftId;

  final MovementType type;

  /// Signed: positive for inward, negative for dispatch, either way for an
  /// audit correction.
  final int delta;
  final int resultingStock;
  final String referenceNumber;

  /// Who recorded it: the auth uid (what the rules verify), the login ID
  /// (what a human verifier recognises, e.g. `store-1`) and the display name.
  final String userId;
  final String username;
  final String userName;
  final String userRole;

  /// True when the movement was posted after its day's report was already
  /// sealed. Surfaced separately so a closed report is never contradicted
  /// silently.
  final bool lateEntry;

  final DateTime? createdAt;

  const Movement({
    required this.id,
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    required this.businessDate,
    required this.shiftId,
    required this.type,
    required this.delta,
    required this.resultingStock,
    required this.referenceNumber,
    required this.userId,
    this.username = '',
    required this.userName,
    required this.userRole,
    this.lateEntry = false,
    this.createdAt,
  });

  bool get isInward => delta > 0;
  int get quantity => delta.abs();

  Map<String, Object?> toFirestore() => {
    'itemId': itemId,
    'itemCode': itemCode,
    'itemName': itemName,
    'businessDate': businessDate,
    'shiftId': shiftId,
    'type': type.wireName,
    'delta': delta,
    'resultingStock': resultingStock,
    'referenceNumber': referenceNumber,
    'userId': userId,
    'username': username,
    'userName': userName,
    'userRole': userRole,
    'lateEntry': lateEntry,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory Movement.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Movement(
      id: doc.id,
      itemId: (data['itemId'] as String?) ?? '',
      itemCode: (data['itemCode'] as String?) ?? '',
      itemName: (data['itemName'] as String?) ?? '',
      businessDate: (data['businessDate'] as String?) ?? '',
      shiftId: data['shiftId'] as String?,
      type: movementTypeFromWire(data['type'] as String?),
      delta: (data['delta'] as num?)?.toInt() ?? 0,
      resultingStock: (data['resultingStock'] as num?)?.toInt() ?? 0,
      referenceNumber: (data['referenceNumber'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      userRole: (data['userRole'] as String?) ?? '',
      lateEntry: (data['lateEntry'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
