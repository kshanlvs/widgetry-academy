import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/core/error/exceptions.dart';
import 'package:widgetry_academy/features/jobs/data/models/job_model.dart';

/// Saved (bookmarked) jobs, stored on the phone.
abstract interface class SavedJobsLocalDataSource {
  List<JobModel> all();
  bool contains(String id);
  Future<void> save(JobModel job);
  Future<void> remove(String id);
}

@LazySingleton(as: SavedJobsLocalDataSource)
class SavedJobsLocalDataSourceImpl implements SavedJobsLocalDataSource {
  SavedJobsLocalDataSourceImpl(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'saved_jobs_v1';
  static const _max = 100;

  @override
  List<JobModel> all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(JobModel.fromJson).toList();
    } catch (_) {
      throw const CacheException('Your saved jobs could not be read.');
    }
  }

  @override
  bool contains(String id) => all().any((j) => j.id == id);

  @override
  Future<void> save(JobModel job) async {
    final list = [job, ...all().where((j) => j.id != job.id)].take(_max).toList();
    await _prefs.setString(_key, jsonEncode(list.map((j) => j.toJson()).toList()));
  }

  @override
  Future<void> remove(String id) async {
    final list = all().where((j) => j.id != id).toList();
    await _prefs.setString(_key, jsonEncode(list.map((j) => j.toJson()).toList()));
  }
}
