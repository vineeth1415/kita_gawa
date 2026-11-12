import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/models/app_user.dart';
import 'package:inventory_app/models/movement.dart';
import 'package:inventory_app/repositories/audit_repository.dart';
import 'package:inventory_app/repositories/item_repository.dart';
import 'package:inventory_app/repositories/movement_repository.dart';
import 'package:inventory_app/utils/validators.dart';

import '../test_helpers.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ItemRepository items;
  late AuditRepository audit;
  late MovementRepository movements;

  final auditor = testUser(
    uid: 'u-audit',
    name: 'Sana',
    role: UserRole.auditor,
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    items = ItemRepository(firestore: db);
    audit = AuditRepository(firestore: db);
    movements = MovementRepository(firestore: db);

    await items.create(
      code: 'BOLT-01',
      name: 'Hex Bolt',
      description: '',
      openingStock: 10,
    );
    await items.create(
      code: 'NUT-02',
      name: 'Lock Nut',
      description: '',
      openingStock: 40,
    );
  });

  Future<int> stockOf(String id) async {
    final doc = await db.collection('items').doc(id).get();
    return (doc.data()!['currentStock'] as num).toInt();
  }

  test('records counts and computes variance against the system figure',
      () async {
    final session = await audit.startSession(user: auditor);
    final all = await items.fetchAll();

    // 8 physically on the shelf where the books say 10.
    await audit.recordCount(
      sessionId: session.id,
      item: all.firstWhere((i) => i.id == 'BOLT-01'),
      countedStock: 8,
    );
    await audit.recordCount(
      sessionId: session.id,
      item: all.firstWhere((i) => i.id == 'NUT-02'),
      countedStock: 40,
    );

    final counts = await audit.fetchCounts(session.id);
    final bolt = counts.firstWhere((c) => c.itemId == 'BOLT-01');
    final nut = counts.firstWhere((c) => c.itemId == 'NUT-02');

    expect(bolt.systemStock, 10);
    expect(bolt.countedStock, 8);
    expect(bolt.variance, -2);
    expect(bolt.hasVariance, isTrue);
    expect(nut.variance, 0);
    expect(nut.hasVariance, isFalse);
  });

  test('submitting without corrections records the count but not the stock',
      () async {
    final session = await audit.startSession(user: auditor);
    final all = await items.fetchAll();
    await audit.recordCount(
      sessionId: session.id,
      item: all.firstWhere((i) => i.id == 'BOLT-01'),
      countedStock: 8,
    );

    final submitted = await audit.submitSession(
      session: session,
      user: auditor,
      applyCorrections: false,
    );

    expect(submitted.isOpen, isFalse);
    expect(submitted.itemsCounted, 1);
    expect(submitted.itemsWithVariance, 1);
    expect(submitted.totalVariance, 2);
    expect(submitted.correctionsApplied, isFalse);
    expect(await stockOf('BOLT-01'), 10, reason: 'stock left as it was');
    expect((await db.collection('movements').get()).docs, isEmpty);
  });

  test('submitting with corrections writes adjustments through the ledger',
      () async {
    final session = await audit.startSession(user: auditor);
    final all = await items.fetchAll();
    await audit.recordCount(
      sessionId: session.id,
      item: all.firstWhere((i) => i.id == 'BOLT-01'),
      countedStock: 8,
    );
    await audit.recordCount(
      sessionId: session.id,
      item: all.firstWhere((i) => i.id == 'NUT-02'),
      countedStock: 43,
    );

    final submitted = await audit.submitSession(
      session: session,
      user: auditor,
      applyCorrections: true,
    );

    expect(submitted.correctionsApplied, isTrue);
    expect(submitted.itemsWithVariance, 2);
    expect(submitted.totalVariance, 5, reason: '|-2| + |+3|');

    expect(await stockOf('BOLT-01'), 8);
    expect(await stockOf('NUT-02'), 43);

    // A correction is a normal ledger entry, not a quiet overwrite.
    final ledger = await movements.forBusinessDate(session.businessDate);
    expect(ledger, hasLength(2));
    expect(
      ledger.every((m) => m.type == MovementType.auditAdjustment),
      isTrue,
    );
    expect(ledger.map((m) => m.delta).toSet(), {-2, 3});
  });

  test('the audit reference satisfies the same 4-16 rule as any other',
      () async {
    final session = await audit.startSession(user: auditor);
    final all = await items.fetchAll();
    await audit.recordCount(
      sessionId: session.id,
      item: all.first,
      countedStock: 999,
    );
    await audit.submitSession(
      session: session,
      user: auditor,
      applyCorrections: true,
    );

    final ledger = await movements.forBusinessDate(session.businessDate);
    final reference = ledger.single.referenceNumber;
    expect(validateReferenceNumber(reference), isNull);
    expect(reference, startsWith('AUD'));
  });

  test('an auditor resumes their open session rather than starting a second',
      () async {
    final first = await audit.startSession(user: auditor);
    final found = await audit.fetchOpenSessionFor(auditor.uid);
    expect(found!.id, first.id);

    await audit.submitSession(
      session: first,
      user: auditor,
      applyCorrections: false,
    );
    expect(await audit.fetchOpenSessionFor(auditor.uid), isNull);
  });
}
