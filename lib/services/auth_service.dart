import 'package:firebase_auth/firebase_auth.dart';

/// Username-based sign-in on top of Firebase's email/password provider.
///
/// Warehouse staff do not necessarily have email addresses, so each username
/// is mapped to a synthetic address in a domain nobody can receive mail at.
/// The mapping is deterministic, which means login needs no lookup in
/// Firestore before authenticating — important, because an unauthenticated
/// client cannot read the users collection under our security rules.
class AuthService {
  /// Not a real mail domain. It exists only to satisfy the provider's
  /// address format.
  static const String usernameDomain = 'kitagawa-inventory-app.app';

  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  static String emailForUsername(String username) =>
      '${username.trim().toLowerCase()}@$usernameDomain';

  static String usernameFromEmail(String email) =>
      email.split('@').first.toLowerCase();

  Future<UserCredential> signIn({
    required String username,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: emailForUsername(username),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Raised when the current password typed on the change-password screen
  /// does not match. Firebase reports a failed re-authentication with the
  /// same codes as a failed sign-in, which would otherwise surface as
  /// "Incorrect username or password" on a screen that asks for neither.
  static const String wrongCurrentPasswordCode = 'wrong-current-password';

  static const Set<String> _badCredentialCodes = {
    'invalid-credential',
    'wrong-password',
    'user-mismatch',
    'user-not-found',
    'INVALID_LOGIN_CREDENTIALS',
  };

  /// Changes the signed-in user's own password.
  ///
  /// Re-authenticating first is not optional in practice: Firebase refuses
  /// `updatePassword` on a session that has not signed in recently
  /// (`requires-recent-login`), and these devices stay signed in for weeks at
  /// a time. It also doubles as proof that whoever is holding the unlocked
  /// phone is the account's owner rather than the next person on the floor.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Not signed in',
      );
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
    } on FirebaseAuthException catch (e) {
      if (_badCredentialCodes.contains(e.code)) {
        throw FirebaseAuthException(
          code: wrongCurrentPasswordCode,
          message: 'Current password is incorrect',
        );
      }
      rethrow;
    }

    await user.updatePassword(newPassword);
  }

  /// Turns Firebase's error codes into something an operator can act on.
  static String describeError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case wrongCurrentPasswordCode:
          return 'Current password is incorrect';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'INVALID_LOGIN_CREDENTIALS':
          return 'Incorrect username or password';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'too-many-requests':
          return 'Too many attempts. Wait a moment and try again.';
        case 'network-request-failed':
          return 'No connection. Check the network and try again.';
        case 'email-already-in-use':
          return 'That username is already taken';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters';
        case 'requires-recent-login':
          return 'Please sign out and back in, then try again';
        default:
          return error.message ?? 'Authentication failed (${error.code})';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
