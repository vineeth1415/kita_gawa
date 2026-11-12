import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

/// Where the app is in the sign-in lifecycle.
enum SessionStatus {
  /// Still resolving the Firebase session on startup.
  initializing,
  signedOut,

  /// Authenticated, but with no users/{uid} profile — so no role and, per
  /// the security rules, no access to anything. Shown as an explicit error
  /// rather than an empty home screen.
  noProfile,

  /// Authenticated with a profile that an admin has deactivated.
  deactivated,
  signedIn,
}

class SessionProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserRepository _userRepository;

  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;

  SessionProvider({AuthService? authService, UserRepository? userRepository})
    : _authService = authService ?? AuthService(),
      _userRepository = userRepository ?? UserRepository() {
    _authSub = _authService.authStateChanges().listen(_onAuthChanged);
  }

  SessionStatus _status = SessionStatus.initializing;
  SessionStatus get status => _status;

  AppUser? _user;
  AppUser? get user => _user;

  String? _lastError;
  String? get lastError => _lastError;

  bool _signingIn = false;
  bool get signingIn => _signingIn;

  bool get isSignedIn => _status == SessionStatus.signedIn && _user != null;
  UserRole? get role => _user?.role;

  void _onAuthChanged(fb.User? authUser) {
    _profileSub?.cancel();
    _profileSub = null;

    if (authUser == null) {
      _user = null;
      _setStatus(SessionStatus.signedOut);
      return;
    }

    // The profile is watched rather than read once, so an admin changing
    // someone's role or deactivating them takes effect on that person's
    // device immediately, without waiting for them to sign out.
    _profileSub = _userRepository.watchUser(authUser.uid).listen(
      (profile) {
        _user = profile;
        if (profile == null) {
          _setStatus(SessionStatus.noProfile);
        } else if (!profile.active) {
          _setStatus(SessionStatus.deactivated);
        } else {
          _setStatus(SessionStatus.signedIn);
        }
      },
      onError: (_) {
        // A rules denial on the profile read means the same thing in
        // practice as a missing profile: this account cannot use the app.
        _user = null;
        _setStatus(SessionStatus.noProfile);
      },
    );
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    notifyListeners();
  }

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    _signingIn = true;
    _lastError = null;
    notifyListeners();
    try {
      await _authService.signIn(username: username, password: password);
      return true;
    } catch (error) {
      _lastError = AuthService.describeError(error);
      return false;
    } finally {
      _signingIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
