import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/models/movement.dart';
import 'package:inventory_app/services/report_builder.dart';

import '../test_helpers.dart';

void main() {
  group('buildLines', () {
    test('recovers the opening figure from the first movement', () {
      // Stock stood at 8; a delivery of 5 took it to 13.
      final movements = [
        testMovement(delta: 5, resultingStock: 13),
      ];
      final lines = ReportBuilder.buildLines(
        items: [testItem(currentStock: 13)],
        movements: movements,
      );

      expect(lines.single.openingStock, 8);
      expect(lines.single.closingStock, 13);
      expect(lines.single.inwardQty, 5);
      expect(lines.single.netChange, 5);
    });

    test('separates inward, dispatch and audit adjustment per item', () {
      final movements = [
        testMovement(
          id: 'm1',
          delta: 10,
          resultingStock: 10,
          createdAt: DateTime(2026, 5, 10, 9),
        ),
        testMovement(
          id: 'm2',
          type: MovementType.dispatch,
          delta: -4,
          resultingStock: 6,
          createdAt: DateTime(2026, 5, 10, 11),
        ),
        testMovement(
          id: 'm3',
          type: MovementType.auditAdjustment,
          delta: -1,
          resultingStock: 5,
          createdAt: DateTime(2026, 5, 10, 16),
        ),
      ];

      final line = ReportBuilder.buildLines(
        items: [testItem(currentStock: 5)],
        movements: movements,
      ).single;

      expect(line.openingStock, 0);
      expect(line.inwardQty, 10);
      expect(line.dispatchQty, 4, reason: 'stored as a positive magnitude');
      expect(line.adjustmentQty, -1, reason: 'adjustments keep their sign');
      expect(line.closingStock, 5);
      expect(line.netChange, 5);
    });

    test('orders by timestamp, not by the order movements arrive in', () {
      // Deliberately out of order: the later movement is listed first.
      final movements = [
        testMovement(
          id: 'later',
          type: MovementType.dispatch,
          delta: -3,
          resultingStock: 7,
          createdAt: DateTime(2026, 5, 10, 15),
        ),
        testMovement(
          id: 'earlier',
          delta: 10,
          resultingStock: 10,
          createdAt: DateTime(2026, 5, 10, 8),
        ),
      ];

      final line = ReportBuilder.buildLines(
        items: [testItem(currentStock: 7)],
        movements: movements,
      ).single;

      expect(line.openingStock, 0, reason: 'from the 08:00 movement');
      expect(line.closingStock, 7, reason: 'from the 15:00 movement');
    });

    test('includes untouched items so the report is a full snapshot', () {
      final lines = ReportBuilder.buildLines(
        items: [
          testItem(id: 'BOLT-01', name: 'Hex Bolt', currentStock: 12),
          testItem(id: 'NUT-02', name: 'Lock Nut', currentStock: 40),
        ],
        movements: [testMovement(delta: 2, resultingStock: 12)],
      );

      expect(lines, hasLength(2));
      final untouched = lines.firstWhere((l) => l.itemId == 'NUT-02');
      expect(untouched.openingStock, 40);
      expect(untouched.closingStock, 40);
      expect(untouched.inwardQty, 0);
      expect(untouched.dispatchQty, 0);
      expect(untouched.netChange, 0);
    });

    test('keeps history for an item deleted mid-day', () {
      final lines = ReportBuilder.buildLines(
        items: const [],
        movements: [
          testMovement(
            itemId: 'GONE-01',
            itemCode: 'GONE-01',
            itemName: 'Removed Part',
            delta: 3,
            resultingStock: 3,
          ),
        ],
      );

      expect(lines.single.code, 'GONE-01');
      expect(lines.single.name, 'Removed Part');
      expect(lines.single.inwardQty, 3);
    });

    test('counts movements posted outside a shift', () {
      // Front office may record inward before the back office opens the day;
      // shiftId is null, but businessDate still files it on this report.
      final lines = ReportBuilder.buildLines(
        items: [testItem(currentStock: 6)],
        movements: [
          testMovement(shiftId: null, delta: 6, resultingStock: 6),
        ],
      );

      expect(lines.single.inwardQty, 6);
      expect(lines.single.closingStock, 6);
    });

    test('sorts lines by item code', () {
      final lines = ReportBuilder.buildLines(
        items: [
          testItem(id: 'ZINC-9', name: 'Zinc'),
          testItem(id: 'ALLOY-1', name: 'Alloy'),
          testItem(id: 'MILD-5', name: 'Mild'),
        ],
        movements: const [],
      );
      expect(lines.map((l) => l.code), ['ALLOY-1', 'MILD-5', 'ZINC-9']);
    });
  });

  group('buildTotals', () {
    test('aggregates across items and counts those touched', () {
      final totals = ReportBuilder.buildTotals(
        movements: [
          testMovement(itemId: 'A', delta: 10, resultingStock: 10),
          testMovement(itemId: 'B', delta: 5, resultingStock: 5),
          testMovement(
            itemId: 'A',
            type: MovementType.dispatch,
            delta: -3,
            resultingStock: 7,
          ),
          testMovement(
            itemId: 'A',
            type: MovementType.auditAdjustment,
            delta: 2,
            resultingStock: 9,
          ),
        ],
      );

      expect(totals.inwardQty, 15);
      expect(totals.dispatchQty, 3);
      expect(totals.adjustmentQty, 2);
      expect(totals.movementCount, 4);
      expect(totals.itemsTouched, 2, reason: 'A counted once, not three times');
      expect(totals.netChange, 14);
    });

    test('is all zeros for a day with no movement', () {
      final totals = ReportBuilder.buildTotals(movements: const []);
      expect(totals.movementCount, 0);
      expect(totals.itemsTouched, 0);
      expect(totals.netChange, 0);
    });
  });

  group('collectReferences', () {
    test('deduplicates and sorts', () {
      final refs = ReportBuilder.collectReferences([
        testMovement(referenceNumber: 'INV002', delta: 1, resultingStock: 1),
        testMovement(referenceNumber: 'INV001', delta: 1, resultingStock: 2),
        testMovement(referenceNumber: 'INV002', delta: 1, resultingStock: 3),
      ]);
      expect(refs, ['INV001', 'INV002']);
    });
  });
}
