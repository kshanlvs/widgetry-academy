import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/features/jobs/data/models/job_model.dart';
import 'package:widgetry_academy/features/jobs/data/models/jobs_meta_model.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';

void main() {
  test('reads a job detail from the API', () {
    final j = JobModel.fromJson({
      'id': 'k3x9',
      'title': 'SDE 2 - Flutter',
      'category': 'flutter',
      'company': {'name': 'slice', 'website': 'https://sliceit.com', 'verified': true},
      'type': 'full_time',
      'mode': 'onsite',
      'level': 'mid',
      'city': 'Bengaluru',
      'salary': null,
      'skills': ['Flutter', 'Dart'],
      'featured': false,
      'postedAt': '2026-10-10T06:30:00.000Z',
      'expiresAt': '2026-11-09T06:30:00.000Z',
      'status': 'open',
      'description': 'Build the slice app.',
      'apply': {'url': 'https://careers.sliceit.com/1', 'email': null},
    }).toEntity();
    expect(j.company.verified, isTrue);
    expect(j.salary, isNull);
    expect(j.postedAt, DateTime.utc(2026, 10, 10, 6, 30));
    expect(j.canApply, isTrue);
    expect(j.shareUrl, 'https://widgetryacademy.in/job.html?id=k3x9');
  });

  test('list items without category default to Flutter; an empty salary becomes null', () {
    final j = JobModel.fromJson({
      'id': 'a',
      'title': 'T',
      'company': {'name': 'C'},
      'type': 'internship',
      'mode': 'remote',
      'level': 'fresher',
      'salary': {'min': null, 'max': null, 'period': 'month'},
    }).toEntity();
    expect(j.category, 'flutter');
    expect(j.salary, isNull);
    expect(j.skills, isEmpty);
    expect(j.canApply, isFalse, reason: 'list items have no apply link');
  });

  test('a filled job cannot be applied to', () {
    final j = JobModel.fromJson({
      'id': 'f', 'title': 'T', 'company': {'name': 'C'}, 'type': 'full_time', 'mode': 'remote', 'level': 'mid',
      'status': 'filled', 'apply': {'url': 'https://x.in'},
    }).toEntity();
    expect(j.isOpen, isFalse);
    expect(j.canApply, isFalse);
  });

  test('meta reads categories and falls back when the server sends none', () {
    final m = JobsMetaModel.fromJson({
      'liveJobs': 4,
      'categories': [
        {'slug': 'flutter', 'name': 'Flutter', 'liveJobs': 3, 'suggestedSkills': ['Dart']},
        {'slug': 'ios', 'name': 'iOS', 'liveJobs': 1},
      ],
    }).toEntity();
    expect(m.categories.map((c) => c.slug), ['flutter', 'ios']);
    expect(m.categoryName('ios'), 'iOS');
    expect(m.categoryName('react-native'), 'React-native');
    expect(JobsMetaModel.fromJson({}).toEntity().categories, JobsMeta.fallback.categories);
  });
}
