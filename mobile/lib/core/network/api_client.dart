import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  /// POSTs JSON and returns the file the server sends back (resume PDF / Word) with its headers.
  Future<ApiFile> postForFile(String path, {Object? body, Duration timeout = const Duration(seconds: 60)}) async {
    try {
      final res = await _dio.post<List<int>>(path, data: body, options: Options(responseType: ResponseType.bytes, receiveTimeout: timeout));
      return ApiFile(Uint8List.fromList(res.data ?? const []), {for (final e in res.headers.map.entries) e.key.toLowerCase(): e.value.join(',')});
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// Uploads a file as the request body (resume import). [query] adds e.g. {'ai': '1'}.
  Future<Map<String, dynamic>> postFile(String path, Uint8List bytes, {required String contentType, Map<String, dynamic>? query, Duration timeout = const Duration(seconds: 90)}) =>
      _send(() => _dio.post<Object?>(path,
          data: Stream.fromIterable([bytes]),
          queryParameters: _clean(query),
          options: Options(contentType: contentType, headers: {Headers.contentLengthHeader: bytes.length}, receiveTimeout: timeout, sendTimeout: timeout)));

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
        var data = e.response?.data;
        // File downloads get the error as bytes: read the JSON message out of them
        if (data is List<int>) {
          try {
            data = jsonDecode(utf8.decode(data));
          } catch (_) {}
        }
        final msg = data is Map && data['error'] is String ? data['error'] as String : _fallback(code);
        return ServerException(msg, statusCode: code);
      case DioExceptionType.cancel:
        return const ServerException('Request cancelled.');
      case DioExceptionType.badCertificate:
        return const ServerException('Secure connection failed. Please try again later.');
      // unknown, and any type newer dio versions add (5.11 added transformTimeout)
      default:
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

/// A file from the API: its bytes and the response headers (lower-case names).
class ApiFile {
  const ApiFile(this.bytes, this.headers);
  final Uint8List bytes;
  final Map<String, String> headers;

  /// File name from Content-Disposition, if the server sent one.
  String? get fileName => RegExp(r'filename="([^"]+)"').firstMatch(headers['content-disposition'] ?? '')?.group(1);
}
