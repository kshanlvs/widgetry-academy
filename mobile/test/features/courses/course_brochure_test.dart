import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';

void main() {
  const site = 'https://widgetryacademy.in';

  test('a brochure saved in admin wins', () {
    const c = Course(id: 'x', title: 'Anything', brochure: 'brochures/x.pdf');
    expect(c.brochureUrl(site), '$site/brochures/x.pdf');
  });

  test('courses saved before the field existed are matched by title', () {
    expect(const Course(id: 'a', title: 'Flutter in 10 Days').brochureUrl(site), '$site/Widgetry-Academy-Flutter-Brochure.pdf');
    expect(const Course(id: 'b', title: 'Food Delivery App with Flutter &Firebase').brochureUrl(site), '$site/brochures/food-delivery-app-course.pdf');
    expect(const Course(id: 'c', title: 'Flutter, Bloc & Clean Architecture').brochureUrl(site), '$site/brochures/flutter-clean-architecture-course.pdf');
  });

  test('no brochure, or a link that is not a PDF: nothing shown', () {
    expect(const Course(id: 'd', title: 'Something new').brochureUrl(site), isNull);
    expect(const Course(id: 'e', title: 'X', brochure: 'javascript:alert(1)').brochureUrl(site), isNull);
    expect(const Course(id: 'f', title: 'X', brochure: 'https://drive.google.com/file/abc').brochureUrl(site), 'https://drive.google.com/file/abc');
  });
}
