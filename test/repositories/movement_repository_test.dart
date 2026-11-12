import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/models/app_user.dart';
import 'package:inventory_app/models/movement.dart';
import 'package:inventory_app/repositories/item_repository.dart';
import 'package:inventory_app/repositories/movement_repository.dart';

import '../test_helpers.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ItemRepository items;
  late MovementRepository movements;

  setUp(() async {
    db = FakeFirebaseFirestore();
    items = ItemRepository(firestore: db);
    movements = MovementRepository(firestore: db);
    await items.create(
      code: 'BOLT-01',
      name: 'Hex Bolt',
      description: 'M8',
      openingStock: 10,
    );
  });

  Future<int> stockOf(String id) async {
    final doc = await db.collection('items').doc(id).get();
    return (doc.data()!['currentStock'] as num).toInt();
  }

  group('recordInward', () {
    test('raises stock and writes the ledger entry together', () async {
      final movement = await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 5,
        referenceNumber: 'INV2024001',
        user: testUser(),
        shiftId: '2026-05-10',
        businessDate: '2026-05-10',
      );

      expect(await stockOf('BOLT-01'), 15);
      expect(movement.delta, 5);
      expect(movement.resultingStock, 15);
      expect(movement.type, MovementType.inward);
      expect(movement.itemName, 'Hex Bolt');
    });

    test('records who did it: uid, login ID and display name', () async {
      final movement = await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 1,
        referenceNumber: 'WHO00001',
        user: testUser(uid: 'u-store2', name: 'Mahesh'),
        shiftId: '2026-05-10',
        businessDate: '2026-05-10',
      );
      expect(movement.userId, 'u-store2');
      expect(movement.username, 'mahesh');
      expect(movement.userName, 'Mahesh');
      expect(movement.userRole, 'store');
      expect(movement.createdAt, isNotNull);
    });

    test('stores the reference uppercased', () async {
      final movement = await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 1,
        referenceNumber: '  inv2024001 ',
        user: testUser(),
        shiftId: '2026-05-10',
        businessDate: '2026-05-10',
      );
      expect(movement.referenceNumber, 'INV2024001');
    });

    test('rejects a reference that breaks the 4-16 rule', () async {
      expect(
        () => movements.recordInward(
          itemId: 'BOLT-01',
          quantity: 1,
          referenceNumber: 'AB',
          user: testUser(),
          shiftId: '2026-05-10',
          businessDate: '2026-05-10',
        ),
        throwsArgumentError,
      );
      expect(
        await stockOf('BOLT-01'),
        10,
        reason: 'a rejected reference must not move stock',
      );
    });

    test('marks a late entry when told the day is already reported', () async {
      final movement = await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 2,
        referenceNumber: 'LATE0001',
        user: testUser(),
        shiftId: '2026-05-09',
        businessDate: '2026-05-09',
        lateEntry: true,
      );
      expect(movement.lateEntry, isTrue);
    });

    test('fails when the item no longer exists', () async {
      expect(
        () => movements.recordInward(
          itemId: 'DOES-NOT-EXIST',
          quantity: 1,
          referenceNumber: 'REF0001',
          user: testUser(),
          shiftId: '2026-05-10',
          businessDate: '2026-05-10',
        ),
        throwsA(isA<ItemMissingException>()),
      );
    });
  });

  group('recordDispatch', () {
    test('lowers stock and records a negative delta', () async {
      final movement = await movements.recordDispatch(
        itemId: 'BOLT-01',
        quantity: 4,
        referenceNumber: 'DIS2024001',
        user: testUser(role: UserRole.store),
        shiftId: '2026-05-10',
        businessDate: '2026-05-10',
      );

      expect(await stockOf('BOLT-01'), 6);
      expect(movement.delta, -4);
      expect(movement.quantity, 4);
      expect(movement.isInward, isFalse);
      expect(movement.resultingStock, 6);
    });

    test('may take stock to exactly zero', () async {
      await movements.recordDispatch(
        itemId: 'BOLT-01',
        quantity: 10,
        referenceNumber: 'DIS0002',
        user: testUser(role: UserRole.store),
        shiftId: '2026-05-10',
        businessDate: '2026-05-10',
      );
      expect(await stockOf('BOLT-01'), 0);
    });

    test('refuses to go negative and leaves stock untouched', () async {
      await expectLater(
        movements.recordDispatch(
          itemId: 'BOLT-01',
          quantity: 11,
          referenceNumber: 'DIS0003',
          user: testUser(role: UserRole.store),
          shiftId: '2026-05-10',
          businessDate: '2026-05-10',
        ),
        throwsA(
          isA<InsufficientStockException>()
              .having((e) => e.available, 'available', 10)
              .having((e) => e.requested, 'requested', 11),
        ),
      );

      expect(await stockOf('BOLT-01'), 10);
      final ledger = await db.collection('movements').get();
      expect(
        ledger.docs,
        isEmpty,
        reason: 'a refused dispatch must not leave a ledger entry behind',
      );
    });
  });

  group('recordAuditAdjustment', () {
    test('applies a signed correction in either direction', () async {
      await movements.recordAuditAdjustment(
        itemId: 'BOLT-01',
        delta: -2,
        referenceNumber: 'AUDABC12345',
        user: testUser(role: UserRole.auditor),
        businessDate: '2026-05-10',
      );
      expect(await stockOf('BOLT-01'), 8);

      final up = await movements.recordAuditAdjustment(
        itemId: 'BOLT-01',
        delta: 3,
        referenceNumber: 'AUDABC12345',
        user: testUser(role: UserRole.auditor),
        businessDate: '2026-05-10',
      );
      expect(await stockOf('BOLT-01'), 11);
      expect(up.type, MovementType.auditAdjustment);
    });
  });

  group('sequential movements', () {
    test('each entry chains from the previous resulting stock', () async {
      await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 5,
        referenceNumber: 'IN000001',
        user: testUser(),
        shiftId: '2026-05-10',
        businessDate: '2026-05-10',
      );
      await movements.recordDispatch(
        itemId: 'BOLT-01',
        quantity: 3,
        referenceNumber: 'OUT00001',
        user: testUser(role: UserRole.store),
        shiftId: '2026-05-10',
        businessDate: '2026-05-10',
      );

      final ledger = await movements.forBusinessDate('2026-05-10');
      expect(ledger.map((m) => m.resultingStock), [15, 12]);
      expect(await stockOf('BOLT-01'), 12);
    });

    test('forBusinessDate returns only that day', () async {
      await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 1,
        referenceNumber: 'DAY10001',
        user: testUser(),
        shiftId: '2026-05-10',
        businessDate: '2026-05-10',
      );
      await movements.recordInward(
        itemId: 'BOLT-01',
        quantity: 1,
        referenceNumber: 'DAY11001',
        user: testUser(),
        shiftId: '2026-05-11',
        businessDate: '2026-05-11',
      );

      expect(await movements.forBusinessDate('2026-05-10'), hasLength(1));
      expect(await movements.forBusinessDate('2026-05-11'), hasLength(1));
      expect(await movements.forBusinessDate('2026-05-12'), isEmpty);
    });
  });
}
