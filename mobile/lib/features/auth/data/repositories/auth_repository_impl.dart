import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';
import 'package:widgetry_academy/features/auth/domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._ds);
  final AuthDataSource _ds;

  @override
  Stream<AppUser?> authStateChanges() => _ds.authStateChanges();

  @override
  AppUser? get currentUser => _ds.currentUser;

  @override
  Future<Result<AppUser>> signInWithGoogle() => guard(_ds.signInWithGoogle);

  @override
  Future<Result<AppUser>> signInWithEmail({required String email, required String password}) => guard(() => _ds.signInWithEmail(email, password));

  @override
  Future<Result<AppUser>> signUpWithEmail({required String name, required String email, required String password}) =>
      guard(() => _ds.signUpWithEmail(name, email, password));

  @override
  Future<Result<Unit>> sendPasswordReset(String email) => guard(() async {
        await _ds.sendPasswordReset(email);
        return unit;
      });

  @override
  Future<Result<Unit>> signOut() => guard(() async {
        await _ds.signOut();
        return unit;
      });
}
