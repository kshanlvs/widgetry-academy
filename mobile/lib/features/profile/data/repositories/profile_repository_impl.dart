import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/repositories/profile_repository.dart';

@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);
  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<Candidate?>> getMine() => guard(() async => (await _remote.getMine())?.toEntity());

  @override
  Future<Result<Candidate>> save(Candidate profile) => guard(() async => (await _remote.save(profile)).toEntity());

  @override
  Future<Result<String>> uploadPhoto(Uint8List jpegBytes) => guard(() => _remote.uploadPhoto(jpegBytes));

  @override
  Future<Result<Unit>> removePhoto() => guard(() async {
        await _remote.removePhoto();
        return unit;
      });

  @override
  Future<Result<Unit>> setOpenToWork(bool open) => guard(() async {
        await _remote.setOpenToWork(open);
        return unit;
      });

  @override
  Future<Result<Unit>> saveResumeSettings(ResumeSettings settings) => guard(() async {
        await _remote.saveResumeSettings(settings);
        return unit;
      });

  @override
  Future<Result<Unit>> deleteProfile() => guard(() async {
        await _remote.delete();
        return unit;
      });
}
