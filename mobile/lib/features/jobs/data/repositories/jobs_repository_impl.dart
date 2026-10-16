import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/jobs/data/datasources/jobs_remote_data_source.dart';
import 'package:widgetry_academy/features/jobs/data/datasources/saved_jobs_local_data_source.dart';
import 'package:widgetry_academy/features/jobs/data/models/job_model.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';
import 'package:widgetry_academy/features/jobs/domain/repositories/jobs_repository.dart';

@LazySingleton(as: JobsRepository)
class JobsRepositoryImpl implements JobsRepository {
  JobsRepositoryImpl(this._remote, this._local);
  final JobsRemoteDataSource _remote;
  final SavedJobsLocalDataSource _local;

  @override
  Future<Result<JobsMeta>> getMeta() => guard(() async => (await _remote.meta()).toEntity());

  @override
  Future<Result<JobsResult>> search(JobFilter filter, {int page = 1, int pageSize = 20}) => guard(() async {
        final r = await _remote.search(filter, page, pageSize);
        return JobsResult(items: r.items.map((m) => m.toEntity()).toList(), total: r.total, page: r.page, pageSize: r.pageSize);
      });

  @override
  Future<Result<Job>> getJob(String id) => guard(() async => (await _remote.job(id)).toEntity());

  @override
  Future<Result<Unit>> report(String jobId, {required String reason, String? details}) => guard(() async {
        await _remote.report(jobId, reason, details);
        return unit;
      });

  @override
  Future<Result<List<Job>>> savedJobs() => guard(() async => _local.all().map((m) => m.toEntity()).toList());

  @override
  Future<Result<bool>> isSaved(String jobId) => guard(() async => _local.contains(jobId));

  @override
  Future<Result<bool>> toggleSaved(Job job) => guard(() async {
        if (_local.contains(job.id)) {
          await _local.remove(job.id);
          return false;
        }
        await _local.save(JobModel.fromEntity(job));
        return true;
      });
}
