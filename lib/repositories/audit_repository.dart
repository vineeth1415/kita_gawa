import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/audit_session.dart';
import '../models/item.dart';
import '../utils/business_date.dart';
import 'collections.dart';
import 'movement_repository.dart';

class AuditRepository {
  final FirebaseFirestore _db;
  final MovementRepository _movements;

  AuditRepository({
    FirebaseFirestore? firestore,
    MovementRepository? movementRepository,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _movements =
           movementRepository ??
           MovementRepository(
             firestore: firestore ?? FirebaseFirestore.instance,
           );

  JsonCollection get _sessions => _db.collection(Collections.auditSessions);

  Stream<List<AuditSession>> watchSessions({int limit = 50}) {
    return _sessions
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AuditSession.fromFirestore).toList());
  }

  Future<AuditSession?> fetchOpenSessionFor(String uid) async {
    final snap = await _sessions
        .where('startedBy', isEqualTo: uid)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AuditSession.fromFirestore(snap.docs.first);
  }

  Future<AuditSession> startSession({required AppUser user}) async {
    final ref = _sessions.doc();
    final session = AuditSession(
      id: ref.id,
      status: AuditSessionStatus.open,
      businessDate: todayBusinessDate(),
      startedBy: user.uid,
      startedByName: user.displayName,
    );
    await ref.set(session.toFirestoreStart());
    return AuditSession.fromFirestore(await ref.get());
  }

  Stream<List<AuditCount>> watchCounts(String sessionId) {
    return _sessions
        .doc(sessionId)
        .collection(Collections.auditCounts)
        .orderBy('code')
        .snapshots()
        .map((snap) => snap.docs.map(AuditCount.fromFirestore).toList());
  }

  Future<List<AuditCount>> fetchCounts(String sessionId) async {
    final snap = await _sessions
        .doc(sessionId)
        .collection(Collections.auditCounts)
        .orderBy('code')
        .get();
    return snap.docs.map(AuditCount.fromFirestore).toList();
  }

  /// Records a physical count against an item. The system figure is captured
  /// at counting time so the variance reflects what the books said when the
  /// auditor actually looked at the shelf.
  Future<void> recordCount({
    required String sessionId,
    required Item item,
    required int countedStock,
  }) {
    final count = AuditCount(
      itemId: item.id,
      code: item.code,
      name: item.name,
      systemStock: item.currentStock,
      countedStock: countedStock,
    );
    return _sessions
        .doc(sessionId)
        .collection(Collections.auditCounts)
        .doc(item.id)
        .set(count.toFirestore());
  }

  /// Submits the session and, when asked, writes the variances back into
  /// stock as `audit_adjustment` movements.
  ///
  /// Corrections go through MovementRepository like every other stock change,
  /// so an audit correction is as traceable as an inward or a dispatch —
  /// there is no back door that quietly rewrites a stock figure.
  Future<AuditSession> submitSession({
    required AuditSession session,
    required AppUser user,
    required bool applyCorrections,
    String? shiftId,
  }) async {
    final counts = await fetchCounts(session.id);
    final withVariance = counts.where((c) => c.hasVariance).toList();

    if (applyCorrections) {
      // A short, stable reference tying every correction back to this
      // session, and still matching the 4-16 alphanumeric rule.
      final reference = _auditReference(session.id);
      for (final count in withVariance) {
        await _movements.recordAuditAdjustment(
          itemId: count.itemId,
          delta: count.variance,
          referenceNumber: reference,
          user: user,
          shiftId: shiftId,
          businessDate: session.businessDate,
        );
      }
    }

    await _sessions.doc(session.id).update({
      'status': 'submitted',
      'submittedAt': FieldValue.serverTimestamp(),
      'itemsCounted': counts.length,
      'itemsWithVariance': withVariance.length,
      'totalVariance': withVariance.fold<int>(
        0,
        (total, c) => total + c.variance.abs(),
      ),
      'correctionsApplied': applyCorrections,
    });

    return AuditSession.fromFirestore(await _sessions.doc(session.id).get());
  }

  /// `AUD` + the first 9 characters of the session id, upper-cased: 12
  /// characters of `[A-Z0-9]`, inside the 4-16 reference format.
  static String _auditReference(String sessionId) {
    final cleaned = sessionId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final tail = cleaned.length <= 9 ? cleaned : cleaned.substring(0, 9);
    return 'AUD${tail.toUpperCase()}';
  }
}
