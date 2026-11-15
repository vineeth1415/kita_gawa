import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../utils/firebase_emulator.dart';
import 'auth_service.dart';

/// Creates staff accounts from inside the app.
///
/// Calling `createUserWithEmailAndPassword` on the default FirebaseAuth
/// instance signs the *new* user in, which would kick the admin out of their
/// own session mid-task. To avoid that, the account is created through a
/// second, throwaway FirebaseApp with its own auth instance: the default
/// instance — and therefore the admin's session — is never touched.
///
/// The server-side alternative (a Cloud Function using the Admin SDK) is
/// cleaner still, but needs the Blaze plan; this project runs on Spark.
class UserAdminService {
  static const String _secondaryAppName = 'userProvisioning';

  final UserRepository _users;

  UserAdminService({UserRepository? userRepository})
    : _users = userRepository ?? UserRepository();

  Future<AppUser> createStaffAccount({
    required String username,
    required String displayName,
    required String password,
    required UserRole role,
    required String createdBy,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();

    if (await _users.usernameExists(normalizedUsername)) {
      throw UsernameTakenException(normalizedUsername);
    }

    final secondaryApp = await _openSecondaryApp();
    try {
      await configureFirebaseEmulators(app: secondaryApp);
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: AuthService.emailForUsername(normalizedUsername),
        password: password,
      );
      final uid = credential.user!.uid;

      // The profile is what actually grants access: until it exists the new
      // auth account has no role and the rules deny it everything.
      await _users.createProfile(
        uid: uid,
        username: normalizedUsername,
        displayName: displayName,
        role: role,
        createdBy: createdBy,
      );

      await secondaryAuth.signOut();

      return AppUser(
        uid: uid,
        username: normalizedUsername,
        displayName: displayName.trim(),
        role: role,
        createdBy: createdBy,
      );
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<FirebaseApp> _openSecondaryApp() async {
    try {
      return await Firebase.initializeApp(
        name: _secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      // A previous attempt that threw before its `finally` can leave the app
      // registered; reuse it rather than failing the whole operation.
      if (e.code == 'duplicate-app') {
        return Firebase.app(_secondaryAppName);
      }
      rethrow;
    }
  }
}
