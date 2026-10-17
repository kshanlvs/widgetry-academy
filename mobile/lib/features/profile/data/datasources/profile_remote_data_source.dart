import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/features/profile/data/models/candidate_model.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';

abstract interface class ProfileRemoteDataSource {
  Future<CandidateModel?> getMine();
  Future<CandidateModel> save(Candidate p);
  Future<String> uploadPhoto(Uint8List jpeg);
  Future<void> removePhoto();
  Future<void> setOpenToWork(bool open);
  Future<void> saveResumeSettings(ResumeSettings s);
  Future<void> delete();
}

@LazySingleton(as: ProfileRemoteDataSource)
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._api);
  final ApiClient _api;

  @override
  Future<CandidateModel?> getMine() async {
    final json = await _api.get('/talent/me');
    final p = json['profile'];
    return p is Map<String, dynamic> ? CandidateModel.fromJson(p) : null;
  }

  @override
  Future<CandidateModel> save(Candidate p) async {
    final json = await _api.put('/talent/me', body: CandidateModel.toRequest(p));
    return CandidateModel.fromJson(json['profile'] as Map<String, dynamic>);
  }

  @override
  Future<String> uploadPhoto(Uint8List jpeg) async {
    final json = await _api.put('/talent/me/photo', body: {'dataUrl': 'data:image/jpeg;base64,${base64Encode(jpeg)}'});
    return json['photo'] as String;
  }

  @override
  Future<void> removePhoto() => _api.delete('/talent/me/photo');

  @override
  Future<void> setOpenToWork(bool open) => _api.patch('/talent/me', body: {'openToWork': open});

  @override
  Future<void> saveResumeSettings(ResumeSettings s) => _api.put('/talent/me/resume-settings', body: ResumeSettingsModel.fromEntity(s).toJson());

  @override
  Future<void> delete() => _api.delete('/talent/me');
}
