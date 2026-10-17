import 'package:widgetry_academy/core/error/exceptions.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';

/// Runs repository work and converts exceptions into [Failure]s in one place (DRY).
Future<Result<T>> guard<T>(Future<T> Function() run) async {
  try {
    return Success(await run());
  } on NetworkException catch (e) {
    return Err(NetworkFailure(e.message));
  } on ServerException catch (e) {
    return Err(ServerFailure(e.message, statusCode: e.statusCode));
  } on AuthException catch (e) {
    return Err(AuthFailure(e.message));
  } on CacheException catch (e) {
    return Err(CacheFailure(e.message));
  } on FormatException {
    return const Err(UnknownFailure('We received data we could not read. Please update the app.'));
  } catch (_) {
    return const Err(UnknownFailure());
  }
}
