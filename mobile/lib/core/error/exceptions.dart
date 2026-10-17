/// Thrown by data sources. Repositories turn these into [Failure]s, so the UI never sees raw exceptions.
class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'No internet connection. Check your network and try again.']);
  final String message;
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code});
  final String message;
  final String? code;
}

class CacheException implements Exception {
  const CacheException([this.message = 'Could not read saved data.']);
  final String message;
}
