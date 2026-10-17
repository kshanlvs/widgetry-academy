import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';
import 'package:widgetry_academy/features/auth/domain/usecases/auth_usecases.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/services/profile_score.dart';
import 'package:widgetry_academy/features/profile/domain/usecases/profile_usecases.dart';

enum ProfileStatus { signedOut, loading, empty, ready, failure }

class ProfileState extends Equatable {
  const ProfileState({this.status = ProfileStatus.loading, this.profile, this.saving = false, this.error, this.message});
  final ProfileStatus status;
  final Candidate? profile;
  final bool saving;
  final String? error;
  final String? message;

  ProfileScore? get score => profile == null ? null : ProfileScorer.score(profile!);

  ProfileState copyWith({ProfileStatus? status, Candidate? profile, bool clearProfile = false, bool? saving, String? error, String? message}) => ProfileState(
        status: status ?? this.status,
        profile: clearProfile ? null : (profile ?? this.profile),
        saving: saving ?? this.saving,
        error: error,
        message: message,
      );

  @override
  List<Object?> get props => [status, profile, saving, error, message];
}

/// The signed-in seeker's profile. App-wide, so the profile, edit and resume screens share one copy.
@lazySingleton
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(WatchAuthState watchAuth, this._get, this._save, this._upload, this._removePhoto, this._openToWork, this._resume, this._delete)
      : super(const ProfileState()) {
    _authSub = watchAuth(const NoParams()).listen(_onAuth);
  }

  final GetMyProfile _get;
  final SaveProfile _save;
  final UploadProfilePhoto _upload;
  final RemoveProfilePhoto _removePhoto;
  final SetOpenToWork _openToWork;
  final SaveResumeSettings _resume;
  final DeleteProfile _delete;
  StreamSubscription<AppUser?>? _authSub;
  String? _uid;
  bool _authKnown = false;

  void _onAuth(AppUser? user) {
    // The first event always counts: a signed-out start (null == null) must leave the loading state
    if (_authKnown && user?.uid == _uid) return;
    _authKnown = true;
    _uid = user?.uid;
    if (user == null) {
      emit(const ProfileState(status: ProfileStatus.signedOut));
    } else {
      load();
    }
  }

  Future<void> load() async {
    if (_uid == null) {
      emit(const ProfileState(status: ProfileStatus.signedOut));
      return;
    }
    emit(state.copyWith(status: ProfileStatus.loading));
    final r = await _get(const NoParams());
    r.fold(
      (f) => emit(state.copyWith(status: ProfileStatus.failure, error: f.message)),
      (p) => emit(p == null ? state.copyWith(status: ProfileStatus.empty, clearProfile: true) : state.copyWith(status: ProfileStatus.ready, profile: p)),
    );
  }

  Future<bool> save(Candidate profile) async {
    emit(state.copyWith(saving: true));
    final r = await _save(profile);
    return r.fold((f) {
      emit(state.copyWith(saving: false, error: f.message));
      return false;
    }, (p) {
      // Keep the photo and resume settings the server holds separately
      emit(state.copyWith(saving: false, status: ProfileStatus.ready, profile: p, message: 'Profile saved'));
      return true;
    });
  }

  Future<void> uploadPhoto(Uint8List bytes) async {
    final p = state.profile;
    if (p == null) return;
    emit(state.copyWith(saving: true));
    final r = await _upload(bytes);
    r.fold((f) => emit(state.copyWith(saving: false, error: f.message)), (url) => emit(state.copyWith(saving: false, profile: p.copyWith(photo: url), message: 'Looking good! Photo updated.')));
  }

  Future<void> removePhoto() async {
    final p = state.profile;
    if (p == null) return;
    final r = await _removePhoto(const NoParams());
    r.fold((f) => emit(state.copyWith(error: f.message)), (_) => emit(state.copyWith(profile: p.copyWith(clearPhoto: true), message: 'Photo removed')));
  }

  Future<void> setOpenToWork(bool open) async {
    final p = state.profile;
    if (p == null) return;
    emit(state.copyWith(profile: p.copyWith(openToWork: open)));
    final r = await _openToWork(open);
    r.fold((f) => emit(state.copyWith(profile: p, error: f.message)), (_) => emit(state.copyWith(message: open ? "You're open to work" : 'Your profile is paused')));
  }

  Future<void> saveResumeSettings(ResumeSettings s) async {
    final p = state.profile;
    if (p == null) return;
    emit(state.copyWith(profile: p.copyWith(resumeSettings: s)));
    final r = await _resume(s);
    r.fold((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<bool> deleteProfile() async {
    final r = await _delete(const NoParams());
    return r.fold((f) {
      emit(state.copyWith(error: f.message));
      return false;
    }, (_) {
      emit(const ProfileState(status: ProfileStatus.empty, message: 'Your profile has been deleted'));
      return true;
    });
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
