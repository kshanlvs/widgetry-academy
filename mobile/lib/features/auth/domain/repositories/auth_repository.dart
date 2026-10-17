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
}
