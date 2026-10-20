import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/workshops/domain/workshops.dart';

const blocCard = Course(id: 'b', title: 'Bloc Crash Course', ctaLink: 'bloc-crash-course.html', price: 799, mrp: 999, priceNote: 'old note', showBatch: true);
Workshop ws({String status = 'open', int seats = 10, String? schedule, DateTime? startsAt, int? early = 799}) =>
    Workshop(slug: 'bloc-crash-course', title: 'Bloc', status: status, price: 999, earlyPrice: early, earlySeatsLeft: 3, seatsLeft: seats, schedule: schedule, startsAt: startsAt);

void main() {
  test('a short course card never shows the Flutter batch date', () {
    expect(blocCard.usesBatch, isFalse);
    expect(const Course(id: 'f', title: 'Flutter in 10 Days', flagship: true).usesBatch, isTrue);
  });

  test('draft short course: card says dates coming soon, like its page', () {
    final c = CoursesCubit.withShortCourse(blocCard, [ws(status: 'draft')]);
    expect(c.dateLine, 'Dates coming soon');
    expect(c.enrolling, isFalse);
    expect(c.live?.tag, 'Dates soon');
  });

  test('draft with a date: shows the date and that enrolment opens soon', () {
    final c = CoursesCubit.withShortCourse(blocCard, [ws(status: 'draft', schedule: 'Sat 8 & Sun 9 Nov')]);
    expect(c.dateLine, 'Sat 8 & Sun 9 Nov · enrolment opens soon');
    expect(c.enrolling, isFalse);
  });

  test('open short course: its dates and its price', () {
    final c = CoursesCubit.withShortCourse(blocCard, [ws(schedule: 'Sat 8 & Sun 9 Nov')]);
    expect(c.dateLine, 'Sat 8 & Sun 9 Nov');
    expect(c.enrolling, isTrue);
    expect([c.price, c.mrp], [799, 999]);
    expect(c.priceNote, 'Early-bird price · 3 seats left');
  });

  test('full batch', () {
    final c = CoursesCubit.withShortCourse(blocCard, [ws(seats: 0)]);
    expect([c.dateLine, c.enrolling, c.live?.tag], ['This batch is full', false, 'Batch full']);
  });

  test('short course not listed (closed): next dates coming soon; not loaded: card as saved', () {
    expect(CoursesCubit.withShortCourse(blocCard, const []).dateLine, 'Next batch dates coming soon');
    final same = CoursesCubit.withShortCourse(blocCard, null);
    expect(same, blocCard);
    expect(same.dateLine, isNull);
  });

  test('other courses use their own start date', () {
    const c = Course(id: 'x', title: 'Food Delivery App', startDate: 'Sat 24 Oct 2026', showBatch: true);
    expect(c.dateLine, 'Starts Sat 24 Oct 2026');
    expect(c.usesBatch, isFalse);
    expect(CoursesCubit.withShortCourse(c, const []), c);
  });
}
