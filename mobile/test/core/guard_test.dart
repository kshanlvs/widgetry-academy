import 'package:flutter_test/flutter_test.dart';
import 'package:widgetry_academy/core/error/exceptions.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/error/guard.dart';

void main() {
  test('returns the value on success', () async {
    expect((await guard(() async => 42)).valueOrNull, 42);
  });

  test('maps each exception to a user-readable failure', () async {
    expect((await guard<int>(() async => throw const NetworkException())).failureOrNull, isA<NetworkFailure>());
    final server = (await guard<int>(() async => throw const ServerException('Not found', statusCode: 404))).failureOrNull;
    expect(server, isA<ServerFailure>());
    expect((server! as ServerFailure).isNotFound, isTrue);
    expect((await guard<int>(() async => throw const AuthException('Sign in again'))).failureOrNull, const AuthFailure('Sign in again'));
    expect((await guard<int>(() async => throw const FormatException('bad'))).failureOrNull, isA<UnknownFailure>());
    expect((await guard<int>(() async => throw StateError('x'))).failureOrNull, const UnknownFailure());
  });
}
