import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/presentation/cubit/courses_cubit.dart';
import 'package:widgetry_academy/features/courses/presentation/widgets/my_course.dart';

Registration reg(String status, {int paid = 0, String course = 'Flutter in 10 Days'}) =>
    Registration(name: 'A', email: 'a@b.in', phone: '+919876543210', level: 'Graduate', experience: '', course: course, payStatus: status, amountPaid: paid);

void main() {
  const flagship = Course(id: 'f10', title: 'Flutter in 10 Days', flagship: true);
  const other = Course(id: 'pro', title: 'Professional Flutter Program', status: 'soon');

  test('my course is the one registered for, so its sales card can be hidden', () {
    expect(CoursesState(courses: const [other, flagship], registration: reg('pending')).myCourse, flagship);
    expect(const CoursesState(courses: [other, flagship]).myCourse, isNull);
    expect(CoursesState(courses: const [other, flagship], registration: reg('refunded')).myCourse, isNull, reason: 'refunded students see the course again');
    expect(CoursesState(courses: const [other, flagship], registration: reg('pending', course: 'Unknown title')).myCourse, flagship, reason: 'old registrations fall back to the flagship');
  });

  test('enrolment stage follows the pay status used in admin', () {
    expect(stageOf(reg('pending')), EnrolmentStage.registered);
    expect(stageOf(reg('part-paid', paid: 2500)), EnrolmentStage.booked);
    expect(stageOf(reg('paid', paid: 4999)), EnrolmentStage.enrolled);
  });
}
