import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';
import 'package:widgetry_academy/features/auth/domain/usecases/auth_usecases.dart';

enum AuthStatus { unknown, signedIn, signedOut }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.busy = false, this.error, this.info});
  final AuthStatus status;
  final AppUser? user;
  final bool busy;
  final String? error;
  final String? info;

  bool get isSignedIn => status == AuthStatus.signedIn && user != null;

  AuthState copyWith({AuthStatus? status, AppUser? user, bool clearUser = false, bool? busy, String? error, String? info}) => AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        busy: busy ?? this.busy,
        error: error,
        info: info,
      );

  @override
  List<Object?> get props => [status, user, busy, error, info];
}

/// App-wide sign-in state. A singleton, so the router and every screen see the same user.
@lazySingleton
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._watch, this._google, this._email, this._signUp, this._reset, this._signOut) : super(const AuthState()) {
    _sub = _watch(const NoParams()).listen(
      (u) => emit(state.copyWith(status: u == null ? AuthStatus.signedOut : AuthStatus.signedIn, user: u, clearUser: u == null)),
    );
  }

  final WatchAuthState _watch;
  final SignInWithGoogle _google;
  final SignInWithEmail _email;
  final SignUpWithEmail _signUp;
  final SendPasswordReset _reset;
  final SignOut _signOut;
  StreamSubscription<AppUser?>? _sub;

  Future<bool> signInWithGoogle() => _run(() => _google(const NoParams()));

  Future<bool> signInWithEmail(String email, String password) => _run(() => _email(EmailCredentials(email: email, password: password)));

  Future<bool> signUp(String name, String email, String password) =>
      _run(() => _signUp(EmailCredentials(name: name, email: email, password: password)), info: 'Account created. We sent a verification email.');

  Future<void> resetPassword(String email) async {
    emit(state.copyWith(busy: true));
    final r = await _reset(email);
    emit(r.fold((f) => state.copyWith(busy: false, error: f.message), (_) => state.copyWith(busy: false, info: 'Password reset link sent to $email.')));
  }

  Future<void> signOut() async {
    await _signOut(const NoParams());
  }

  Future<bool> _run(Future<Result<AppUser>> Function() f, {String? info}) async {
    emit(state.copyWith(busy: true));
    final r = await f();
    return r.fold((fail) {
      emit(state.copyWith(busy: false, error: fail.message));
      return false;
    }, (u) {
      emit(state.copyWith(busy: false, status: AuthStatus.signedIn, user: u, info: info));
      return true;
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
