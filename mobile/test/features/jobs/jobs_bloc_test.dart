import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';
import 'package:widgetry_academy/features/jobs/presentation/bloc/jobs_bloc.dart';

import '../../helpers/fixtures.dart';

class MockGetJobsMeta extends Mock implements GetJobsMeta {}

class MockSearchJobs extends Mock implements SearchJobs {}

void main() {
  late MockGetJobsMeta meta;
  late MockSearchJobs search;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const SearchJobsParams(JobFilter()));
  });

  setUp(() {
    meta = MockGetJobsMeta();
    search = MockSearchJobs();
  });

  JobsBloc build() => JobsBloc(meta, search);

  group('JobsStarted', () {
    blocTest<JobsBloc, JobsState>(
      'opens the Flutter tab first when Flutter has live jobs',
      setUp: () {
        when(() => meta(any())).thenAnswer((_) async => const Success(metaWithFlutterJobs));
        when(() => search(any())).thenAnswer((_) async => Success(page([job('a'), job('b')])));
      },
      build: build,
      act: (b) => b.add(const JobsStarted()),
      verify: (b) {
        expect(b.state.status, JobsStatus.success);
        expect(b.state.filter.category, 'flutter');
        expect(b.state.jobs.map((j) => j.id), ['a', 'b']);
        expect(b.state.meta, metaWithFlutterJobs);
        verify(() => search(const SearchJobsParams(JobFilter(category: 'flutter')))).called(1);
      },
    );

    blocTest<JobsBloc, JobsState>(
      'shows all categories when Flutter has no live jobs',
      setUp: () {
        when(() => meta(any())).thenAnswer((_) async => const Success(metaNoFlutterJobs));
        when(() => search(any())).thenAnswer((_) async => Success(page([job('x', category: 'android')])));
      },
      build: build,
      act: (b) => b.add(const JobsStarted()),
      verify: (b) {
        expect(b.state.filter.category, isNull);
        expect(b.state.status, JobsStatus.success);
      },
    );

    blocTest<JobsBloc, JobsState>(
      'a category from a notification wins over the default',
      setUp: () {
        when(() => meta(any())).thenAnswer((_) async => const Success(metaWithFlutterJobs));
        when(() => search(any())).thenAnswer((_) async => Success(page([job('i', category: 'ios')])));
      },
      build: build,
      act: (b) => b.add(const JobsStarted(category: 'ios')),
      verify: (b) => expect(b.state.filter.category, 'ios'),
    );

    blocTest<JobsBloc, JobsState>(
      'falls back to built-in categories when meta fails, and reports search errors',
      setUp: () {
        when(() => meta(any())).thenAnswer((_) async => const Err(NetworkFailure()));
        when(() => search(any())).thenAnswer((_) async => const Err(NetworkFailure()));
      },
      build: build,
      act: (b) => b.add(const JobsStarted()),
      verify: (b) {
        expect(b.state.meta, JobsMeta.fallback);
        expect(b.state.status, JobsStatus.failure);
        expect(b.state.error, const NetworkFailure().message);
      },
    );
  });

  blocTest<JobsBloc, JobsState>(
    'search keeps the category and resets to page 1',
    setUp: () => when(() => search(any())).thenAnswer((_) async => Success(page([job('s')]))),
    build: build,
    seed: () => JobsState(status: JobsStatus.success, filter: const JobFilter(category: 'flutter'), jobs: [job('old')], total: 40, page: 2),
    act: (b) => b.add(const JobsSearchSubmitted('bloc')),
    expect: () => [
      JobsState(status: JobsStatus.loading, filter: const JobFilter(category: 'flutter', query: 'bloc'), jobs: [job('old')], total: 40, page: 2),
      JobsState(status: JobsStatus.success, filter: const JobFilter(category: 'flutter', query: 'bloc'), jobs: [job('s')], total: 1, page: 1),
    ],
  );

  blocTest<JobsBloc, JobsState>(
    'next page appends results',
    setUp: () => when(() => search(any())).thenAnswer((_) async => Success(page([job('3')], total: 3, page: 2))),
    build: build,
    seed: () => JobsState(status: JobsStatus.success, jobs: [job('1'), job('2')], total: 3, page: 1),
    act: (b) => b.add(const JobsNextPageRequested()),
    expect: () => [
      JobsState(status: JobsStatus.success, jobs: [job('1'), job('2')], total: 3, page: 1, loadingMore: true),
      JobsState(status: JobsStatus.success, jobs: [job('1'), job('2'), job('3')], total: 3, page: 2),
    ],
    verify: (_) => verify(() => search(const SearchJobsParams(JobFilter(), page: 2))).called(1),
  );

  blocTest<JobsBloc, JobsState>(
    'next page does nothing when everything is loaded',
    build: build,
    seed: () => JobsState(status: JobsStatus.success, jobs: [job('1')], total: 1, page: 1),
    act: (b) => b.add(const JobsNextPageRequested()),
    expect: () => <JobsState>[],
    verify: (_) => verifyNever(() => search(any())),
  );

  blocTest<JobsBloc, JobsState>(
    'changing category clears nothing else but the category',
    setUp: () => when(() => search(any())).thenAnswer((_) async => Success(page([job('a', category: 'android')]))),
    build: build,
    seed: () => const JobsState(status: JobsStatus.success, filter: JobFilter(category: 'flutter', mode: 'remote')),
    act: (b) => b.add(const JobsCategorySelected('android')),
    verify: (b) => expect(b.state.filter, const JobFilter(category: 'android', mode: 'remote')),
  );

  test('pull-to-refresh completes even when nothing changed', () async {
    when(() => meta(any())).thenAnswer((_) async => const Success(metaWithFlutterJobs));
    when(() => search(any())).thenAnswer((_) async => Success(page([job('a')])));
    final bloc = build()..add(const JobsStarted());
    await bloc.stream.firstWhere((s) => s.status == JobsStatus.success);
    final done = Completer<void>();
    bloc.add(JobsRefreshed(done: done));
    await done.future.timeout(const Duration(seconds: 2));
    expect(bloc.state.jobs.single.id, 'a');
    await bloc.close();
  });

  test('JobFilter.toQuery trims and drops an empty query', () {
    expect(const JobFilter(query: '  ').toQuery()['q'], isNull);
    expect(const JobFilter(query: ' bloc ').toQuery()['q'], 'bloc');
    expect(const JobFilter(type: 'internship', city: 'Kolkata').activeCount, 2);
    expect(const JobFilter(category: 'ios', query: 'x', type: 'internship').clearedFilters(), const JobFilter(category: 'ios', query: 'x'));
  });
}
