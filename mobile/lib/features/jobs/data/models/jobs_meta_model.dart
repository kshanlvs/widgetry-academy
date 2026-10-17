import 'package:json_annotation/json_annotation.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/jobs_meta.dart';

part 'jobs_meta_model.g.dart';

@JsonSerializable(createToJson: false)
class JobsMetaModel {
  const JobsMetaModel({this.liveJobs = 0, this.categories = const [], this.cities = const [], this.skills = const []});
  factory JobsMetaModel.fromJson(Map<String, dynamic> json) => _$JobsMetaModelFromJson(json);

  final int liveJobs;
  final List<CategoryModel> categories;
  final List<String> cities;
  final List<String> skills;

  JobsMeta toEntity() => JobsMeta(
        liveJobs: liveJobs,
        categories: categories.isEmpty ? JobsMeta.fallback.categories : categories.map((c) => c.toEntity()).toList(),
        cities: cities,
        skills: skills,
      );
}

@JsonSerializable(createToJson: false)
class CategoryModel {
  const CategoryModel({required this.slug, required this.name, this.liveJobs = 0, this.suggestedSkills = const []});
  factory CategoryModel.fromJson(Map<String, dynamic> json) => _$CategoryModelFromJson(json);
  final String slug;
  final String name;
  final int liveJobs;
  final List<String> suggestedSkills;

  JobCategory toEntity() => JobCategory(slug: slug, name: name, liveJobs: liveJobs, suggestedSkills: suggestedSkills);
}
