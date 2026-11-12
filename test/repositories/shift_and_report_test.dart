import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/repositories/item_repository.dart';
import 'package:inventory_app/repositories/movement_repository.dart';
import 'package:inventory_app/repositories/report_repository.dart';
import 'package:inventory_app/repositories/shift_repository.dart';

import '../test_helpers.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ItemRepository items;
  late MovementRepository movements;
  late ShiftRepository shifts;
  late ReportRepository reports;

  const day = '2026-05-10';
  final store1 = testUser(uid: 'u-store1', name: 'Ravi');
  final store2 = testUser(uid: 'u-store2', name: 'Meera');

  setUp(() async {
    db = FakeFirebaseFirestore();
    items = ItemRepository(firestore: db);
    movements = MovementRepository(firestore: db);
    shifts = ShiftRepository(firestore: db);
    reports = ReportRepository(firestore: db);

    await items.create(
      code: 'BOLT-01',
      name: 'Hex Bolt',
      description: 'M8',
      openingStock: 10,
    );
    await items.create(
      code: 'NUT-02',
      name: 'Lock Nut',
      description: '',
      openingStock: 40,
    );
  });

  group('opening the day', () {
    test('creates a shift keyed by the business date', () async {
      final shift = await shifts.openDay(businessDate: day, user: store2);

      expect(shift.id, day);
      expect(shift.isOpen, isTrue);
      expect(shift.openedByName, 'Meera');
    });

    test('refuses a second open for the same day', () async {
      await shifts.openDay(businessDate: day, user: store2);

      expect(
        () => shifts.openDay(businessDate: day, user: store2),
        throwsA(isA<ShiftAlreadyOpenException>()),
      );
    });

    test('refuses to reopen a closed day', () async {
      await shifts.openDay(businessDate: day, user: store2);
      await shifts.closeDay(businessDate: day, user: store2);

      expect(
        () => shifts.openDay(businessDate: day, user: store2),
        throwsA(isA<ShiftAlreadyClosedException>()),
      );
    });

    test('refuses a second day while one is still open', () async {
      await shifts.openDay(businessDate: day, user: store2);

      expect(
        () => shifts.openDay(businessDate: '2026-05-11', user: store1),
        throwsA(
          isA<AnotherDayOpenException>().having(
            (e) => e.openBusinessDate,
            'openBusinessDate',
            day,
          ),
        ),
      );
    });

    test('sets the shared working-day pointer', () async {
      expect(await shifts.fetchWorkingDay(), isNull);
      await shifts.openDay(businessDate: day, user: store2);
      expect(await shifts.fetchWorkingDay(), day);
    });

    test('a closed day frees the pointer for the next date', () async {
      await shifts.openDay(businessDate: day, user: store2);
      await shifts.closeDay(businessDate: day, user: store2);
      expect(await shifts.fetchWorkingDay(), isNull);

      final next = await shifts.openDay(
        businessDate: '2026-05-11',
        user: store1,
      );
      expect(next.isOpen, isTrue);
      expect(await shifts.fetchWorkingDay(), '2026-05-11');
    });

    test('the pointer stream follows open and close', () async {
      final seen = <String?>[];
      final sub = shifts.watchWorkingDay().listen(seen.add);

      await shifts.openDay(businessDate: day, user: store2);
      await shifts.closeDay(businessDate: day, user: store2);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen.last, isNull);
      expect(seen, contains(day));
    });
  });

  group('closing the day and sealing the report', () {
    test('produces totals, lines and references', () async {
      await shifts.openDay(businessDate: day, user: store2);
      await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 5,
        referenceNumber: 'INV2024001',
        user: store1,
        shiftId: day,
        businessDate: day,
      );
      await movements.recordDispatch(
        itemId: 'BOLT-01',
        quantity: 3,
        referenceNumber: 'DIS2024001',
        user: store2,
        shiftId: day,
        businessDate: day,
      );

      final report = await reports.closeDayAndBuildReport(
        businessDate: day,
        user: store2,
      );

      expect(report.totals.inwardQty, 5);
      expect(report.totals.dispatchQty, 3);
      expect(report.totals.movementCount, 2);
      expect(report.totals.itemsTouched, 1);
      expect(report.totals.netChange, 2);
      expect(report.referenceNumbers, ['DIS2024001', 'INV2024001']);
      expect(report.closedByName, 'Meera');

      final lines = await reports.fetchLines(day);
      expect(lines, hasLength(2), reason: 'every item, not just those moved');

      final bolt = lines.firstWhere((l) => l.itemId == 'BOLT-01');
      expect(bolt.openingStock, 10);
      expect(bolt.inwardQty, 5);
      expect(bolt.dispatchQty, 3);
      expect(bolt.closingStock, 12);

      final nut = lines.firstWhere((l) => l.itemId == 'NUT-02');
      expect(nut.openingStock, 40);
      expect(nut.closingStock, 40);
      expect(nut.netChange, 0);
    });

    test('marks the shift closed', () async {
      await shifts.openDay(businessDate: day, user: store2);
      await reports.closeDayAndBuildReport(businessDate: day, user: store2);

      final shift = await shifts.fetchShiftFor(day);
      expect(shift!.isOpen, isFalse);
      expect(shift.closedByName, 'Meera');
    });

    test('entries from both store logins land on the same report', () async {
      await shifts.openDay(businessDate: day, user: store1);
      await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 7,
        referenceNumber: 'GATE0001',
        user: store1,
        shiftId: day,
        businessDate: day,
      );
      await movements.recordDispatch(
        itemId: 'NUT-02',
        quantity: 10,
        referenceNumber: 'DISP0001',
        user: store2,
        shiftId: day,
        businessDate: day,
      );

      final report = await reports.closeDayAndBuildReport(
        businessDate: day,
        user: store2,
      );

      expect(report.totals.inwardQty, 7);
      expect(report.totals.dispatchQty, 10);
      expect(report.totals.movementCount, 2);
      expect(report.openedByName, 'Ravi');
      expect(report.closedByName, 'Meera');
    });

    test('refuses a second close for the same day', () async {
      await shifts.openDay(businessDate: day, user: store2);
      await reports.closeDayAndBuildReport(businessDate: day, user: store2);

      expect(
        () => reports.closeDayAndBuildReport(businessDate: day, user: store2),
        throwsA(isA<ReportAlreadyExistsException>()),
      );
    });

    test('refuses to close a day that was never opened', () async {
      expect(
        () => reports.closeDayAndBuildReport(businessDate: day, user: store2),
        throwsA(isA<NoOpenShiftException>()),
      );
    });

    test('a day with no movement still seals a full stock snapshot', () async {
      await shifts.openDay(businessDate: day, user: store2);
      final report = await reports.closeDayAndBuildReport(
        businessDate: day,
        user: store2,
      );

      expect(report.totals.movementCount, 0);
      final lines = await reports.fetchLines(day);
      expect(lines, hasLength(2));
      expect(lines.every((l) => l.openingStock == l.closingStock), isTrue);
    });

    test('excludes movements belonging to another day', () async {
      await shifts.openDay(businessDate: day, user: store2);
      await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 5,
        referenceNumber: 'TODAY001',
        user: store1,
        shiftId: day,
        businessDate: day,
      );
      await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 99,
        referenceNumber: 'TOMORROW1',
        user: store1,
        shiftId: '2026-05-11',
        businessDate: '2026-05-11',
      );

      final report = await reports.closeDayAndBuildReport(
        businessDate: day,
        user: store2,
      );
      expect(report.totals.inwardQty, 5);
      expect(report.referenceNumbers, ['TODAY001']);
    });
  });
}
