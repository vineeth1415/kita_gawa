import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/shift.dart';
import 'collections.dart';

class ShiftAlreadyOpenException implements Exception {
  final String businessDate;
  ShiftAlreadyOpenException(this.businessDate);
}

class ShiftAlreadyClosedException implements Exception {
  final String businessDate;
  ShiftAlreadyClosedException(this.businessDate);
}

/// Raised when a store user tries to start a day while a different date is
/// still the working day. Only one day may be open at a time.
class AnotherDayOpenException implements Exception {
  final String openBusinessDate;
  AnotherDayOpenException(this.openBusinessDate);
}

class NoOpenShiftException implements Exception {}

/// Shifts are keyed by business date, so "one shift per day" needs no
/// uniqueness check — the document either exists for that date or it does not.
///
/// Which date is *the* working day is a second question, answered by the
/// `settings/workingDay` pointer: store staff select a date in the morning
/// and every device follows that document, so two store phones never file
/// the same day's entries under different dates. The pointer is set and
/// cleared in the same transactions that open and close the shift, so it can
/// never point at a closed day or at nothing while a day is open.
class ShiftRepository {
  final FirebaseFirestore _db;

  ShiftRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  JsonCollection get _shifts => _db.collection(Collections.shifts);
  JsonDocument get _workingDay =>
      _db.collection(Collections.settings).doc(Collections.workingDayDoc);

  Stream<Shift?> watchShiftFor(String businessDate) {
    return _shifts.doc(businessDate).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Shift.fromFirestore(doc);
    });
  }

  Future<Shift?> fetchShiftFor(String businessDate) async {
    final doc = await _shifts.doc(businessDate).get();
    if (!doc.exists) return null;
    return Shift.fromFirestore(doc);
  }

  /// The business date the store is currently working on, or null when no
  /// day has been selected (or the last one was closed).
  Stream<String?> watchWorkingDay() {
    return _workingDay.snapshots().map(_workingDateOf);
  }

  Future<String?> fetchWorkingDay() async =>
      _workingDateOf(await _workingDay.get());

  static String? _workingDateOf(DocumentSnapshot<Json> doc) {
    if (!doc.exists) return null;
    final value = doc.data()?['businessDate'] as String?;
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Selects [businessDate] as the working day. Runs in a transaction so that
  /// two store devices tapping "Start day" at the same moment cannot both
  /// succeed, and so that a day can never be opened while another is open.
  Future<Shift> openDay({
    required String businessDate,
    required AppUser user,
  }) async {
    final ref = _shifts.doc(businessDate);

    await _db.runTransaction((txn) async {
      final current = _workingDateOf(await txn.get(_workingDay));
      if (current != null) {
        throw current == businessDate
            ? ShiftAlreadyOpenException(businessDate)
            : AnotherDayOpenException(current);
      }

      final snap = await txn.get(ref);
      if (snap.exists) {
        final status = (snap.data() ?? const {})['status'] as String?;
        // Reopening a closed day would let movements land after its report
        // was sealed, so it is refused outright.
        throw status == 'closed'
            ? ShiftAlreadyClosedException(businessDate)
            : ShiftAlreadyOpenException(businessDate);
      }
      txn.set(ref, {
        'businessDate': businessDate,
        'status': 'open',
        'openedAt': FieldValue.serverTimestamp(),
        'openedBy': user.uid,
        'openedByName': user.displayName,
        'closedAt': null,
        'closedBy': null,
        'closedByName': null,
      });
      txn.set(_workingDay, {
        'businessDate': businessDate,
        'openedAt': FieldValue.serverTimestamp(),
        'openedBy': user.uid,
        'openedByName': user.displayName,
      });
    });

    return Shift.fromFirestore(await ref.get());
  }

  /// Marks the day closed and clears the working-day pointer. The report
  /// itself is written by ReportRepository, which calls this last so a
  /// failure to build the report leaves the day open and retryable.
  Future<Shift> closeDay({
    required String businessDate,
    required AppUser user,
  }) async {
    final ref = _shifts.doc(businessDate);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw NoOpenShiftException();
      }
      final status = (snap.data() ?? const {})['status'] as String?;
      if (status == 'closed') {
        throw ShiftAlreadyClosedException(businessDate);
      }
      final pointer = _workingDateOf(await txn.get(_workingDay));

      txn.update(ref, {
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': user.uid,
        'closedByName': user.displayName,
      });
      // Only clear the pointer if it is ours: closing a stale shift must not
      // pull the rug from under a different day someone else is working on.
      if (pointer == businessDate) {
        txn.set(_workingDay, {
          'businessDate': null,
          'closedAt': FieldValue.serverTimestamp(),
          'closedBy': user.uid,
          'closedByName': user.displayName,
        });
      }
    });

    return Shift.fromFirestore(await ref.get());
  }

  Stream<List<Shift>> watchHistory({int limit = 60}) {
    return _shifts
        .orderBy('businessDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Shift.fromFirestore).toList());
  }
}
