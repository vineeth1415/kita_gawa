import '../models/item.dart';
import '../models/movement.dart';
import '../models/shift_report.dart';

/// Turns a day's ledger into the closing report.
///
/// Pure: no Firebase, no Flutter, no clock. Everything it needs is passed in,
/// which is what makes the day-end arithmetic — the part of this app that has
/// to be right — directly unit-testable.
class ReportBuilder {
  const ReportBuilder._();

  /// One line per item in the catalogue, not merely per item that moved.
  ///
  /// An untouched item still gets a row showing its unchanged stock, so the
  /// sealed report is a complete picture of the warehouse at close rather
  /// than a diff. That is what makes it useful "for future reference" months
  /// later, when today's item list no longer exists in the same form.
  static List<ShiftReportLine> buildLines({
    required List<Item> items,
    required List<Movement> movements,
  }) {
    final byItem = <String, List<Movement>>{};
    for (final movement in movements) {
      byItem.putIfAbsent(movement.itemId, () => []).add(movement);
    }
    for (final entry in byItem.entries) {
      entry.value.sort(_byCreatedAt);
    }

    final lines = <ShiftReportLine>[];

    for (final item in items) {
      final itemMovements = byItem.remove(item.id);

      if (itemMovements == null || itemMovements.isEmpty) {
        lines.add(
          ShiftReportLine(
            itemId: item.id,
            code: item.code,
            name: item.name,
            openingStock: item.currentStock,
            inwardQty: 0,
            dispatchQty: 0,
            adjustmentQty: 0,
            closingStock: item.currentStock,
          ),
        );
        continue;
      }

      lines.add(
        _lineFromMovements(
          itemId: item.id,
          code: item.code,
          name: item.name,
          movements: itemMovements,
        ),
      );
    }

    // Movements can outlive the item they refer to (an admin may delete an
    // item mid-day). Their history still belongs on the report, carried by
    // the item code and name denormalised onto each movement.
    for (final entry in byItem.entries) {
      final first = entry.value.first;
      lines.add(
        _lineFromMovements(
          itemId: entry.key,
          code: first.itemCode,
          name: first.itemName,
          movements: entry.value,
        ),
      );
    }

    lines.sort((a, b) {
      final byCode = a.code.toLowerCase().compareTo(b.code.toLowerCase());
      return byCode != 0
          ? byCode
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return lines;
  }

  static ShiftReportLine _lineFromMovements({
    required String itemId,
    required String code,
    required String name,
    required List<Movement> movements,
  }) {
    final first = movements.first;
    final last = movements.last;

    // The opening figure is recovered from the ledger itself: the stock that
    // must have existed before the day's first movement was applied.
    final opening = first.resultingStock - first.delta;

    var inward = 0;
    var dispatch = 0;
    var adjustment = 0;
    for (final m in movements) {
      switch (m.type) {
        case MovementType.inward:
          inward += m.delta;
        case MovementType.dispatch:
          dispatch += -m.delta;
        case MovementType.auditAdjustment:
          adjustment += m.delta;
      }
    }

    return ShiftReportLine(
      itemId: itemId,
      code: code,
      name: name,
      openingStock: opening,
      inwardQty: inward,
      dispatchQty: dispatch,
      adjustmentQty: adjustment,
      closingStock: last.resultingStock,
    );
  }

  static ShiftReportTotals buildTotals({
    required List<Movement> movements,
  }) {
    var inward = 0;
    var dispatch = 0;
    var adjustment = 0;
    final touched = <String>{};

    for (final m in movements) {
      touched.add(m.itemId);
      switch (m.type) {
        case MovementType.inward:
          inward += m.delta;
        case MovementType.dispatch:
          dispatch += -m.delta;
        case MovementType.auditAdjustment:
          adjustment += m.delta;
      }
    }

    return ShiftReportTotals(
      inwardQty: inward,
      dispatchQty: dispatch,
      adjustmentQty: adjustment,
      movementCount: movements.length,
      itemsTouched: touched.length,
    );
  }

  /// Every distinct reference number seen during the day, so a closed report
  /// can be reconciled against the paperwork without reading every line.
  static List<String> collectReferences(List<Movement> movements) {
    final refs = movements
        .map((m) => m.referenceNumber)
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();
    refs.sort();
    return refs;
  }

  /// Null timestamps sort last: a movement whose server timestamp has not
  /// landed yet is necessarily the most recent one this device has seen.
  static int _byCreatedAt(Movement a, Movement b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  }
}
