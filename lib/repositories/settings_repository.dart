import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_settings.dart';
import 'collections.dart';

class SettingsRepository {
  final FirebaseFirestore _db;

  SettingsRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  JsonDocument get _doc =>
      _db.collection(Collections.settings).doc(Collections.settingsDoc);

  /// Defaults to audit disabled when the document does not exist yet, which
  /// matches the requirement's "if enabled" framing: the auditor role does
  /// nothing until someone deliberately switches it on.
  Stream<AppSettings> watch() {
    return _doc.snapshots().map((doc) {
      if (!doc.exists) return const AppSettings();
      return AppSettings.fromFirestore(doc);
    });
  }

  Future<void> setAuditEnabled({
    required bool enabled,
    required String updatedBy,
  }) {
    return _doc.set({
      'auditEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));
  }
}
