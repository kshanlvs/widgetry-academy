import 'package:equatable/equatable.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';

/// Search and filters for the jobs list. A null [category] means all categories.
class JobFilter extends Equatable {
  const JobFilter({this.category, this.query = '', this.type, this.mode, this.level, this.city, this.skill});
  final String? category;
  final String query;
  final String? type;
  final String? mode;
  final String? level;
  final String? city;
  final String? skill;

  int get activeCount => [type, mode, level, city, skill].where((v) => v != null).length;

  JobFilter copyWith({
    String? Function()? category,
    String? query,
    String? Function()? type,
    String? Function()? mode,
    String? Function()? level,
    String? Function()? city,
    String? Function()? skill,
  }) =>
      JobFilter(
        category: category != null ? category() : this.category,
        query: query ?? this.query,
        type: type != null ? type() : this.type,
        mode: mode != null ? mode() : this.mode,
        level: level != null ? level() : this.level,
        city: city != null ? city() : this.city,
        skill: skill != null ? skill() : this.skill,
      );

  JobFilter clearedFilters() => JobFilter(category: category, query: query);

  Map<String, dynamic> toQuery() => {
        'category': category,
        'q': query.trim().isEmpty ? null : query.trim(),
        'type': type,
        'mode': mode,
        'level': level,
        'city': city,
        'skill': skill,
      };

  @override
  List<Object?> get props => [category, query, type, mode, level, city, skill];
}

/// One page of search results.
class JobsResult extends Equatable {
  const JobsResult({required this.items, required this.total, required this.page, required this.pageSize});
  final List<Job> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  @override
  List<Object?> get props => [items, total, page, pageSize];
}
