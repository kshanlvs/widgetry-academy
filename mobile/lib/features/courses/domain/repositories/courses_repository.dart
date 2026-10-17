import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';

abstract interface class CoursesRepository {
  Future<Result<List<Course>>> courses();
  Future<Result<BatchInfo>> nextBatch();
  /// The signed-in user's registration, or null.
  Future<Result<Registration?>> myRegistration();
  Future<Result<Registration>> register(Registration r);
}
