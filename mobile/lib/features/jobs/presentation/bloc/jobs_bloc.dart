import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/domain/usecases/jobs_usecases.dart';

// ---------- Events ----------
sealed class JobsEvent extends Equatable {
  const JobsEvent();
  @override
  List<Object?> get props => const [];
}

/// [category]: open a specific tab (e.g. from a notification); null = pick automatically.
final class JobsStarted extends JobsEvent {
  const JobsStarted({this.category});
  final String? category;
  @override
  List<Object?> get props => [category];
}

final class JobsCategorySelected extends JobsEvent {
  const JobsCategorySelected(this.category);
  final String? category;
  @override
  List<Object?> get props => [category];
}

final class JobsSearchSubmitted extends JobsEvent {
  const JobsSearchSubmitted(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

final class JobsFiltersApplied extends JobsEvent {
  const JobsFiltersApplied(this.filter);
  final JobFilter filter;
  @override
  List<Object?> get props => [filter];
}

final class JobsNextPageRequested extends JobsEvent {
  const JobsNextPageRequested();
}

/// Pull-to-refresh. [done] completes when the reload finishes, even if nothing changed.
final class JobsRefreshed extends JobsEvent {
  const JobsRefreshed({this.done});
  final Completer<void>? done;
}

// ---------- State ----------
enum JobsStatus { initial, loading, success, failure }

class JobsState extends Equatable {
  const JobsState({
    this.status = JobsStatus.initial,
    this.meta = JobsMeta.fallback,
    this.filter = const JobFilter(),
    this.jobs = const [],
    this.total = 0,
    this.page = 0,
    this.loadingMore = false,
    this.error,
  });

  final JobsStatus status;
  final JobsMeta meta;
  final JobFilter filter;
  final List<Job> jobs;
  final int total;
  final int page;
  final bool loadingMore;
  final String? error;

  bool get hasMore => jobs.length < total;

  JobsState copyWith({JobsStatus? status, JobsMeta? meta, JobFilter? filter, List<Job>? jobs, int? total, int? page, bool? loadingMore, String? error}) => JobsState(
        status: status ?? this.status,
        meta: meta ?? this.meta,
        filter: filter ?? this.filter,
        jobs: jobs ?? this.jobs,
        total: total ?? this.total,
        page: page ?? this.page,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );

  @override
  List<Object?> get props => [status, meta, filter, jobs, total, page, loadingMore, error];
}

// ---------- Bloc ----------
@injectable
class JobsBloc extends Bloc<JobsEvent, JobsState> {
  JobsBloc(this._meta, this._search) : super(const JobsState()) {
    on<JobsStarted>(_onStarted);
    on<JobsCategorySelected>((e, emit) => _reload(emit, state.filter.copyWith(category: () => e.category)));
    on<JobsSearchSubmitted>((e, emit) => _reload(emit, state.filter.copyWith(query: e.query)));
    on<JobsFiltersApplied>((e, emit) => _reload(emit, e.filter));
    on<JobsRefreshed>(_onRefreshed);
    on<JobsNextPageRequested>(_onNextPage);
  }

  final GetJobsMeta _meta;
  final SearchJobs _search;
  static const pageSize = 20;

  Future<void> _onStarted(JobsStarted e, Emitter<JobsState> emit) async {
    emit(state.copyWith(status: JobsStatus.loading));
    final meta = (await _meta(const NoParams())).valueOrNull ?? JobsMeta.fallback;
    // Open Flutter first if it has jobs (Flutter-first), otherwise show everything
    final first = meta.categories.isEmpty ? null : meta.categories.first;
    final category = e.category ?? (first != null && first.liveJobs > 0 ? first.slug : null);
    emit(state.copyWith(meta: meta));
    await _reload(emit, state.filter.copyWith(category: () => category));
  }

  Future<void> _onRefreshed(JobsRefreshed e, Emitter<JobsState> emit) async {
    try {
      final meta = (await _meta(const NoParams())).valueOrNull;
      if (meta != null) emit(state.copyWith(meta: meta));
      await _reload(emit, state.filter, showLoading: false);
    } finally {
      if (e.done != null && !e.done!.isCompleted) e.done!.complete();
    }
  }

  Future<void> _reload(Emitter<JobsState> emit, JobFilter filter, {bool showLoading = true}) async {
    emit(state.copyWith(filter: filter, status: showLoading ? JobsStatus.loading : state.status));
    final r = await _search(SearchJobsParams(filter, pageSize: pageSize));
    if (filter != state.filter) return; // a newer search replaced this one
    r.fold(
      (f) => emit(state.copyWith(status: JobsStatus.failure, error: f.message)),
      (res) => emit(state.copyWith(status: JobsStatus.success, jobs: res.items, total: res.total, page: 1)),
    );
  }

  Future<void> _onNextPage(JobsNextPageRequested e, Emitter<JobsState> emit) async {
    if (state.loadingMore || !state.hasMore || state.status != JobsStatus.success) return;
    emit(state.copyWith(loadingMore: true));
    final filter = state.filter;
    final r = await _search(SearchJobsParams(filter, page: state.page + 1, pageSize: pageSize));
    if (filter != state.filter) return;
    r.fold(
      (f) => emit(state.copyWith(loadingMore: false, error: f.message)),
      (res) => emit(state.copyWith(loadingMore: false, jobs: [...state.jobs, ...res.items], total: res.total, page: res.page)),
    );
  }
}
