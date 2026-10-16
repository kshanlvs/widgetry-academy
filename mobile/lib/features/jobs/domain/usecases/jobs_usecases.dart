import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/domain/repositories/jobs_repository.dart';

@injectable
class GetJobsMeta implements UseCase<JobsMeta, NoParams> {
  const GetJobsMeta(this._repo);
  final JobsRepository _repo;
  @override
  Future<Result<JobsMeta>> call(NoParams p) => _repo.getMeta();
}

class SearchJobsParams extends Equatable {
  const SearchJobsParams(this.filter, {this.page = 1, this.pageSize = 20});
  final JobFilter filter;
  final int page;
  final int pageSize;
  @override
  List<Object?> get props => [filter, page, pageSize];
}

@injectable
class SearchJobs implements UseCase<JobsResult, SearchJobsParams> {
  const SearchJobs(this._repo);
  final JobsRepository _repo;
  @override
  Future<Result<JobsResult>> call(SearchJobsParams p) => _repo.search(p.filter, page: p.page, pageSize: p.pageSize);
}

@injectable
class GetJobDetail implements UseCase<Job, String> {
  const GetJobDetail(this._repo);
  final JobsRepository _repo;
  @override
  Future<Result<Job>> call(String id) => _repo.getJob(id);
}

class ReportJobParams extends Equatable {
  const ReportJobParams({required this.jobId, required this.reason, this.details});
  final String jobId;
  final String reason;
  final String? details;
  @override
  List<Object?> get props => [jobId, reason, details];
}

@injectable
class ReportJob implements UseCase<Unit, ReportJobParams> {
  const ReportJob(this._repo);
  final JobsRepository _repo;
  @override
  Future<Result<Unit>> call(ReportJobParams p) => _repo.report(p.jobId, reason: p.reason, details: p.details);
}

@injectable
class GetSavedJobs implements UseCase<List<Job>, NoParams> {
  const GetSavedJobs(this._repo);
  final JobsRepository _repo;
  @override
  Future<Result<List<Job>>> call(NoParams p) => _repo.savedJobs();
}

@injectable
class IsJobSaved implements UseCase<bool, String> {
  const IsJobSaved(this._repo);
  final JobsRepository _repo;
  @override
  Future<Result<bool>> call(String id) => _repo.isSaved(id);
}

@injectable
class ToggleSavedJob implements UseCase<bool, Job> {
  const ToggleSavedJob(this._repo);
  final JobsRepository _repo;
  @override
  Future<Result<bool>> call(Job job) => _repo.toggleSaved(job);
}
