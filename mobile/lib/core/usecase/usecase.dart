import 'package:equatable/equatable.dart';
import 'package:widgetry_academy/core/result/result.dart';

/// One business action. Each use case does one thing (single responsibility).
abstract interface class UseCase<T, P> {
  Future<Result<T>> call(P params);
}

/// For use cases that return a stream (e.g. auth state).
abstract interface class StreamUseCase<T, P> {
  Stream<T> call(P params);
}

class NoParams extends Equatable {
  const NoParams();
  @override
  List<Object?> get props => const [];
}
