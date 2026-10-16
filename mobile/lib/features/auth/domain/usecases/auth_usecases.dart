import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';
import 'package:widgetry_academy/features/auth/domain/repositories/auth_repository.dart';

@injectable
class WatchAuthState implements StreamUseCase<AppUser?, NoParams> {
  const WatchAuthState(this._repo);
  final AuthRepository _repo;
  @override
  Stream<AppUser?> call(NoParams params) => _repo.authStateChanges();
}

@injectable
class SignInWithGoogle implements UseCase<AppUser, NoParams> {
  const SignInWithGoogle(this._repo);
  final AuthRepository _repo;
  @override
  Future<Result<AppUser>> call(NoParams params) => _repo.signInWithGoogle();
}

class EmailCredentials extends Equatable {
  const EmailCredentials({required this.email, required this.password, this.name});
  final String email;
  final String password;
  final String? name;
  @override
  List<Object?> get props => [email, password, name];
}

@injectable
class SignInWithEmail implements UseCase<AppUser, EmailCredentials> {
  const SignInWithEmail(this._repo);
  final AuthRepository _repo;
  @override
  Future<Result<AppUser>> call(EmailCredentials p) => _repo.signInWithEmail(email: p.email.trim(), password: p.password);
}

@injectable
class SignUpWithEmail implements UseCase<AppUser, EmailCredentials> {
  const SignUpWithEmail(this._repo);
  final AuthRepository _repo;
  @override
  Future<Result<AppUser>> call(EmailCredentials p) => _repo.signUpWithEmail(name: (p.name ?? '').trim(), email: p.email.trim(), password: p.password);
}

@injectable
class SendPasswordReset implements UseCase<Unit, String> {
  const SendPasswordReset(this._repo);
  final AuthRepository _repo;
  @override
  Future<Result<Unit>> call(String email) => _repo.sendPasswordReset(email.trim());
}

@injectable
class SignOut implements UseCase<Unit, NoParams> {
  const SignOut(this._repo);
  final AuthRepository _repo;
  @override
  Future<Result<Unit>> call(NoParams params) => _repo.signOut();
}
