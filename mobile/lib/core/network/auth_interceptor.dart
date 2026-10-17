import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';

/// Adds the signed-in user's Firebase ID token to every API request.
/// The jobs server verifies it, so there is one login for the website and the app.
@lazySingleton
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._auth);
  final FirebaseAuth _auth;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await _auth.currentUser?.getIdToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    } catch (_) {
      // No token: the request goes out signed-out and the server answers 401 where needed.
    }
    handler.next(options);
  }
}
