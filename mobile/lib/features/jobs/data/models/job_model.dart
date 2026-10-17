import 'package:json_annotation/json_annotation.dart';
import 'package:widgetry_academy/features/jobs/domain/entities/job.dart';

part 'job_model.g.dart';

/// JSON shape of a job from the Widgetry Jobs API. Mapped to the [Job] entity with [toEntity].
@JsonSerializable()
class JobModel {
  const JobModel({
    required this.id,
    required this.title,
    this.category = 'flutter',
    required this.company,
    required this.type,
    required this.mode,
    required this.level,
    this.city,
    this.salary,
    this.skills = const [],
    this.featured = false,
    this.postedAt,
    this.expiresAt,
    this.status,
    this.description,
    this.apply,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) => _$JobModelFromJson(json);

  factory JobModel.fromEntity(Job j) => JobModel(
        id: j.id,
        title: j.title,
        category: j.category,
        company: CompanyModel(name: j.company.name, website: j.company.website, verified: j.company.verified),
        type: j.type,
        mode: j.mode,
        level: j.level,
        city: j.city,
        salary: j.salary == null ? null : SalaryModel(min: j.salary!.min, max: j.salary!.max, period: j.salary!.period),
        skills: j.skills,
        featured: j.featured,
        postedAt: j.postedAt,
        expiresAt: j.expiresAt,
        status: j.status,
      );

  final String id;
  final String title;
  final String category;
  final CompanyModel company;
  final String type;
  final String mode;
  final String level;
  final String? city;
  final SalaryModel? salary;
  final List<String> skills;
  final bool featured;
  final DateTime? postedAt;
  final DateTime? expiresAt;
  final String? status;
  final String? description;
  final ApplyModel? apply;

  Map<String, dynamic> toJson() => _$JobModelToJson(this);

  Job toEntity() => Job(
        id: id,
        title: title,
        category: category,
        company: JobCompany(name: company.name, website: company.website, verified: company.verified),
        type: type,
        mode: mode,
        level: level,
        city: city,
        salary: salary == null || (salary!.min == null && salary!.max == null) ? null : JobSalary(min: salary!.min, max: salary!.max, period: salary!.period),
        skills: skills,
        featured: featured,
        postedAt: postedAt,
        expiresAt: expiresAt,
        status: status,
        description: description,
        applyUrl: apply?.url,
        applyEmail: apply?.email,
      );
}

@JsonSerializable()
class CompanyModel {
  const CompanyModel({required this.name, this.website, this.verified = false});
  factory CompanyModel.fromJson(Map<String, dynamic> json) => _$CompanyModelFromJson(json);
  final String name;
  final String? website;
  final bool verified;
  Map<String, dynamic> toJson() => _$CompanyModelToJson(this);
}

@JsonSerializable()
class SalaryModel {
  const SalaryModel({this.min, this.max, this.period});
  factory SalaryModel.fromJson(Map<String, dynamic> json) => _$SalaryModelFromJson(json);
  final int? min;
  final int? max;
  final String? period;
  Map<String, dynamic> toJson() => _$SalaryModelToJson(this);
}

@JsonSerializable()
class ApplyModel {
  const ApplyModel({this.url, this.email});
  factory ApplyModel.fromJson(Map<String, dynamic> json) => _$ApplyModelFromJson(json);
  final String? url;
  final String? email;
  Map<String, dynamic> toJson() => _$ApplyModelToJson(this);
}
