import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around Firebase Authentication so screens don't talk
/// to FirebaseAuth directly.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// google_sign_in v7 must be initialized EXACTLY once per app run, and
  /// before any other call — calling it again (or signOut before it) is
  /// "undefined behaviour". So it's shared, and retried only if it failed.
  static Future<void>? _googleReady;

  static Future<void> _ensureGoogle() {
    return _googleReady ??= GoogleSignIn.instance.initialize().catchError((Object error) {
      _googleReady = null; // let the next attempt try again
      throw error;
    });
  }

  User? get currentUser => _auth.currentUser;

  Future<User> signInAsGuest() async {
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  Future<User> createAccount({
    required String email,
    required String password,
    required String username,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user!.updateDisplayName(username);
    return cred.user!;
  }

  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user!;
  }

  /// Uses native Android Google Sign-In sheet instead of browser redirects.
  Future<User> signInWithGoogle() async {
    // 1. Initialize Google Sign-In (once per app run — see _ensureGoogle)
    await _ensureGoogle();

    // 2. Prompt native Android account picker / Credential Manager sheet
    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    // 3. Request authorization scopes to obtain access token
    final clientAuth = await googleUser.authorizationClient.authorizeScopes([
      'email',
      'profile',
    ]);

    // 4. Convert Google tokens into Firebase OAuth credentials
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: clientAuth.accessToken,
      idToken: googleUser.authentication.idToken,
    );

    // 5. Authenticate natively with Firebase
    final cred = await _auth.signInWithCredential(credential);
    return cred.user!;
  }

  /// Signs out of Firebase — and of Google too, but only if this account
  /// used Google, and never letting a Google hiccup stop the real sign-out.
  Future<void> signOut() async {
    final usedGoogle = _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    if (usedGoogle) {
      try {
        await _ensureGoogle();
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Google sign-out failed (continuing): $error');
      }
    }
    await _auth.signOut();
  }

  /// Turns Firebase's technical error codes into something a student
  /// can actually act on.
  static String friendlyError(Object error) {
    // The student sees a friendly line; the log keeps the real error so a
    // failure on a tester's phone can still be diagnosed (adb logcat).
    debugPrint('[Auth] sign-in failed: $error');
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) return 'Sign-in was cancelled.';
      return "Google sign-in didn't work. Please try again.";
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return "That email address doesn't look right.";
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account with that email already exists. Try signing in instead.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a bit and try again.';
        case 'operation-not-allowed':
          return "This sign-in method isn't turned on in Firebase yet.";
        case 'web-context-canceled':
        case 'canceled':
        case 'popup-closed-by-user':
          return 'Sign-in was cancelled.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}