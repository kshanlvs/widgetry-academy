import 'package:equatable/equatable.dart';

class JobCompany extends Equatable {
  const JobCompany({required this.name, this.website, this.verified = false});
  final String name;
  final String? website;
  final bool verified;
  @override
  List<Object?> get props => [name, website, verified];
}

class JobSalary extends Equatable {
  const JobSalary({this.min, this.max, this.period});
  final int? min;
  final int? max;
  final String? period;
  @override
  List<Object?> get props => [min, max, period];
}

/// A job listing. [description], [applyUrl] and [applyEmail] are only filled on the detail screen.
class Job extends Equatable {
  const Job({
    required this.id,
    required this.title,
    required this.category,
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
    this.applyUrl,
    this.applyEmail,
  });

  final String id;
  final String title;
  final String category;
  final JobCompany company;
  final String type;
  final String mode;
  final String level;
  final String? city;
  final JobSalary? salary;
  final List<String> skills;
  final bool featured;
  final DateTime? postedAt;
  final DateTime? expiresAt;

  /// "open", "filled" or "closed" on the detail screen; "approved" in lists.
  final String? status;
  final String? description;
  final String? applyUrl;
  final String? applyEmail;

  bool get isOpen => status == null || status == 'open' || status == 'approved';
  bool get canApply => isOpen && ((applyUrl ?? '').isNotEmpty || (applyEmail ?? '').isNotEmpty);
  String get shareUrl => 'https://widgetryacademy.in/job.html?id=$id';

  @override
  List<Object?> get props => [id, title, category, company, type, mode, level, city, salary, skills, featured, postedAt, expiresAt, status, description, applyUrl, applyEmail];
}
