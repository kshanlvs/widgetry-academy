import 'package:equatable/equatable.dart';

class WorkItem extends Equatable {
  const WorkItem({required this.company, required this.role, required this.start, this.end, this.points});
  final String company;
  final String role;
  /// "YYYY-MM"
  final String start;
  /// "YYYY-MM", or null for a current job
  final String? end;
  /// One achievement per line
  final String? points;

  List<String> get bullets => (points ?? '').split('\n').map((l) => l.replaceFirst(RegExp(r'^\s*[-•*·]\s*'), '').trim()).where((l) => l.isNotEmpty).toList();

  @override
  List<Object?> get props => [company, role, start, end, points];
}

class EduItem extends Equatable {
  const EduItem({required this.degree, required this.institute, this.year, this.score});
  final String degree;
  final String institute;
  final int? year;
  final String? score;
  @override
  List<Object?> get props => [degree, institute, year, score];
}

class AppItem extends Equatable {
  const AppItem({required this.name, this.url, this.role, this.about});
  final String name;
  final String? url;
  final String? role;
  final String? about;
  @override
  List<Object?> get props => [name, url, role, about];
}

class CertItem extends Equatable {
  const CertItem({required this.name, this.issuer, this.year});
  final String name;
  final String? issuer;
  final int? year;
  @override
  List<Object?> get props => [name, issuer, year];
}

class ResumeSettings extends Equatable {
  const ResumeSettings({this.template = 'modern', this.accent = 'green', this.title, this.showPhoto = false, this.hide = const [], this.density = 'normal'});
  final String template;
  final String accent;
  final String? title;
  final bool showPhoto;
  final List<String> hide;
  /// "Fit to one page": normal, compact or tight (the same resume, slightly smaller).
  final String density;

  bool shows(String part) => !hide.contains(part);

  ResumeSettings copyWith({String? template, String? accent, String? title, bool? showPhoto, List<String>? hide, String? density}) => ResumeSettings(
        template: template ?? this.template,
        accent: accent ?? this.accent,
        title: title ?? this.title,
        showPhoto: showPhoto ?? this.showPhoto,
        hide: hide ?? this.hide,
        density: density ?? this.density,
      );

  @override
  List<Object?> get props => [template, accent, title, showPhoto, hide, density];
}

/// A job seeker's Talent Network profile. Also the source of their resume.
class Candidate extends Equatable {
  const Candidate({
    this.id = '',
    required this.fullName,
    this.email = '',
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
    this.resumeSettings = const ResumeSettings(),
    this.mockInterview,
    this.achievements = const [],
    this.languages = const [],
    this.talentNetwork = false,
  });

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
  final List<AppItem> apps;
  final List<WorkItem> experience;
  final List<EduItem> education;
  final List<CertItem> certifications;
  final String? about;
  final List<String> skills;
  final bool openToWork;
  final String? hiddenCompanies;
  /// "self", "portfolio" or "verified"
  final String verification;
  /// data:image/... URL, or null
  final String? photo;
  final ResumeSettings resumeSettings;
  /// A mock interview score the candidate chose to show, or null.
  final MockBadge? mockInterview;
  /// One line each: awards, hackathons, positions of responsibility.
  final List<String> achievements;
  final List<String> languages;
  /// Joined the Talent Network (employers can be introduced, with approval). Building a resume doesn't need it.
  final bool talentNetwork;

  Candidate copyWith({bool? openToWork, String? photo, bool clearPhoto = false, ResumeSettings? resumeSettings, bool? talentNetwork}) => Candidate(
        id: id, fullName: fullName, email: email, phone: phone, headline: headline, currentCompany: currentCompany,
        experienceYears: experienceYears, city: city, categories: categories, workModes: workModes, jobTypes: jobTypes,
        noticePeriod: noticePeriod, expectedSalaryLpa: expectedSalaryLpa, githubUrl: githubUrl, linkedinUrl: linkedinUrl,
        portfolioUrl: portfolioUrl, apps: apps, experience: experience, education: education, certifications: certifications,
        about: about, skills: skills, openToWork: openToWork ?? this.openToWork, hiddenCompanies: hiddenCompanies,
        verification: verification, photo: clearPhoto ? null : (photo ?? this.photo), resumeSettings: resumeSettings ?? this.resumeSettings, mockInterview: mockInterview,
        achievements: achievements, languages: languages, talentNetwork: talentNetwork ?? this.talentNetwork,
      );

  @override
  List<Object?> get props => [
        id, fullName, email, phone, headline, currentCompany, experienceYears, city, categories, workModes, jobTypes, noticePeriod,
        expectedSalaryLpa, githubUrl, linkedinUrl, portfolioUrl, apps, experience, education, certifications, about, skills,
        openToWork, hiddenCompanies, verification, photo, resumeSettings, mockInterview, achievements, languages, talentNetwork,
      ];
}

/// "Mock interview 4.2/5 · Flutter" on the profile.
class MockBadge extends Equatable {
  const MockBadge({required this.overall, required this.track});
  final double overall;
  final String track;
  @override
  List<Object?> get props => [overall, track];
}
