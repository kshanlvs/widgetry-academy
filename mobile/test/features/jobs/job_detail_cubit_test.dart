import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/utils/link_launcher.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';
import 'package:widgetry_academy/features/jobs/presentation/cubit/job_detail_cubit.dart';

import '../../helpers/fixtures.dart';

class MockGetJobDetail extends Mock implements GetJobDetail {}

class MockIsJobSaved extends Mock implements IsJobSaved {}

class MockToggleSavedJob extends Mock implements ToggleSavedJob {}

class MockReportJob extends Mock implements ReportJob {}

class MockLinks extends Mock implements LinkLauncher {}

void main() {
  late MockGetJobDetail get;
  late MockIsJobSaved isSaved;
  late MockToggleSavedJob toggle;
  late MockReportJob report;
  late MockLinks links;

  setUpAll(() {
    registerFallbackValue(job('fallback'));
    registerFallbackValue(const ReportJobParams(jobId: 'x', reason: 'other'));
  });

  setUp(() {
    get = MockGetJobDetail();
    isSaved = MockIsJobSaved();
    toggle = MockToggleSavedJob();
    report = MockReportJob();
    links = MockLinks();
  });

  JobDetailCubit build() => JobDetailCubit(get, isSaved, toggle, report, links);

  blocTest<JobDetailCubit, JobDetailState>(
    'load shows the job and whether it is saved',
    setUp: () {
      when(() => isSaved('j1')).thenAnswer((_) async => const Success(true));
      when(() => get('j1')).thenAnswer((_) async => Success(job('j1')));
    },
    build: build,
    act: (c) => c.load('j1'),
    expect: () => [JobDetailState(status: DetailStatus.ready, job: job('j1'), saved: true)],
  );

  blocTest<JobDetailCubit, JobDetailState>(
    'load shows a not-found error',
    setUp: () {
      when(() => isSaved(any())).thenAnswer((_) async => const Success(false));
      when(() => get(any())).thenAnswer((_) async => const Err(ServerFailure('This job was not found.', statusCode: 404)));
    },
    build: build,
    act: (c) => c.load('gone'),
    expect: () => [const JobDetailState(status: DetailStatus.failure, error: 'This job was not found.')],
  );

  blocTest<JobDetailCubit, JobDetailState>(
    'apply opens the employer careers page in the app',
    setUp: () => when(() => links.openInApp(any())).thenAnswer((_) async => true),
    build: build,
    seed: () => JobDetailState(status: DetailStatus.ready, job: job('j', applyUrl: 'https://careers.acme.in/1')),
    act: (c) => c.apply(),
    expect: () => <JobDetailState>[],
    verify: (_) => verify(() => links.openInApp('https://careers.acme.in/1')).called(1),
  );

  blocTest<JobDetailCubit, JobDetailState>(
    'apply falls back to email and tells the user when nothing opens',
    setUp: () => when(() => links.email(any(), subject: any(named: 'subject'))).thenAnswer((_) async => false),
    build: build,
    seed: () => JobDetailState(status: DetailStatus.ready, job: job('j', applyEmail: 'hr@acme.in')),
    act: (c) => c.apply(),
    expect: () => [JobDetailState(status: DetailStatus.ready, job: job('j', applyEmail: 'hr@acme.in'), message: "Couldn't open the application link.")],
  );

  blocTest<JobDetailCubit, JobDetailState>(
    'apply does nothing for a filled job',
    build: build,
    seed: () => JobDetailState(status: DetailStatus.ready, job: job('j', applyUrl: 'https://x.in', status: 'filled')),
    act: (c) => c.apply(),
    expect: () => <JobDetailState>[],
    verify: (_) => verifyNever(() => links.openInApp(any())),
  );

  blocTest<JobDetailCubit, JobDetailState>(
    'toggleSave updates the flag and confirms',
    setUp: () => when(() => toggle(any())).thenAnswer((_) async => const Success(true)),
    build: build,
    seed: () => JobDetailState(status: DetailStatus.ready, job: job('j')),
    act: (c) => c.toggleSave(),
    expect: () => [JobDetailState(status: DetailStatus.ready, job: job('j'), saved: true, message: 'Saved to your jobs')],
  );

  blocTest<JobDetailCubit, JobDetailState>(
    'report sends the reason and marks the job reported',
    setUp: () => when(() => report(any())).thenAnswer((_) async => const Success(unit)),
    build: build,
    seed: () => JobDetailState(status: DetailStatus.ready, job: job('j')),
    act: (c) => c.report('asks_fees', 'Wanted ₹5,000 for training'),
    expect: () => [JobDetailState(status: DetailStatus.ready, job: job('j'), reported: true, message: "Thanks. We'll review this job.")],
    verify: (_) => verify(() => report(const ReportJobParams(jobId: 'j', reason: 'asks_fees', details: 'Wanted ₹5,000 for training'))).called(1),
  );
}
