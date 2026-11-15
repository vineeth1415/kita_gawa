import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Whether the app was launched with `--dart-define=USE_EMULATOR=true`.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_EMULATOR');

const String _emulatorHostOverride = String.fromEnvironment('EMULATOR_HOST');

const int authEmulatorPort = 9099;
const int firestoreEmulatorPort = 8080;

/// Host address for the local Firebase emulators.
///
/// Android emulators reach the host machine's loopback via `10.0.2.2`; other
/// targets use `127.0.0.1`. Override with `--dart-define=EMULATOR_HOST=...`
/// (for example, a LAN IP on a physical device).
String get firebaseEmulatorHost {
  if (_emulatorHostOverride.isNotEmpty) return _emulatorHostOverride;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return '10.0.2.2';
  }
  return '127.0.0.1';
}

/// Points Firebase Auth (and Firestore for the default app) at the local
/// emulators when [useFirebaseEmulator] is enabled.
Future<void> configureFirebaseEmulators({FirebaseApp? app}) async {
  if (!useFirebaseEmulator) return;
  final host = firebaseEmulatorHost;
  final targetApp = app ?? Firebase.app();
  await FirebaseAuth.instanceFor(
    app: targetApp,
  ).useAuthEmulator(host, authEmulatorPort);
  if (app == null) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      sslEnabled: false,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      firestoreEmulatorPort,
    );
  }
}

