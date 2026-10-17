import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/guard.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/courses/data/datasources/courses_firestore_data_source.dart';
import 'package:widgetry_academy/features/courses/domain/entities/course.dart';
import 'package:widgetry_academy/features/courses/domain/repositories/courses_repository.dart';

@LazySingleton(as: CoursesRepository)
class CoursesRepositoryImpl implements CoursesRepository {
  CoursesRepositoryImpl(this._ds);
  final CoursesDataSource _ds;

  @override
  Future<Result<List<Course>>> courses() => guard(_ds.courses);

  @override
  Future<Result<BatchInfo>> nextBatch() => guard(_ds.batch);

  @override
  Future<Result<Registration?>> myRegistration() => guard(_ds.myRegistration);

  @override
  Future<Result<Registration>> register(Registration r) => guard(() => _ds.register(r));
}
