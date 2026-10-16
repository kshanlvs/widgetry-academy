import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/repositories/profile_repository.dart';

@injectable
class GetMyProfile implements UseCase<Candidate?, NoParams> {
  const GetMyProfile(this._repo);
  final ProfileRepository _repo;
  @override
  Future<Result<Candidate?>> call(NoParams p) => _repo.getMine();
}

@injectable
class SaveProfile implements UseCase<Candidate, Candidate> {
  const SaveProfile(this._repo);
  final ProfileRepository _repo;
  @override
  Future<Result<Candidate>> call(Candidate p) => _repo.save(p);
}

@injectable
class UploadProfilePhoto implements UseCase<String, Uint8List> {
  const UploadProfilePhoto(this._repo);
  final ProfileRepository _repo;
  @override
  Future<Result<String>> call(Uint8List bytes) => _repo.uploadPhoto(bytes);
}

@injectable
class RemoveProfilePhoto implements UseCase<Unit, NoParams> {
  const RemoveProfilePhoto(this._repo);
  final ProfileRepository _repo;
  @override
  Future<Result<Unit>> call(NoParams p) => _repo.removePhoto();
}

@injectable
class SetOpenToWork implements UseCase<Unit, bool> {
  const SetOpenToWork(this._repo);
  final ProfileRepository _repo;
  @override
  Future<Result<Unit>> call(bool open) => _repo.setOpenToWork(open);
}

@injectable
class SaveResumeSettings implements UseCase<Unit, ResumeSettings> {
  const SaveResumeSettings(this._repo);
  final ProfileRepository _repo;
  @override
  Future<Result<Unit>> call(ResumeSettings s) => _repo.saveResumeSettings(s);
}

@injectable
class DeleteProfile implements UseCase<Unit, NoParams> {
  const DeleteProfile(this._repo);
  final ProfileRepository _repo;
  @override
  Future<Result<Unit>> call(NoParams p) => _repo.deleteProfile();
}

@injectable
class BuildResumePdf {
  const BuildResumePdf(this._builder);
  final ResumeBuilder _builder;
  Future<Uint8List> call(Candidate profile, ResumeSettings settings) => _builder.build(profile, settings);
}
