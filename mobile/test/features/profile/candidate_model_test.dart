import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/features/profile/data/models/candidate_model.dart';

void main() {
  final json = <String, dynamic>{
    'id': 'c_1',
    'fullName': 'Asha Roy',
    'email': 'asha@example.com',
    'phone': '9876543210',
    'headline': 'Flutter developer',
    'currentCompany': null,
    'experienceYears': 2,
    'city': 'Kolkata',
    'categories': ['flutter', 'android'],
    'workModes': ['remote'],
    'jobTypes': ['full_time'],
    'noticePeriod': '30_days',
    'expectedSalaryLpa': 8.5,
    'githubUrl': 'https://github.com/asha',
    'apps': [
      {'name': 'PayFast', 'url': 'https://play.google.com/x', 'role': 'Lead', 'about': null},
    ],
    'experience': [
      {'company': 'Acme', 'role': 'SDE 1', 'start': '2023-01', 'end': null, 'points': '- Shipped v2'},
    ],
    'education': [
      {'degree': 'B.Tech', 'institute': 'JU', 'year': 2022, 'score': '8.1 CGPA'},
    ],
    'skills': ['Flutter', 'Dart'],
    'openToWork': true,
    'verification': 'portfolio',
    'photo': null,
    'resumeSettings': {'template': 'classic', 'accent': 'navy', 'title': '', 'showPhoto': true, 'hide': ['certifications']},
  };

  test('reads the /talent/me profile', () {
    final c = CandidateModel.fromJson(json).toEntity();
    expect(c.fullName, 'Asha Roy');
    expect(c.experienceYears, 2.0);
    expect(c.categories, ['flutter', 'android']);
    expect(c.experience.single.end, isNull);
    expect(c.experience.single.bullets, ['Shipped v2']);
    expect(c.education.single.year, 2022);
    expect(c.certifications, isEmpty);
    expect(c.verification, 'portfolio');
    expect(c.resumeSettings.template, 'classic');
    expect(c.resumeSettings.title, isNull, reason: 'empty title means "use headline"');
    expect(c.resumeSettings.shows('certifications'), isFalse);
  });

  test('missing optional lists and settings get safe defaults', () {
    final c = CandidateModel.fromJson({'id': 'c', 'fullName': 'A', 'email': 'a@b.in', 'headline': 'H'}).toEntity();
    expect(c.categories, ['flutter']);
    expect(c.skills, isEmpty);
    expect(c.openToWork, isTrue);
    expect(c.resumeSettings.template, 'modern');
  });

  test('reads achievements, languages, Talent Network and "fit to one page"', () {
    final c = CandidateModel.fromJson({
      ...json,
      'achievements': ['Winner, Smart India Hackathon 2024'],
      'languages': ['English', 'Hindi'],
      'talentNetwork': true,
      'resumeSettings': {'template': 'modern', 'density': 'tight'},
    }).toEntity();
    expect(c.achievements, ['Winner, Smart India Hackathon 2024']);
    expect(c.languages, ['English', 'Hindi']);
    expect(c.talentNetwork, isTrue);
    expect(c.resumeSettings.density, 'tight');
  });

  test('toRequest sends empty strings for unset fields and the Talent Network choice', () {
    final body = CandidateModel.toRequest(CandidateModel.fromJson(json).toEntity());
    expect(body['currentCompany'], '');
    expect(body['talentNetwork'], isFalse, reason: 'building a resume does not join the network');
    expect(body.containsKey('consent'), isFalse);
    expect(body['achievements'], isEmpty);
    expect((body['experience'] as List).single['end'], '');
    expect(body.containsKey('photo'), isFalse, reason: 'photos upload separately');
  });
}
