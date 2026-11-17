import 'package:cloud_firestore/cloud_firestore.dart';

/// Central place where collection names are spelled, so a rename cannot drift
/// between repositories and firestore.rules.
class Collections {
  static const String users = 'users';
  static const String usernames = 'usernames';
  static const String items = 'items';
  static const String movements = 'movements';
  static const String shifts = 'shifts';
  static const String shiftReports = 'shiftReports';
  static const String reportLines = 'lines';
  static const String auditSessions = 'auditSessions';
  static const String auditCounts = 'counts';
  static const String settings = 'settings';
  static const String settingsDoc = 'app';

  /// The shared pointer to the working day the store has selected. Lives in
  /// `settings` so it sits beside the other app-wide state, but has its own
  /// rule: store staff write it, the rest of `settings` is admin-only.
  static const String workingDayDoc = 'workingDay';
}

typedef Json = Map<String, dynamic>;
typedef JsonCollection = CollectionReference<Json>;
typedef JsonDocument = DocumentReference<Json>;
