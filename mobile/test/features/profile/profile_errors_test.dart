import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/features/profile/domain/services/profile_errors.dart';

void main() {
  test('server field errors become readable', () {
    expect(ProfileErrors.readable('apps.0.url: Invalid url'), 'App 1, link: enter a full link, e.g. https://github.com/you');
    expect(ProfileErrors.readable('education.1.institute: Add the college or school'), 'Education 2, college or school: add the college or school');
    expect(ProfileErrors.readable('githubUrl: Enter a full link, e.g. https://github.com/you'), 'GitHub link: enter a full link, e.g. https://github.com/you');
    expect(ProfileErrors.readable('No internet connection.'), 'No internet connection.');
    expect(ProfileErrors.readable('unknownField: Something'), 'unknownField: Something');
  });
}
