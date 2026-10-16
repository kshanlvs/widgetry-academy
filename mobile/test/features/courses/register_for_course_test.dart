import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/domain/repositories/courses_repository.dart';
import 'package:widgetry_academy/features/courses/domain/usecases/courses_usecases.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late MockCoursesRepository repo;
  late RegisterForCourse register;

  const valid = Registration(name: 'Asha', email: 'asha@example.com', phone: '+91 98765 43210', level: 'Graduate', experience: 'None, complete beginner', course: 'Flutter in 10 Days');

  setUpAll(() => registerFallbackValue(valid));
  setUp(() {
    repo = MockCoursesRepository();
    register = RegisterForCourse(repo);
    when(() => repo.register(any())).thenAnswer((i) async => Success(i.positionalArguments.first as Registration));
  });

  test('saves a valid registration', () async {
    final r = await register(valid);
    expect(r.isSuccess, isTrue);
    verify(() => repo.register(valid)).called(1);
  });

  Future<void> rejects(Registration r, String message) async {
    final res = await register(r);
    expect(res.failureOrNull, ValidationFailure(message));
    verifyNever(() => repo.register(any()));
  }

  test('needs a name', () => rejects(
        const Registration(name: ' ', email: 'a@b.in', phone: '9876543210', level: 'Graduate', experience: '', course: 'x'),
        'Please enter your name.',
      ));

  test('needs a valid Indian mobile', () => rejects(
        const Registration(name: 'A', email: 'a@b.in', phone: '12345', level: 'Graduate', experience: '', course: 'x'),
        'Please enter a valid 10-digit Indian mobile number.',
      ));

  test('needs a class / course level', () => rejects(
        const Registration(name: 'A', email: 'a@b.in', phone: '9876543210', level: '', experience: '', course: 'x'),
        'Please choose your class / course.',
      ));

  test('isPaid covers full and part payments', () {
    expect(const Registration(name: '', email: '', phone: '', level: '', experience: '', course: '', payStatus: 'part').isPaid, isTrue);
    expect(valid.isPaid, isFalse);
  });
}
