import 'package:cloud_firestore/cloud_firestore.dart';

/// The roles the app recognises.
///
/// Stored in Firestore as the snake_case [wireName], which is exactly the
/// string firestore.rules compares against — keep them in sync.
///
/// Four accounts run the warehouse: one admin, one read-only login for
/// management and audit, and two store logins (store-1, store-2). The two
/// store logins share the one [store] role; they are separate accounts only
/// so that entries are attributed to the right person. [auditor] is an optional fifth role that only functions
/// while the admin has audit switched on.
enum UserRole { admin, readOnly, store, auditor }

extension UserRoleCodec on UserRole {
  String get wireName => switch (this) {
    UserRole.admin => 'admin',
    UserRole.readOnly => 'read_only',
    UserRole.store => 'store',
    UserRole.auditor => 'auditor',
  };

  String get label => switch (this) {
    UserRole.admin => 'Administrator',
    UserRole.readOnly => 'Read-only',
    UserRole.store => 'Store',
    UserRole.auditor => 'Auditor',
  };

  String get description => switch (this) {
    UserRole.admin => 'Creates items, manages users, checks reports',
    UserRole.readOnly =>
      'Senior management / audit: views stock, transactions and reports',
    UserRole.store =>
      'Selects the working day, records inward and outward stock, closes the day',
    UserRole.auditor => 'Verifies physical stock against the system',
  };
}

UserRole? userRoleFromWire(String? value) {
  for (final role in UserRole.values) {
    if (role.wireName == value) return role;
  }
  return null;
}

class AppUser {
  final String uid;
  final String username;
  final String displayName;
  final UserRole role;
  final bool active;
  final DateTime? createdAt;
  final String? createdBy;

  /// Set when an admin switches the account off, cleared when it is switched
  /// back on. Access control reads [active] alone; these two exist so the
  /// roster can answer "who turned this off, and when" months later.
  final DateTime? deactivatedAt;
  final String? deactivatedBy;

  const AppUser({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.role,
    this.active = true,
    this.createdAt,
    this.createdBy,
    this.deactivatedAt,
    this.deactivatedBy,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isReadOnly => role == UserRole.readOnly;
  bool get isStore => role == UserRole.store;
  bool get isAuditor => role == UserRole.auditor;

  Map<String, Object?> toFirestore() => {
    'username': username,
    'displayName': displayName,
    'role': role.wireName,
    'active': active,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'createdBy': createdBy,
    'deactivatedAt': deactivatedAt == null
        ? null
        : Timestamp.fromDate(deactivatedAt!),
    'deactivatedBy': deactivatedBy,
  };

  static AppUser? fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final role = userRoleFromWire(data['role'] as String?);
    // A document with an unrecognised role is treated as no account at all
    // rather than being silently downgraded to some default.
    if (role == null) return null;
    return AppUser(
      uid: doc.id,
      username: (data['username'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      role: role,
      active: (data['active'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      deactivatedAt: (data['deactivatedAt'] as Timestamp?)?.toDate(),
      deactivatedBy: data['deactivatedBy'] as String?,
    );
  }
}
