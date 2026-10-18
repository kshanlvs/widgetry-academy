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

  /// A web link. "github.com/you" is accepted and completed to "https://github.com/you" by [normalizeUrl].
  static String? optionalHttpsUrl(String? v) {
    final n = normalizeUrl(v);
    if (n.isEmpty) return null;
    if (n.contains(RegExp(r'\s'))) return 'Links can\'t contain spaces';
    final u = Uri.tryParse(n);
    return (u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.contains('.') && n.length <= 400) ? null : 'Enter a full link, e.g. https://github.com/you';
  }

  /// Trims, and adds https:// when the scheme is missing. Empty stays empty.
  static String normalizeUrl(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '';
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(t)) return t;
    return 'https://$t';
  }

  /// Optional phone, same rule as the server: digits, spaces and dashes, 8 to 17 characters.
  static String? optionalPhone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return RegExp(r'^\+?\d[\d\s-]{7,16}$').hasMatch(t) ? null : 'Enter a valid phone number';
  }

  /// Optional year between 1970 and 2040.
  static String? optionalYear(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final y = int.tryParse(t);
    return y != null && y >= 1970 && y <= 2040 ? null : 'Enter a year, e.g. 2024';
  }

  static String normalizeIndianMobile(String v) => v.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');
}
