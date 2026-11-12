import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-item breakdown for one closed day. Stored as documents in the
/// `lines` subcollection of the report rather than as an array field, so a
/// large catalogue can never push the parent past Firestore's 1 MB document
/// ceiling.
class ShiftReportLine {
  final String itemId;
  final String code;
  final String name;
  final int openingStock;
  final int inwardQty;
  final int dispatchQty;
  final int adjustmentQty;
  final int closingStock;

  const ShiftReportLine({
    required this.itemId,
    required this.code,
    required this.name,
    required this.openingStock,
    required this.inwardQty,
    required this.dispatchQty,
    required this.adjustmentQty,
    required this.closingStock,
  });

  int get netChange => closingStock - openingStock;

  Map<String, Object?> toFirestore() => {
    'itemId': itemId,
    'code': code,
    'name': name,
    'openingStock': openingStock,
    'inwardQty': inwardQty,
    'dispatchQty': dispatchQty,
    'adjustmentQty': adjustmentQty,
    'closingStock': closingStock,
  };

  factory ShiftReportLine.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ShiftReportLine(
      itemId: (data['itemId'] as String?) ?? doc.id,
      code: (data['code'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      openingStock: (data['openingStock'] as num?)?.toInt() ?? 0,
      inwardQty: (data['inwardQty'] as num?)?.toInt() ?? 0,
      dispatchQty: (data['dispatchQty'] as num?)?.toInt() ?? 0,
      adjustmentQty: (data['adjustmentQty'] as num?)?.toInt() ?? 0,
      closingStock: (data['closingStock'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShiftReportTotals {
  final int inwardQty;
  final int dispatchQty;
  final int adjustmentQty;
  final int movementCount;
  final int itemsTouched;

  const ShiftReportTotals({
    this.inwardQty = 0,
    this.dispatchQty = 0,
    this.adjustmentQty = 0,
    this.movementCount = 0,
    this.itemsTouched = 0,
  });

  int get netChange => inwardQty - dispatchQty + adjustmentQty;

  Map<String, Object?> toMap() => {
    'inwardQty': inwardQty,
    'dispatchQty': dispatchQty,
    'adjustmentQty': adjustmentQty,
    'movementCount': movementCount,
    'itemsTouched': itemsTouched,
    'netChange': netChange,
  };

  factory ShiftReportTotals.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return ShiftReportTotals(
      inwardQty: (map['inwardQty'] as num?)?.toInt() ?? 0,
      dispatchQty: (map['dispatchQty'] as num?)?.toInt() ?? 0,
      adjustmentQty: (map['adjustmentQty'] as num?)?.toInt() ?? 0,
      movementCount: (map['movementCount'] as num?)?.toInt() ?? 0,
      itemsTouched: (map['itemsTouched'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The permanent record produced when the store closes the working day.
///
/// Sealed on write: firestore.rules denies update and delete, because the
/// whole purpose of this document is to be trustworthy after the fact.
class ShiftReport {
  final String businessDate;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String openedByName;
  final String closedByName;
  final ShiftReportTotals totals;
  final List<String> referenceNumbers;
  final int auditSessionsSubmitted;
  final int auditVariancesFound;

  /// Movements posted against days whose report was already sealed, carried
  /// onto this report so they are visible somewhere rather than lost.
  final List<String> lateEntryDates;

  final DateTime? generatedAt;

  const ShiftReport({
    required this.businessDate,
    this.openedAt,
    this.closedAt,
    this.openedByName = '',
    this.closedByName = '',
    this.totals = const ShiftReportTotals(),
    this.referenceNumbers = const [],
    this.auditSessionsSubmitted = 0,
    this.auditVariancesFound = 0,
    this.lateEntryDates = const [],
    this.generatedAt,
  });

  String get id => businessDate;

  Map<String, Object?> toFirestore() => {
    'businessDate': businessDate,
    'openedAt': openedAt == null ? null : Timestamp.fromDate(openedAt!),
    'closedAt': closedAt == null ? null : Timestamp.fromDate(closedAt!),
    'openedByName': openedByName,
    'closedByName': closedByName,
    'totals': totals.toMap(),
    'referenceNumbers': referenceNumbers,
    'auditSessionsSubmitted': auditSessionsSubmitted,
    'auditVariancesFound': auditVariancesFound,
    'lateEntryDates': lateEntryDates,
    'generatedAt': FieldValue.serverTimestamp(),
  };

  factory ShiftReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ShiftReport(
      businessDate: (data['businessDate'] as String?) ?? doc.id,
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      openedByName: (data['openedByName'] as String?) ?? '',
      closedByName: (data['closedByName'] as String?) ?? '',
      totals: ShiftReportTotals.fromMap(
        (data['totals'] as Map?)?.cast<String, dynamic>(),
      ),
      referenceNumbers:
          (data['referenceNumbers'] as List?)?.cast<String>() ?? const [],
      auditSessionsSubmitted:
          (data['auditSessionsSubmitted'] as num?)?.toInt() ?? 0,
      auditVariancesFound: (data['auditVariancesFound'] as num?)?.toInt() ?? 0,
      lateEntryDates:
          (data['lateEntryDates'] as List?)?.cast<String>() ?? const [],
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
