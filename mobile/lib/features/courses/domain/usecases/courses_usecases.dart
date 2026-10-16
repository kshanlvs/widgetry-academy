import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/core/usecase/usecase.dart';
import 'package:widgetry_academy/core/utils/validators.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/domain/repositories/courses_repository.dart';

@injectable
class GetCourses implements UseCase<List<Course>, NoParams> {
  const GetCourses(this._repo);
  final CoursesRepository _repo;
  @override
  Future<Result<List<Course>>> call(NoParams p) => _repo.courses();
}

@injectable
class GetNextBatch implements UseCase<BatchInfo, NoParams> {
  const GetNextBatch(this._repo);
  final CoursesRepository _repo;
  @override
  Future<Result<BatchInfo>> call(NoParams p) => _repo.nextBatch();
}

@injectable
class GetMyRegistration implements UseCase<Registration?, NoParams> {
  const GetMyRegistration(this._repo);
  final CoursesRepository _repo;
  @override
  Future<Result<Registration?>> call(NoParams p) => _repo.myRegistration();
}

/// Validates like the website, then saves in the format the Firestore rules accept.
@injectable
class RegisterForCourse implements UseCase<Registration, Registration> {
  const RegisterForCourse(this._repo);
  final CoursesRepository _repo;
  @override
  Future<Result<Registration>> call(Registration r) async {
    if (r.name.trim().isEmpty) return const Err(ValidationFailure('Please enter your name.'));
    if (Validators.indianMobile(r.phone) != null) return const Err(ValidationFailure('Please enter a valid 10-digit Indian mobile number.'));
    if (r.level.isEmpty) return const Err(ValidationFailure('Please choose your class / course.'));
    return _repo.register(r);
  }
}
