import 'package:json_annotation/json_annotation.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';

part 'candidate_model.g.dart';

/// JSON shape of /talent/me. [toRequest] builds the body the server's PUT expects.
@JsonSerializable(createToJson: false)
class CandidateModel {
  const CandidateModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.headline,
    this.currentCompany,
    this.experienceYears = 0,
    this.city,
    this.categories = const ['flutter'],
    this.workModes = const [],
    this.jobTypes = const [],
    this.noticePeriod,
    this.expectedSalaryLpa,
    this.githubUrl,
    this.linkedinUrl,
    this.portfolioUrl,
    this.apps = const [],
    this.experience = const [],
    this.education = const [],
    this.certifications = const [],
    this.about,
    this.skills = const [],
    this.openToWork = true,
    this.hiddenCompanies,
    this.verification = 'self',
    this.photo,
    this.resumeSettings,
  });

  factory CandidateModel.fromJson(Map<String, dynamic> json) => _$CandidateModelFromJson(json);

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String headline;
  final String? currentCompany;
  final double experienceYears;
  final String? city;
  final List<String> categories;
  final List<String> workModes;
  final List<String> jobTypes;
  final String? noticePeriod;
  final double? expectedSalaryLpa;
  final String? githubUrl;
  final String? linkedinUrl;
  final String? portfolioUrl;
  final List<AppItemModel> apps;
  final List<WorkItemModel> experience;
  final List<EduItemModel> education;
  final List<CertItemModel> certifications;
  final String? about;
  final List<String> skills;
  final bool openToWork;
  final String? hiddenCompanies;
  final String verification;
  final String? photo;
  final ResumeSettingsModel? resumeSettings;

  Candidate toEntity() => Candidate(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        headline: headline,
        currentCompany: currentCompany,
        experienceYears: experienceYears,
        city: city,
        categories: categories.isEmpty ? const ['flutter'] : categories,
        workModes: workModes,
        jobTypes: jobTypes,
        noticePeriod: noticePeriod,
        expectedSalaryLpa: expectedSalaryLpa,
        githubUrl: githubUrl,
        linkedinUrl: linkedinUrl,
        portfolioUrl: portfolioUrl,
        apps: apps.map((a) => AppItem(name: a.name, url: a.url, role: a.role, about: a.about)).toList(),
        experience: experience.map((w) => WorkItem(company: w.company, role: w.role, start: w.start, end: w.end, points: w.points)).toList(),
        education: education.map((e) => EduItem(degree: e.degree, institute: e.institute, year: e.year, score: e.score)).toList(),
        certifications: certifications.map((c) => CertItem(name: c.name, issuer: c.issuer, year: c.year)).toList(),
        about: about,
        skills: skills,
        openToWork: openToWork,
        hiddenCompanies: hiddenCompanies,
        verification: verification,
        photo: photo,
        resumeSettings: resumeSettings?.toEntity() ?? const ResumeSettings(),
      );

  /// Body for PUT /talent/me. Empty strings mean "not set" on the server.
  static Map<String, dynamic> toRequest(Candidate p) => {
        'fullName': p.fullName.trim(),
        'phone': p.phone ?? '',
        'headline': p.headline.trim(),
        'currentCompany': p.currentCompany ?? '',
        'experienceYears': p.experienceYears,
        'city': p.city ?? '',
        'categories': p.categories,
        'workModes': p.workModes,
        'jobTypes': p.jobTypes,
        'noticePeriod': p.noticePeriod,
        'expectedSalaryLpa': p.expectedSalaryLpa,
        'githubUrl': p.githubUrl ?? '',
        'linkedinUrl': p.linkedinUrl ?? '',
        'portfolioUrl': p.portfolioUrl ?? '',
        'apps': [for (final a in p.apps) {'name': a.name, 'url': a.url ?? '', 'role': a.role ?? '', 'about': a.about ?? ''}],
        'experience': [for (final w in p.experience) {'company': w.company, 'role': w.role, 'start': w.start, 'end': w.end ?? '', 'points': w.points ?? ''}],
        'education': [for (final e in p.education) {'degree': e.degree, 'institute': e.institute, 'year': e.year, 'score': e.score ?? ''}],
        'certifications': [for (final c in p.certifications) {'name': c.name, 'issuer': c.issuer ?? '', 'year': c.year}],
        'about': p.about ?? '',
        'skills': p.skills,
        'openToWork': p.openToWork,
        'hiddenCompanies': p.hiddenCompanies ?? '',
        'consent': true,
      };
}

@JsonSerializable(createToJson: false)
class AppItemModel {
  const AppItemModel({required this.name, this.url, this.role, this.about});
  factory AppItemModel.fromJson(Map<String, dynamic> json) => _$AppItemModelFromJson(json);
  final String name;
  final String? url;
  final String? role;
  final String? about;
}

@JsonSerializable(createToJson: false)
class WorkItemModel {
  const WorkItemModel({required this.company, required this.role, required this.start, this.end, this.points});
  factory WorkItemModel.fromJson(Map<String, dynamic> json) => _$WorkItemModelFromJson(json);
  final String company;
  final String role;
  final String start;
  final String? end;
  final String? points;
}

@JsonSerializable(createToJson: false)
class EduItemModel {
  const EduItemModel({required this.degree, required this.institute, this.year, this.score});
  factory EduItemModel.fromJson(Map<String, dynamic> json) => _$EduItemModelFromJson(json);
  final String degree;
  final String institute;
  final int? year;
  final String? score;
}

@JsonSerializable(createToJson: false)
class CertItemModel {
  const CertItemModel({required this.name, this.issuer, this.year});
  factory CertItemModel.fromJson(Map<String, dynamic> json) => _$CertItemModelFromJson(json);
  final String name;
  final String? issuer;
  final int? year;
}

@JsonSerializable()
class ResumeSettingsModel {
  const ResumeSettingsModel({this.template = 'modern', this.accent = 'green', this.title, this.showPhoto = false, this.hide = const []});
  factory ResumeSettingsModel.fromJson(Map<String, dynamic> json) => _$ResumeSettingsModelFromJson(json);
  factory ResumeSettingsModel.fromEntity(ResumeSettings s) =>
      ResumeSettingsModel(template: s.template, accent: s.accent, title: s.title ?? '', showPhoto: s.showPhoto, hide: s.hide);

  final String template;
  final String accent;
  final String? title;
  final bool showPhoto;
  final List<String> hide;

  Map<String, dynamic> toJson() => _$ResumeSettingsModelToJson(this);
  ResumeSettings toEntity() => ResumeSettings(template: template, accent: accent, title: (title ?? '').isEmpty ? null : title, showPhoto: showPhoto, hide: hide);
}
