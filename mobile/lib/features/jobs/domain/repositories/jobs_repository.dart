import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';

abstract interface class JobsRepository {
  Future<Result<JobsMeta>> getMeta();
  Future<Result<JobsResult>> search(JobFilter filter, {int page = 1, int pageSize = 20});
  Future<Result<Job>> getJob(String id);
  Future<Result<Unit>> report(String jobId, {required String reason, String? details});

  // Saved jobs live on the phone
  Future<Result<List<Job>>> savedJobs();
  Future<Result<bool>> isSaved(String jobId);
  /// Returns true if the job is now saved, false if it was removed.
  Future<Result<bool>> toggleSaved(Job job);
}
