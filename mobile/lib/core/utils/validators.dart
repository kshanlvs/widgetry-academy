/// Form validators. Return an error message, or null when the value is fine.
abstract final class Validators {
  static String? required(String? v, [String field = 'This field']) => (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? null : 'Enter a valid email address';
  }

  static String? password(String? v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null;

  /// 10-digit Indian mobile number, with or without +91.
  static String? indianMobile(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');
    return RegExp(r'^[6-9]\d{9}$').hasMatch(d) ? null : 'Enter a valid 10-digit mobile number';
  }

  static String? optionalHttpsUrl(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final u = Uri.tryParse(v.trim());
    return (u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.contains('.')) ? null : 'Enter a full link starting with https://';
  }

  static String normalizeIndianMobile(String v) => v.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');
}
