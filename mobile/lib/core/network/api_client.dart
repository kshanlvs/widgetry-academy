import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:widgetry_academy/core/error/exceptions.dart';

/// Thin wrapper over Dio for the Widgetry Jobs API.
/// Turns every transport or server problem into [NetworkException] or [ServerException]
/// with the server's own friendly message, so data sources stay simple.
@lazySingleton
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: _clean(query)));

  /// [timeout] overrides the usual wait for slow calls (e.g. the AI tutor, which thinks before it answers).
  Future<Map<String, dynamic>> post(String path, {Object? body, Duration? timeout}) =>
      _send(() => _dio.post<Object?>(path, data: body, options: timeout == null ? null : Options(receiveTimeout: timeout)));

  Future<Map<String, dynamic>> put(String path, {Object? body}) => _send(() => _dio.put<Object?>(path, data: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) => _send(() => _dio.patch<Object?>(path, data: body));

  Future<Map<String, dynamic>> delete(String path, {Object? body}) => _send(() => _dio.delete<Object?>(path, data: body));

  /// Fetches any JSON URL (used for the blog feed on the website).
  Future<Map<String, dynamic>> getUrl(String url) => _send(() => _dio.getUri<Object?>(Uri.parse(url)));

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      out[k] = v;
    });
    return out;
  }

  Future<Map<String, dynamic>> _send(Future<Response<Object?>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data == null || data == '') return <String, dynamic>{};
      throw const ServerException('Unexpected response from the server.');
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Exception _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final data = e.response?.data;
        final msg = data is Map && data['error'] is String ? data['error'] as String : _fallback(code);
        return ServerException(msg, statusCode: code);
      case DioExceptionType.cancel:
        return const ServerException('Request cancelled.');
      case DioExceptionType.badCertificate:
        return const ServerException('Secure connection failed. Please try again later.');
      case DioExceptionType.unknown:
        return e.error is SocketException ? const NetworkException() : ServerException(_fallback(null));
    }
  }

  String _fallback(int? code) => switch (code) {
        401 => 'Please sign in again.',
        403 => "You don't have access to this.",
        404 => 'Not found.',
        429 => 'Too many requests. Please wait a moment and try again.',
        _ => 'Something went wrong. Please try again.',
      };
}
