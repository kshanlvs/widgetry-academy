import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';

Job job(String id, {String category = 'flutter', String? applyUrl, String? applyEmail, String? status}) => Job(
      id: id,
      title: 'Flutter Developer $id',
      category: category,
      company: const JobCompany(name: 'Acme'),
      type: 'full_time',
      mode: 'remote',
      level: 'mid',
      applyUrl: applyUrl,
      applyEmail: applyEmail,
      status: status,
    );

JobsResult page(List<Job> items, {int total = 0, int page = 1}) => JobsResult(items: items, total: total == 0 ? items.length : total, page: page, pageSize: 20);

const metaWithFlutterJobs = JobsMeta(liveJobs: 3, categories: [
  JobCategory(slug: 'flutter', name: 'Flutter', liveJobs: 3),
  JobCategory(slug: 'android', name: 'Android'),
]);

const metaNoFlutterJobs = JobsMeta(categories: [
  JobCategory(slug: 'flutter', name: 'Flutter'),
  JobCategory(slug: 'android', name: 'Android', liveJobs: 2),
]);
