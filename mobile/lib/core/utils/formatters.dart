import 'package:intl/intl.dart';

/// Text formatting shared across features.
abstract final class Fmt {
  static final _inr = NumberFormat.decimalPattern('en_IN');
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String rupees(num n) => '₹${_inr.format(n)}';

  /// ₹25k, ₹1.2L: short form for job cards.
  static String rupeesShort(num n) {
    if (n >= 100000) {
      final l = n / 100000;
      return '₹${l == l.roundToDouble() ? l.toStringAsFixed(0) : l.toStringAsFixed(1)}L';
    }
    if (n >= 1000) return '₹${(n / 1000).round()}k';
    return '₹$n';
  }

  static String salary({int? min, int? max, String? period, bool short = false}) {
    if (min == null && max == null) return '';
    final f = short ? rupeesShort : rupees;
    final per = switch (period) { 'month' => '/ month', 'year' => '/ year', 'project' => '/ project', _ => '' };
    final range = min != null && max != null ? (min == max ? f(min) : '${f(min)}–${f(max).substring(1)}') : (min != null ? '${f(min)}+' : 'up to ${f(max!)}');
    return '$range $per'.trim();
  }

  static String timeAgo(DateTime? d, {DateTime? now}) {
    if (d == null) return '';
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inHours < 1) return 'just now';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    return '${d.day} ${_months[d.month - 1]}';
  }

  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// "2023-06" → "Jun 2023"; null/empty → "Present".
  static String yearMonth(String? ym) {
    if (ym == null || ym.isEmpty) return 'Present';
    final p = ym.split('-');
    if (p.length != 2) return ym;
    final m = int.tryParse(p[1]) ?? 1;
    return '${_months[(m - 1).clamp(0, 11)]} ${p[0]}';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    final s = parts.map((w) => w[0]).join().toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  static String shortUrl(String url) => url.replaceFirst(RegExp(r'^https?://(www\.)?'), '').replaceFirst(RegExp(r'/$'), '');
}

/// Labels for API enum values (same as the website).
abstract final class Labels {
  static const jobType = {'full_time': 'Full-time', 'internship': 'Internship', 'freelance': 'Freelance', 'contract': 'Contract', 'part_time': 'Part-time'};
  static const workMode = {'remote': 'Remote', 'onsite': 'On-site', 'hybrid': 'Hybrid'};
  static const level = {'fresher': 'Fresher', 'junior': 'Junior (0–2 yrs)', 'mid': 'Mid (2–5 yrs)', 'senior': 'Senior (5+ yrs)', 'lead': 'Lead'};
  static const notice = {'immediate': 'Immediate', '15_days': '15 days', '30_days': '30 days', '60_days': '60 days', '90_days': '90 days'};
  static const verification = {'self': 'Self-declared', 'portfolio': 'Portfolio checked', 'verified': 'Widgetry verified'};
  static const report = {
    'scam': 'Looks like a scam',
    'asks_fees': 'Asks candidates to pay',
    'fake': 'Fake company or job',
    'expired': 'Job is no longer open',
    'wrong_info': 'Wrong information',
    'other': 'Something else',
  };
}
