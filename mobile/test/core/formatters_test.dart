import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';

void main() {
  test('rupeesShort', () {
    expect(Fmt.rupeesShort(25000), '₹25k');
    expect(Fmt.rupeesShort(100000), '₹1L');
    expect(Fmt.rupeesShort(1250000), '₹12.5L');
    expect(Fmt.rupeesShort(500), '₹500');
  });

  test('rupees uses Indian grouping', () => expect(Fmt.rupees(1250000), '₹12,50,000'));

  test('salary ranges', () {
    expect(Fmt.salary(), '');
    expect(Fmt.salary(min: 600000, max: 900000, period: 'year', short: true), '₹6L–9L / year');
    expect(Fmt.salary(min: 30000, period: 'month', short: true), '₹30k+ / month');
    expect(Fmt.salary(max: 50000, short: true), 'up to ₹50k');
    expect(Fmt.salary(min: 40000, max: 40000, period: 'month', short: true), '₹40k / month');
  });

  test('timeAgo', () {
    final now = DateTime(2026, 10, 16, 12);
    expect(Fmt.timeAgo(now.subtract(const Duration(minutes: 5)), now: now), 'just now');
    expect(Fmt.timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(Fmt.timeAgo(now.subtract(const Duration(days: 1)), now: now), 'yesterday');
    expect(Fmt.timeAgo(now.subtract(const Duration(days: 6)), now: now), '6 days ago');
    expect(Fmt.timeAgo(DateTime(2026, 8, 2), now: now), '2 Aug');
    expect(Fmt.timeAgo(null), '');
  });

  test('yearMonth', () {
    expect(Fmt.yearMonth('2023-06'), 'Jun 2023');
    expect(Fmt.yearMonth(null), 'Present');
    expect(Fmt.yearMonth(''), 'Present');
  });

  test('initials and shortUrl', () {
    expect(Fmt.initials('Kishan Kumar Singh'), 'KK');
    expect(Fmt.initials('  '), '?');
    expect(Fmt.shortUrl('https://www.github.com/kishan/'), 'github.com/kishan');
  });
}
