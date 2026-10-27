import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetry_academy/features/profile/data/profile_draft_store.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/repositories/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const draft = ProfileDraft(
    Candidate(
      fullName: 'Asha Rao',
      headline: 'Flutter Developer',
      experienceYears: 1.5,
      skills: ['Flutter', 'Dart'],
      achievements: ['Won a hackathon'],
      languages: ['English', 'Hindi'],
      experience: [WorkItem(company: 'Acme', role: 'Intern', start: '2024-01', points: 'Built X')],
      education: [EduItem(degree: 'BCA', institute: 'XYZ College', year: 2024)],
    ),
    look: ResumeSettings(template: 'classic', density: 'compact'),
  );

  test('a resume made before signing in comes back exactly as it was', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsProfileDraftStore(await SharedPreferences.getInstance());
    expect(store.read(), isNull);
    await store.write(draft);
    final back = store.read()!;
    expect(back.profile.fullName, 'Asha Rao');
    expect(back.profile.experience.single.end, isNull, reason: 'still a current job, not an empty end date');
    expect(back.profile.phone, isNull);
    expect(back.profile.achievements, ['Won a hackathon']);
    expect(back.profile.education.single.year, 2024);
    expect(back.look.template, 'classic');
    expect(back.look.density, 'compact');
    await store.clear();
    expect(store.read(), isNull);
  });

  test('an unreadable draft is ignored, never a crash', () async {
    SharedPreferences.setMockInitialValues({'resume_draft_v1': jsonEncode({'profile': 'nonsense'})});
    expect(PrefsProfileDraftStore(await SharedPreferences.getInstance()).read(), isNull);
  });
}
