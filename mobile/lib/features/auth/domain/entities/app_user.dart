import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({required this.uid, this.email, this.displayName, this.photoUrl, this.emailVerified = false});
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;

  String get firstName => (displayName ?? '').trim().split(' ').first;

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, emailVerified];
}
