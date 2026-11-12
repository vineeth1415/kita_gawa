import 'package:cloud_firestore/cloud_firestore.dart';

/// The single `settings/app` document.
///
/// [auditEnabled] is the master switch the requirement calls for: the Auditor
/// role only functions "if enabled". It gates the auditor's tabs in the UI and
/// is re-checked in firestore.rules, so switching it off actually stops audit
/// writes rather than merely hiding the buttons.
class AppSettings {
  final bool auditEnabled;
  final DateTime? updatedAt;
  final String? updatedBy;

  const AppSettings({
    this.auditEnabled = false,
    this.updatedAt,
    this.updatedBy,
  });

  Map<String, Object?> toFirestore() => {
    'auditEnabled': auditEnabled,
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedBy': updatedBy,
  };

  factory AppSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppSettings(
      auditEnabled: (data['auditEnabled'] as bool?) ?? false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }
}
