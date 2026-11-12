import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftStatus { open, closed }

/// A single working day.
///
/// The document id IS the business date (`YYYY-MM-DD`), which makes "one shift
/// per day" a structural property of the database rather than a rule the code
/// has to remember to enforce: a second open for the same day would collide
/// with an existing document.
class Shift {
  final String businessDate;
  final ShiftStatus status;
  final DateTime? openedAt;
  final String openedBy;
  final String openedByName;
  final DateTime? closedAt;
  final String? closedBy;
  final String? closedByName;

  const Shift({
    required this.businessDate,
    required this.status,
    this.openedAt,
    required this.openedBy,
    required this.openedByName,
    this.closedAt,
    this.closedBy,
    this.closedByName,
  });

  String get id => businessDate;
  bool get isOpen => status == ShiftStatus.open;

  Map<String, Object?> toFirestoreOpen() => {
    'businessDate': businessDate,
    'status': 'open',
    'openedAt': FieldValue.serverTimestamp(),
    'openedBy': openedBy,
    'openedByName': openedByName,
    'closedAt': null,
    'closedBy': null,
    'closedByName': null,
  };

  factory Shift.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Shift(
      businessDate: (data['businessDate'] as String?) ?? doc.id,
      status: (data['status'] as String?) == 'closed'
          ? ShiftStatus.closed
          : ShiftStatus.open,
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      openedBy: (data['openedBy'] as String?) ?? '',
      openedByName: (data['openedByName'] as String?) ?? '',
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      closedBy: data['closedBy'] as String?,
      closedByName: data['closedByName'] as String?,
    );
  }
}
