import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/auth/domain/entities/app_user.dart';
import 'package:widgetry_academy/features/auth/domain/usecases/auth_usecases.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/repositories/profile_repository.dart';
import 'package:widgetry_academy/features/profile/domain/services/profile_errors.dart';
import 'package:widgetry_academy/features/profile/domain/services/profile_score.dart';
import 'package:widgetry_academy/features/profile/domain/usecases/profile_usecases.dart';

enum ProfileStatus { signedOut, loading, empty, ready, failure }

class ProfileState extends Equatable {
  const ProfileState({this.status = ProfileStatus.loading, this.profile, this.saving = false, this.error, this.message, this.draft});
  final ProfileStatus status;
  final Candidate? profile;
  /// A resume made before signing in, waiting for "use it or keep the saved one" (the account already had one).
  final ProfileDraft? draft;
  final bool saving;
  final String? error;
  final String? message;

  ProfileScore? get score => profile == null ? null : ProfileScorer.score(profile!);

  ProfileState copyWith({ProfileStatus? status, Candidate? profile, bool clearProfile = false, bool? saving, String? error, String? message, ProfileDraft? draft, bool clearDraft = false}) =>
      ProfileState(
        status: status ?? this.status,
        profile: clearProfile ? null : (profile ?? this.profile),
        saving: saving ?? this.saving,
        error: error,
        message: message,
        draft: clearDraft ? null : (draft ?? this.draft),
      );

  @override
  List<Object?> get props => [status, profile, saving, error, message, draft];
}

/// The signed-in seeker's profile. App-wide, so the profile, edit and resume screens share one copy.
@lazySingleton
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(WatchAuthState watchAuth, this._get, this._save, this._upload, this._removePhoto, this._openToWork, this._resume, this._delete, this._drafts)
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
  final ProfileDraftStore _drafts;
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
    if (r case Err(:final failure)) {
      emit(state.copyWith(status: ProfileStatus.failure, error: failure.message));
      return;
    }
    final p = r.valueOrNull;
    final draft = _drafts.read();
    if (p == null && draft != null) {
      // Built before signing in: save it to the new account straight away
      if (await _saveDraft(draft)) return;
      emit(state.copyWith(status: ProfileStatus.empty, clearProfile: true));
      return;
    }
    emit(p == null ? state.copyWith(status: ProfileStatus.empty, clearProfile: true) : state.copyWith(status: ProfileStatus.ready, profile: p, draft: draft));
  }

  /// Keeps a resume made before signing in (on this phone only).
  Future<void> keepDraft(ProfileDraft d) => _drafts.write(d);
  ProfileDraft? get draft => _drafts.read();

  Future<bool> _saveDraft(ProfileDraft d) async {
    final r = await _save(d.profile);
    if (r case Err(:final failure)) {
      emit(state.copyWith(error: ProfileErrors.readable(failure.message)));
      return false;
    }
    await _drafts.clear();
    emit(state.copyWith(status: ProfileStatus.ready, profile: r.valueOrNull!.copyWith(resumeSettings: d.look), clearDraft: true, message: 'Your resume is saved to your account'));
    await _resume(d.look);
    return true;
  }

  /// The account already had a resume: replace it with the one made before signing in.
  Future<void> useDraft() async {
    final d = state.draft;
    if (d == null) return;
    emit(state.copyWith(saving: true));
    final old = state.profile;
    final n = d.profile;
    // The resume comes from the new one; Talent Network choices stay as they were unless set in the new one
    final keepNetwork = old != null && !n.talentNetwork;
    final merged = old == null
        ? n
        : Candidate(
            fullName: n.fullName, phone: n.phone ?? old.phone, headline: n.headline, currentCompany: n.currentCompany, experienceYears: n.experienceYears,
            city: n.city ?? old.city, categories: n.categories, githubUrl: n.githubUrl, linkedinUrl: n.linkedinUrl, portfolioUrl: n.portfolioUrl,
            apps: n.apps, experience: n.experience, education: n.education, certifications: n.certifications, about: n.about, skills: n.skills,
            achievements: n.achievements, languages: n.languages,
            talentNetwork: keepNetwork ? old.talentNetwork : n.talentNetwork,
            workModes: keepNetwork ? old.workModes : n.workModes,
            jobTypes: keepNetwork ? old.jobTypes : n.jobTypes,
            noticePeriod: keepNetwork ? old.noticePeriod : n.noticePeriod,
            expectedSalaryLpa: keepNetwork ? old.expectedSalaryLpa : n.expectedSalaryLpa,
            openToWork: keepNetwork ? old.openToWork : n.openToWork,
            hiddenCompanies: keepNetwork ? old.hiddenCompanies : n.hiddenCompanies,
          );
    await _saveDraft(ProfileDraft(merged, look: d.look));
    emit(state.copyWith(saving: false));
  }

  /// Keep the saved resume; forget the one made before signing in.
  Future<void> discardDraft() async {
    await _drafts.clear();
    emit(state.copyWith(clearDraft: true));
  }

  Future<bool> save(Candidate profile) async {
    emit(state.copyWith(saving: true));
    final r = await _save(profile);
    return r.fold((f) {
      emit(state.copyWith(saving: false, error: ProfileErrors.readable(f.message)));
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

  /// The server changed the profile (e.g. AI suggestions applied on the resume screen).
  void replaceProfile(Candidate p) => emit(state.copyWith(status: ProfileStatus.ready, profile: p));

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
