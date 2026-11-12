import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/audit_session.dart';
import '../models/item.dart';
import '../models/movement.dart';
import '../models/shift.dart';
import '../models/shift_report.dart';
import '../services/report_builder.dart';
import 'collections.dart';
import 'item_repository.dart';
import 'movement_repository.dart';
import 'shift_repository.dart';

class ReportAlreadyExistsException implements Exception {
  final String businessDate;
  ReportAlreadyExistsException(this.businessDate);
}

/// Builds and stores the permanent day-end report.
class ReportRepository {
  final FirebaseFirestore _db;
  final MovementRepository _movements;
  final ItemRepository _items;
  final ShiftRepository _shifts;

  ReportRepository({
    FirebaseFirestore? firestore,
    MovementRepository? movementRepository,
    ItemRepository? itemRepository,
    ShiftRepository? shiftRepository,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _movements =
           movementRepository ??
           MovementRepository(
             firestore: firestore ?? FirebaseFirestore.instance,
           ),
       _items =
           itemRepository ??
           ItemRepository(firestore: firestore ?? FirebaseFirestore.instance),
       _shifts =
           shiftRepository ??
           ShiftRepository(firestore: firestore ?? FirebaseFirestore.instance);

  JsonCollection get _reports => _db.collection(Collections.shiftReports);

  /// Closes the day and seals its report.
  ///
  /// Order matters: the report is written first, then the shift is marked
  /// closed. If report generation fails halfway, the day stays open and the
  /// store can simply try again — the alternative order would leave a
  /// closed day with no report and no way to produce one.
  Future<ShiftReport> closeDayAndBuildReport({
    required String businessDate,
    required AppUser user,
  }) async {
    final existing = await _reports.doc(businessDate).get();
    if (existing.exists) {
      throw ReportAlreadyExistsException(businessDate);
    }

    final shift = await _shifts.fetchShiftFor(businessDate);
    if (shift == null || !shift.isOpen) {
      throw NoOpenShiftException();
    }

    final movements = await _movements.forBusinessDate(businessDate);
    final items = await _items.fetchAll();
    final audit = await _auditSummaryFor(businessDate);
    final lateDates = await _unreportedLateEntryDates(excluding: businessDate);

    final lines = ReportBuilder.buildLines(items: items, movements: movements);
    final totals = ReportBuilder.buildTotals(movements: movements);
    final references = ReportBuilder.collectReferences(movements);

    final report = ShiftReport(
      businessDate: businessDate,
      openedAt: shift.openedAt,
      closedAt: DateTime.now(),
      openedByName: shift.openedByName,
      closedByName: user.displayName,
      totals: totals,
      referenceNumbers: references,
      auditSessionsSubmitted: audit.$1,
      auditVariancesFound: audit.$2,
      lateEntryDates: lateDates,
    );

    final reportRef = _reports.doc(businessDate);

    // Batched so a report is never half-written. Firestore caps a batch at
    // 500 operations, so the lines are chunked and the parent document is
    // written last: until it exists, the report does not exist.
    final lineChunks = _chunk(lines, 450);
    for (final chunk in lineChunks) {
      final batch = _db.batch();
      for (final line in chunk) {
        batch.set(
          reportRef.collection(Collections.reportLines).doc(line.itemId),
          line.toFirestore(),
        );
      }
      await batch.commit();
    }
    await reportRef.set(report.toFirestore());

    await _shifts.closeDay(businessDate: businessDate, user: user);

    return ShiftReport.fromFirestore(await reportRef.get());
  }

  Future<ShiftReport?> fetch(String businessDate) async {
    final doc = await _reports.doc(businessDate).get();
    if (!doc.exists) return null;
    return ShiftReport.fromFirestore(doc);
  }

  Stream<List<ShiftReport>> watchHistory({int limit = 60}) {
    return _reports
        .orderBy('businessDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ShiftReport.fromFirestore).toList());
  }

  Future<List<ShiftReportLine>> fetchLines(String businessDate) async {
    final snap = await _reports
        .doc(businessDate)
        .collection(Collections.reportLines)
        .orderBy('code')
        .get();
    return snap.docs.map(ShiftReportLine.fromFirestore).toList();
  }

  /// The movements behind a report, for the CSV export and the detail screen.
  Future<List<Movement>> fetchMovements(String businessDate) =>
      _movements.forBusinessDate(businessDate);

  /// (sessions submitted, items found with a variance) for the day.
  Future<(int, int)> _auditSummaryFor(String businessDate) async {
    final snap = await _db
        .collection(Collections.auditSessions)
        .where('businessDate', isEqualTo: businessDate)
        .where('status', isEqualTo: 'submitted')
        .get();
    final sessions = snap.docs.map(AuditSession.fromFirestore).toList();
    final variances = sessions.fold<int>(
      0,
      (total, s) => total + s.itemsWithVariance,
    );
    return (sessions.length, variances);
  }

  /// Days whose report was already sealed but which have since received a
  /// movement. Surfaced on the next report rather than altering the sealed
  /// one, so a closed report is never contradicted after the fact.
  Future<List<String>> _unreportedLateEntryDates({
    required String excluding,
  }) async {
    final snap = await _db
        .collection(Collections.movements)
        .where('lateEntry', isEqualTo: true)
        .get();
    final dates = snap.docs
        .map((d) => (d.data()['businessDate'] as String?) ?? '')
        .where((d) => d.isNotEmpty && d != excluding)
        .toSet()
        .toList();
    dates.sort();
    return dates;
  }

  static List<List<T>> _chunk<T>(List<T> source, int size) {
    if (source.isEmpty) return const [];
    final chunks = <List<T>>[];
    for (var i = 0; i < source.length; i += size) {
      chunks.add(
        source.sublist(i, i + size > source.length ? source.length : i + size),
      );
    }
    return chunks;
  }
}

/// Re-exported so callers importing this file get the item type used by
/// [ReportBuilder] without a second import.
typedef ReportItem = Item;
typedef ReportShift = Shift;
