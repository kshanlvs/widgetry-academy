import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';
import 'package:widgetry_academy/features/auth/domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._ds, this._api, this._prefs);
  final AuthDataSource _ds;
  final ApiClient _api;
  final SharedPreferences _prefs;

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

  /// Things the app keeps about the person on the phone (saved jobs, checklist, payment state).
  static bool _personal(String key) => key == 'saved_jobs_v1' || key == 'pay_tax_state' || key.startsWith('start_');

  @override
  Future<Result<String>> deleteAccount() => guard(() async {
        final j = await _api.delete('/me');
        // The sign-in account is already deleted on the server; this clears it on the phone
        try {
          await _ds.signOut();
        } catch (_) {}
        for (final k in _prefs.getKeys().where(_personal).toList()) {
          await _prefs.remove(k);
        }
        return '${j['message'] ?? 'Your account is deleted.'}';
      });
}
