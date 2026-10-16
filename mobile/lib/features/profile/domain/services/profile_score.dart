import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';

class ScoreTip {
  const ScoreTip(this.text, this.action);
  final String text;
  /// "photo", "edit" or "verify"
  final String action;
}

class ProfileScore {
  const ProfileScore(this.score, this.tips);
  final int score;
  final List<ScoreTip> tips;

  String get level => score >= 85 ? 'All-star profile ⭐' : score >= 65 ? 'Strong profile' : score >= 40 ? 'Good start' : 'Just getting started';
}

/// Same scoring as the website's profile page, so the number matches everywhere.
abstract final class ProfileScorer {
  static bool _isLink(String? u) => u != null && RegExp(r'^https?://', caseSensitive: false).hasMatch(u);

  static ProfileScore score(Candidate p) {
    final bullets = p.experience.expand((w) => w.bullets).toList();
    final checks = <(bool, int, ScoreTip)>[
      (p.photo != null, 8, const ScoreTip('Add a profile photo', 'photo')),
      ((p.about ?? '').length >= 120, 10, const ScoreTip('Write a 2–3 line summary about what you build', 'edit')),
      (p.skills.length >= 6, 10, const ScoreTip('Add at least 6 skills', 'edit')),
      (p.experience.isNotEmpty || p.experienceYears == 0, 12, const ScoreTip('Add your work experience or internships', 'edit')),
      (bullets.any((l) => RegExp(r'\d').hasMatch(l)), 10, const ScoreTip('Use numbers in your achievements (downloads, % faster, users)', 'edit')),
      (p.apps.any((a) => _isLink(a.url)), 14, const ScoreTip('Add an app or project with a Play Store or GitHub link', 'edit')),
      (p.education.isNotEmpty, 8, const ScoreTip('Add your education', 'edit')),
      ((p.githubUrl ?? '').isNotEmpty && (p.linkedinUrl ?? '').isNotEmpty, 8, const ScoreTip('Add both GitHub and LinkedIn', 'edit')),
      ((p.phone ?? '').isNotEmpty, 5, const ScoreTip('Add your phone number', 'edit')),
      (p.jobTypes.isNotEmpty && p.workModes.isNotEmpty, 5, const ScoreTip('Tell us the job type and work mode you want', 'edit')),
      (p.verification != 'self', 10, const ScoreTip('Get your portfolio checked by a Widgetry engineer', 'verify')),
    ];
    final score = checks.fold<int>(0, (s, c) => s + (c.$1 ? c.$2 : 0));
    return ProfileScore(score, [for (final c in checks) if (!c.$1) c.$3]);
  }
}
