import 'package:equatable/equatable.dart';

/// A job category (Flutter, Android, iOS, React Native, …). Comes from the server, so new ones appear without an app update.
class JobCategory extends Equatable {
  const JobCategory({required this.slug, required this.name, this.liveJobs = 0, this.suggestedSkills = const []});
  final String slug;
  final String name;
  final int liveJobs;
  final List<String> suggestedSkills;
  @override
  List<Object?> get props => [slug, name, liveJobs, suggestedSkills];
}

class JobsMeta extends Equatable {
  const JobsMeta({this.liveJobs = 0, this.categories = const [], this.cities = const [], this.skills = const []});
  final int liveJobs;
  final List<JobCategory> categories;
  final List<String> cities;
  final List<String> skills;

  static const fallback = JobsMeta(categories: [
    JobCategory(slug: 'flutter', name: 'Flutter'),
    JobCategory(slug: 'android', name: 'Android'),
    JobCategory(slug: 'ios', name: 'iOS'),
    JobCategory(slug: 'react-native', name: 'React Native'),
  ]);

  String categoryName(String slug) => categories.where((c) => c.slug == slug).map((c) => c.name).firstOrNull ?? (slug.isEmpty ? 'Flutter' : slug[0].toUpperCase() + slug.substring(1));

  @override
  List<Object?> get props => [liveJobs, categories, cities, skills];
}
