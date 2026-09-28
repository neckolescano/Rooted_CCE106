import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around Firebase Authentication so screens don't talk
/// to FirebaseAuth directly.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user!.updateDisplayName(username);
    return cred.user!;
  }

  Future<User> signInWithEmail({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return cred.user!;
  }

  /// Uses Firebase's own Google sign-in flow (opens a small browser
  /// tab), so no extra Google package is needed.
  Future<User> signInWithGoogle() async {
    final cred = await _auth.signInWithProvider(GoogleAuthProvider());
    return cred.user!;
  }

  Future<void> signOut() => _auth.signOut();

  /// Turns Firebase's technical error codes into something a student
  /// can actually act on.
  static String friendlyError(Object error) {
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
