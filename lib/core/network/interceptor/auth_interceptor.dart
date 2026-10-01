import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../constants/app_routes.dart';
import '../../storage/session_store.dart';

/// Attaches the Bearer token to every non-auth request, and handles global
/// 401 session expiry by redirecting to [Routes.login].
///
/// Token is read from [SessionStore]'s synchronous in-memory cache first
/// (zero-overhead hot path), falling back to the async secure-storage read
/// only when the cache is cold (first request after a cold start).
class AuthInterceptor extends Interceptor {
  SessionStore get _session => Get.find<SessionStore>();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;
    final isAuthCall =
        path.contains('/auth/login') || path.contains('/auth/register');

    if (!isAuthCall) {
      final existing = options.headers['Authorization'];
      if (existing == null ||
          (existing is String && existing.trim().isEmpty)) {
        final token =
            _session.currentToken ?? await _session.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // A 401 from the login/register/me call itself just means "wrong
    // credentials" — the caller shows that inline. Force-navigating to
    // /login here would tear down the very screen showing the error.
    final path = err.requestOptions.path;
    final isAuthCall = path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/me');

    if (err.response?.statusCode == 401 && !isAuthCall) {
      if (Get.currentRoute != Routes.login) {
        _session.clear();
        Get.offAllNamed(Routes.login);
      }
    }
    handler.next(err);
  }
}
