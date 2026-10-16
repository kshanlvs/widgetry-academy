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

/// Builds the resume PDF. Lives behind an interface so the PDF library can be swapped.
abstract interface class ResumeBuilder {
  Future<Uint8List> build(Candidate profile, ResumeSettings settings);
}
