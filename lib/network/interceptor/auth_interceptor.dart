import 'package:dio/dio.dart';
import '../../storage/session_store.dart';

/// Wired into the shared Dio instance ahead of real API integration —
/// attaches the bearer token and will redirect to login on 401 once actual
/// network calls replace the mocked repositories.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SessionStore.instance.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      SessionStore.instance.clear();
      // TODO(api): navigate to login once GetX navigation is reachable from here.
    }
    handler.next(err);
  }
}
