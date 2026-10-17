import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';

/// Sign-in for the app. Same Firebase accounts as widgetryacademy.in.
abstract interface class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<Result<AppUser>> signInWithGoogle();
  Future<Result<AppUser>> signInWithEmail({required String email, required String password});
  Future<Result<AppUser>> signUpWithEmail({required String name, required String email, required String password});
  Future<Result<Unit>> sendPasswordReset(String email);
  Future<Result<Unit>> signOut();
  /// Deletes the account and its data on our server (payment records stay, as tax law requires),
  /// signs out and clears what the app saved on this phone. Returns the server's message.
  Future<Result<String>> deleteAccount();
}
