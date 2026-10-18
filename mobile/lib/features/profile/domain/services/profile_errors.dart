/// Turns the server's "apps.0.url: Invalid url" into "App 1, link: Invalid url",
/// so the student knows which part of the form to fix.
abstract final class ProfileErrors {
  static const _fields = {
    'fullName': 'Name',
    'phone': 'Phone',
    'headline': 'Headline',
    'currentCompany': 'Current company',
    'experienceYears': 'Experience',
    'city': 'City',
    'categories': 'I work with',
    'skills': 'Skills',
    'githubUrl': 'GitHub link',
    'linkedinUrl': 'LinkedIn link',
    'portfolioUrl': 'Portfolio link',
    'expectedSalaryLpa': 'Expected salary',
    'about': 'About',
    'hiddenCompanies': 'Never show my profile to',
    'consent': 'Consent',
  };
  static const _lists = {'apps': 'App', 'experience': 'Job', 'education': 'Education', 'certifications': 'Certificate'};
  static const _parts = {
    'url': 'link',
    'name': 'name',
    'role': 'role',
    'about': 'description',
    'company': 'company',
    'start': 'start date',
    'end': 'end date',
    'points': 'what you did',
    'degree': 'degree',
    'institute': 'college or school',
    'year': 'year',
    'score': 'score',
    'issuer': 'issued by',
  };

  static String readable(String message) {
    final m = RegExp(r'^([A-Za-z]+)(?:\.(\d+))?(?:\.([A-Za-z]+))?:\s*(.+)$').firstMatch(message.trim());
    if (m == null) return message;
    final field = m.group(1)!, index = m.group(2), part = m.group(3), text = m.group(4)!;
    final String where;
    if (_lists.containsKey(field) && index != null) {
      where = '${_lists[field]} ${int.parse(index) + 1}${part == null ? '' : ', ${_parts[part] ?? part}'}';
    } else if (_fields.containsKey(field)) {
      where = _fields[field]!;
    } else {
      return message;
    }
    final t = text == 'Invalid url' ? 'enter a full link, e.g. https://github.com/you' : text;
    return '$where: ${t[0].toLowerCase()}${t.substring(1)}';
  }
}
