import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/services/profile_score.dart';

void main() {
  const empty = Candidate(fullName: 'Asha', headline: 'Flutter developer', experienceYears: 2);

  test('an empty profile with experience scores 0 and lists every tip', () {
    final s = ProfileScorer.score(empty);
    expect(s.score, 0);
    expect(s.tips, hasLength(11));
    expect(s.level, 'Just getting started');
  });

  test('a fresher does not lose points for having no work experience', () {
    final s = ProfileScorer.score(const Candidate(fullName: 'Ravi', headline: 'Flutter fresher'));
    expect(s.score, 12);
    expect(s.tips.map((t) => t.text), isNot(contains('Add your work experience or internships')));
  });

  test('a complete, verified profile scores 100', () {
    const full = Candidate(
      fullName: 'Asha',
      headline: 'Flutter developer',
      experienceYears: 3,
      phone: '9876543210',
      photo: 'data:image/jpeg;base64,AAAA',
      about: 'I build fast, well-tested Flutter apps for fintech and e-commerce. Shipped 4 apps to the Play Store and App Store with Bloc and clean architecture.',
      skills: ['Flutter', 'Dart', 'Bloc', 'Firebase', 'REST APIs', 'Testing'],
      experience: [WorkItem(company: 'Acme', role: 'SDE 1', start: '2023-01', points: '- Cut crash rate from 2% to 0.3%')],
      apps: [AppItem(name: 'PayFast', url: 'https://play.google.com/store/apps/details?id=x')],
      education: [EduItem(degree: 'B.Tech', institute: 'JU')],
      githubUrl: 'https://github.com/asha',
      linkedinUrl: 'https://linkedin.com/in/asha',
      jobTypes: ['full_time'],
      workModes: ['remote'],
      verification: 'verified',
    );
    final s = ProfileScorer.score(full);
    expect(s.score, 100);
    expect(s.tips, isEmpty);
    expect(s.level, 'All-star profile ⭐');
  });

  test('an app without a link does not count', () {
    final s = ProfileScorer.score(const Candidate(fullName: 'A', headline: 'B', apps: [AppItem(name: 'Notes', url: 'not a link')]));
    expect(s.tips.map((t) => t.text), contains('Add an app or project with a Play Store or GitHub link'));
  });

  test('WorkItem.bullets strips list markers and blank lines', () {
    const w = WorkItem(company: 'A', role: 'B', start: '2024-01', points: '- First\n\n• Second\n  * Third  ');
    expect(w.bullets, ['First', 'Second', 'Third']);
  });
}
