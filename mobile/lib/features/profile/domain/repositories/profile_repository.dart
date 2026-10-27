import 'dart:typed_data';

import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';

abstract interface class ProfileRepository {
  /// null when the user hasn't created a profile yet.
  Future<Result<Candidate?>> getMine();
  Future<Result<Candidate>> save(Candidate profile);
  Future<Result<String>> uploadPhoto(Uint8List jpegBytes);
  Future<Result<Unit>> removePhoto();
  Future<Result<Unit>> setOpenToWork(bool open);
  Future<Result<Unit>> saveResumeSettings(ResumeSettings settings);
  Future<Result<Unit>> deleteProfile();
}

/// A resume built before signing in. Kept on the phone until it can be saved to the account.
class ProfileDraft {
  const ProfileDraft(this.profile, {this.look = const ResumeSettings()});
  final Candidate profile;
  final ResumeSettings look;
}

abstract interface class ProfileDraftStore {
  ProfileDraft? read();
  Future<void> write(ProfileDraft draft);
  Future<void> clear();
}
