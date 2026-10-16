import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/exceptions.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';

abstract interface class AuthDataSource {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail(String name, String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

@LazySingleton(as: AuthDataSource)
class FirebaseAuthDataSource implements AuthDataSource {
  FirebaseAuthDataSource(this._auth);
  final FirebaseAuth _auth;

  AppUser? _map(User? u) => u == null
      ? null
      : AppUser(uid: u.uid, email: u.email, displayName: u.displayName, photoUrl: u.photoURL, emailVerified: u.emailVerified);

  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<AppUser> signInWithGoogle() => _run(() async {
        // Uses Firebase's built-in Google flow (no extra plugin). Needs the app's SHA-1/SHA-256 in Firebase settings.
        final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        final cred = await _auth.signInWithProvider(provider);
        return _map(cred.user)!;
      });

  @override
  Future<AppUser> signInWithEmail(String email, String password) =>
      _run(() async => _map((await _auth.signInWithEmailAndPassword(email: email, password: password)).user)!);

  @override
  Future<AppUser> signUpWithEmail(String name, String email, String password) => _run(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        if (name.isNotEmpty) await cred.user?.updateDisplayName(name);
        await cred.user?.sendEmailVerification();
        await cred.user?.reload();
        return _map(_auth.currentUser)!;
      });

  @override
  Future<void> sendPasswordReset(String email) => _run(() => _auth.sendPasswordResetEmail(email: email));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e.code), code: e.code);
    }
  }

  String _message(String code) => switch (code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' => 'That email and password don\'t match. Try again or reset your password.',
        'email-already-in-use' => 'An account already exists with this email. Sign in instead.',
        'weak-password' => 'Choose a stronger password (at least 8 characters).',
        'user-disabled' => 'This account has been disabled. Contact us for help.',
        'too-many-requests' => 'Too many attempts. Please wait a few minutes and try again.',
        'network-request-failed' => 'No internet connection. Check your network and try again.',
        'web-context-canceled' || 'canceled' || 'popup-closed-by-user' => 'Sign-in was cancelled.',
        'account-exists-with-different-credential' => 'This email is linked to a different sign-in method. Try Google or email.',
        _ => 'Sign-in failed. Please try again.',
      };
}
