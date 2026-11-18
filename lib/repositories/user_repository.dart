import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'collections.dart';

class UsernameTakenException implements Exception {
  final String username;
  UsernameTakenException(this.username);
}

class UserRepository {
  final FirebaseFirestore _db;

  UserRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  JsonCollection get _users => _db.collection(Collections.users);

  /// The signed-in user's own record. Returns null while the document does
  /// not exist — a bare auth account with no role, which the rules treat as
  /// having no access at all.
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map(AppUser.fromFirestore);
  }

  Future<AppUser?> fetchUser(String uid) async {
    return AppUser.fromFirestore(await _users.doc(uid).get());
  }

  Stream<List<AppUser>> watchAll() {
    return _users.orderBy('username').snapshots().map(
      (snap) => snap.docs
          .map(AppUser.fromFirestore)
          .whereType<AppUser>()
          .toList(),
    );
  }

  Future<bool> usernameExists(String username) async {
    final snap = await _users
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<AppUser?> fetchByUsername(String username) async {
    final snap = await _users
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AppUser.fromFirestore(snap.docs.first);
  }

  Future<Map<String, dynamic>?> fetchUsernameMapping(String username) async {
    final doc = await _db
        .collection(Collections.usernames)
        .doc(username.toLowerCase().trim())
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> setUsernameMapping({
    required String username,
    required String uid,
    required String email,
    required int authVersion,
  }) {
    return _db
        .collection(Collections.usernames)
        .doc(username.toLowerCase().trim())
        .set({
      'uid': uid,
      'email': email,
      'authVersion': authVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> migrateProfileOnReset({
    required String oldUid,
    required String newUid,
    required String username,
    required String displayName,
    required UserRole role,
    required String authEmail,
    required int authVersion,
    required String createdBy,
  }) async {
    final normalized = username.toLowerCase().trim();
    final batch = _db.batch();

    final newProfileDoc = _users.doc(newUid);
    batch.set(newProfileDoc, {
      'username': normalized,
      'displayName': displayName.trim(),
      'role': role.wireName,
      'active': true,
      'authEmail': authEmail,
      'authVersion': authVersion,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });

    final usernameDoc = _db.collection(Collections.usernames).doc(normalized);
    batch.set(usernameDoc, {
      'uid': newUid,
      'email': authEmail,
      'authVersion': authVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (oldUid != newUid) {
      batch.delete(_users.doc(oldUid));
    }

    await batch.commit();
  }

  /// Writes the profile that gives an auth account its role. Until this
  /// exists, the account can do nothing.
  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
    required UserRole role,
    required String createdBy,
  }) {
    return _users.doc(uid).set({
      'username': username.toLowerCase(),
      'displayName': displayName.trim(),
      'role': role.wireName,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });
  }

  /// Switches an account on or off.
  ///
  /// `active` is the field the security rules read, so this single flag is
  /// what actually grants or removes every permission the account has. The
  /// two audit fields alongside it are written in the same update so a
  /// deactivated row can always say who switched it off; reactivating clears
  /// them rather than leaving a stale name on a working account.
  Future<void> setActive({
    required String uid,
    required bool active,
    required String actingUid,
  }) {
    return _users.doc(uid).update({
      'active': active,
      'deactivatedAt': active ? null : FieldValue.serverTimestamp(),
      'deactivatedBy': active ? null : actingUid,
    });
  }

  Future<void> setRole({required String uid, required UserRole role}) {
    return _users.doc(uid).update({'role': role.wireName});
  }

  Future<void> setDisplayName({required String uid, required String name}) {
    return _users.doc(uid).update({'displayName': name.trim()});
  }

  /// Permanently deletes a user profile and removes their username mapping.
  ///
  /// This permanently removes the account from the roster and revokes all
  /// access under Firestore security rules. Ledger movements recorded by
  /// this user remain untouched for audit history.
  Future<void> deleteUser({
    required String uid,
    required String username,
  }) async {
    final batch = _db.batch();
    batch.delete(_users.doc(uid));
    batch.delete(
      _db.collection(Collections.usernames).doc(username.toLowerCase().trim()),
    );
    await batch.commit();
  }
}
