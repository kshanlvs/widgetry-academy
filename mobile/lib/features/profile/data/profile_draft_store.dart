import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/features/profile/data/models/candidate_model.dart';
import 'package:widgetry_academy/features/profile/domain/repositories/profile_repository.dart';

/// The guest resume in SharedPreferences, in the same JSON the server takes (PUT /talent/me).
@LazySingleton(as: ProfileDraftStore)
class PrefsProfileDraftStore implements ProfileDraftStore {
  PrefsProfileDraftStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'resume_draft_v1';

  @override
  ProfileDraft? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return draftFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // an unreadable draft is dropped, never a crash
    }
  }

  @override
  Future<void> write(ProfileDraft d) => _prefs.setString(_key, jsonEncode(draftToJson(d)));

  @override
  Future<void> clear() => _prefs.remove(_key);

  static Map<String, dynamic> draftToJson(ProfileDraft d) => {
        'profile': CandidateModel.toRequest(d.profile),
        'look': ResumeSettingsModel.fromEntity(d.look).toJson(),
      };

  static ProfileDraft draftFromJson(Map<String, dynamic> j) {
    // The request shape uses '' for "not set"; the entity uses null (a job with end '' is a current job)
    Object? blank(Object? v) => switch (v) {
          final String s when s.trim().isEmpty => null,
          final Map<dynamic, dynamic> m => {for (final e in m.entries) '${e.key}': blank(e.value)},
          final List<dynamic> l => [for (final x in l) if (blank(x) != null) blank(x)],
          _ => v,
        };
    final p = (blank(j['profile']) as Map<String, dynamic>?) ?? const {};
    final look = j['look'] as Map<String, dynamic>?;
    return ProfileDraft(
      CandidateModel.fromJson({...p, 'id': '', 'email': ''}).toEntity(),
      look: look == null ? const ResumeSettingsModel().toEntity() : ResumeSettingsModel.fromJson(look).toEntity(),
    );
  }
}
