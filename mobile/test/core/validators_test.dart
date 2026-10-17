import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts a normal address', () => expect(Validators.email('kishan@widgetryacademy.in'), isNull));
    test('rejects empty and malformed', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('kishan@'), isNotNull);
      expect(Validators.email('a b@c.in'), isNotNull);
    });
  });

  group('Validators.indianMobile', () {
    test('accepts 10 digits, with +91, spaces or dashes', () {
      expect(Validators.indianMobile('9876543210'), isNull);
      expect(Validators.indianMobile('+91 98765 43210'), isNull);
      expect(Validators.indianMobile('91-9876543210'), isNull);
    });
    test('rejects numbers not starting 6–9 or the wrong length', () {
      expect(Validators.indianMobile('5876543210'), isNotNull);
      expect(Validators.indianMobile('98765'), isNotNull);
      expect(Validators.indianMobile(null), isNotNull);
    });
    test('normalizes to 10 digits', () => expect(Validators.normalizeIndianMobile('+91 98765-43210'), '9876543210'));
  });

  test('optionalHttpsUrl allows empty, needs a full link otherwise', () {
    expect(Validators.optionalHttpsUrl(''), isNull);
    expect(Validators.optionalHttpsUrl('https://github.com/kishan'), isNull);
    expect(Validators.optionalHttpsUrl('github.com/kishan'), isNotNull);
    expect(Validators.optionalHttpsUrl('ftp://x.in'), isNotNull);
  });

  test('password needs 8 characters', () {
    expect(Validators.password('1234567'), isNotNull);
    expect(Validators.password('12345678'), isNull);
  });
}
