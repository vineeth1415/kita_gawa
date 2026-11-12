import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditSessionStatus { open, submitted }

/// One physical stock verification walk-through by an auditor.
class AuditSession {
  final String id;
  final AuditSessionStatus status;
  final String businessDate;
  final DateTime? startedAt;
  final String startedBy;
  final String startedByName;
  final DateTime? submittedAt;
  final int itemsCounted;
  final int itemsWithVariance;

  /// Sum of |counted - system| across the session, so a report can state how
  /// far the books were off in one figure.
  final int totalVariance;

  /// Whether the auditor chose to write corrections back into stock.
  final bool correctionsApplied;

  const AuditSession({
    required this.id,
    required this.status,
    required this.businessDate,
    this.startedAt,
    required this.startedBy,
    required this.startedByName,
    this.submittedAt,
    this.itemsCounted = 0,
    this.itemsWithVariance = 0,
    this.totalVariance = 0,
    this.correctionsApplied = false,
  });

  bool get isOpen => status == AuditSessionStatus.open;

  Map<String, Object?> toFirestoreStart() => {
    'status': 'open',
    'businessDate': businessDate,
    'startedAt': FieldValue.serverTimestamp(),
    'startedBy': startedBy,
    'startedByName': startedByName,
    'submittedAt': null,
    'itemsCounted': 0,
    'itemsWithVariance': 0,
    'totalVariance': 0,
    'correctionsApplied': false,
  };

  factory AuditSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AuditSession(
      id: doc.id,
      status: (data['status'] as String?) == 'submitted'
          ? AuditSessionStatus.submitted
          : AuditSessionStatus.open,
      businessDate: (data['businessDate'] as String?) ?? '',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      startedBy: (data['startedBy'] as String?) ?? '',
      startedByName: (data['startedByName'] as String?) ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      itemsCounted: (data['itemsCounted'] as num?)?.toInt() ?? 0,
      itemsWithVariance: (data['itemsWithVariance'] as num?)?.toInt() ?? 0,
      totalVariance: (data['totalVariance'] as num?)?.toInt() ?? 0,
      correctionsApplied: (data['correctionsApplied'] as bool?) ?? false,
    );
  }
}

/// One item counted during an audit session.
class AuditCount {
  final String itemId;
  final String code;
  final String name;
  final int systemStock;
  final int countedStock;

  const AuditCount({
    required this.itemId,
    required this.code,
    required this.name,
    required this.systemStock,
    required this.countedStock,
  });

  int get variance => countedStock - systemStock;
  bool get hasVariance => variance != 0;

  Map<String, Object?> toFirestore() => {
    'itemId': itemId,
    'code': code,
    'name': name,
    'systemStock': systemStock,
    'countedStock': countedStock,
    'variance': variance,
    'countedAt': FieldValue.serverTimestamp(),
  };

  factory AuditCount.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AuditCount(
      itemId: (data['itemId'] as String?) ?? doc.id,
      code: (data['code'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      systemStock: (data['systemStock'] as num?)?.toInt() ?? 0,
      countedStock: (data['countedStock'] as num?)?.toInt() ?? 0,
    );
  }
}
