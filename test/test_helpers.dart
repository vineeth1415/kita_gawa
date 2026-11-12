import 'package:inventory_app/models/app_user.dart';
import 'package:inventory_app/models/item.dart';
import 'package:inventory_app/models/movement.dart';

/// Builders that keep the tests readable: each one names only the fields the
/// test actually cares about.

AppUser testUser({
  String uid = 'u-store1',
  String name = 'Ravi',
  UserRole role = UserRole.store,
}) => AppUser(
  uid: uid,
  username: name.toLowerCase(),
  displayName: name,
  role: role,
  active: true,
);

Item testItem({
  String id = 'BOLT-01',
  String? code,
  String name = 'Hex Bolt',
  int currentStock = 0,
}) => Item(
  id: id,
  code: code ?? id,
  name: name,
  description: '',
  currentStock: currentStock,
);

Movement testMovement({
  String id = 'm1',
  String itemId = 'BOLT-01',
  String itemCode = 'BOLT-01',
  String itemName = 'Hex Bolt',
  String businessDate = '2026-05-10',
  String? shiftId = '2026-05-10',
  MovementType type = MovementType.inward,
  required int delta,
  required int resultingStock,
  String referenceNumber = 'REF0001',
  String userName = 'Ravi',
  DateTime? createdAt,
}) => Movement(
  id: id,
  itemId: itemId,
  itemCode: itemCode,
  itemName: itemName,
  businessDate: businessDate,
  shiftId: shiftId,
  type: type,
  delta: delta,
  resultingStock: resultingStock,
  referenceNumber: referenceNumber,
  userId: 'u-store1',
  username: userName.toLowerCase(),
  userName: userName,
  userRole: 'store',
  createdAt: createdAt ?? DateTime(2026, 5, 10, 9),
);
