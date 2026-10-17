import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/network/api_client.dart';
import 'package:widgetry_academy/features/jobs/data/models/job_model.dart';
import 'package:widgetry_academy/features/jobs/data/models/jobs_meta_model.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job_filter.dart';

abstract interface class JobsRemoteDataSource {
  Future<JobsMetaModel> meta();
  Future<({List<JobModel> items, int total, int page, int pageSize})> search(JobFilter filter, int page, int pageSize);
  Future<JobModel> job(String id);
  Future<void> report(String id, String reason, String? details);
}

@LazySingleton(as: JobsRemoteDataSource)
class JobsRemoteDataSourceImpl implements JobsRemoteDataSource {
  JobsRemoteDataSourceImpl(this._api);
  final ApiClient _api;

  @override
  Future<JobsMetaModel> meta() async => JobsMetaModel.fromJson(await _api.get('/meta'));

  @override
  Future<({List<JobModel> items, int total, int page, int pageSize})> search(JobFilter filter, int page, int pageSize) async {
    final json = await _api.get('/jobs', query: {...filter.toQuery(), 'page': page, 'pageSize': pageSize});
    final items = (json['items'] as List? ?? const []).whereType<Map<String, dynamic>>().map(JobModel.fromJson).toList();
    return (items: items, total: (json['total'] as num?)?.toInt() ?? items.length, page: (json['page'] as num?)?.toInt() ?? page, pageSize: (json['pageSize'] as num?)?.toInt() ?? pageSize);
  }

  @override
  Future<JobModel> job(String id) async => JobModel.fromJson(await _api.get('/jobs/${Uri.encodeComponent(id)}'));

  @override
  Future<void> report(String id, String reason, String? details) async {
    await _api.post('/jobs/${Uri.encodeComponent(id)}/report', body: {'reason': reason, if (details != null && details.trim().isNotEmpty) 'details': details.trim()});
  }
}
