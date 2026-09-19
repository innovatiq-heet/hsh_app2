import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../constants/app_routes.dart';
import '../../storage/session_store.dart';

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
    // A 401 from the login/register call itself just means "wrong
    // credentials" — the caller (LoginController/RegisterController) shows
    // that inline. Force-navigating to /login here would tear down the very
    // screen that's about to display the error.
    final path = err.requestOptions.path;
    final isAuthCall =
        path.contains('/auth/login') || path.contains('/auth/register');
    if (err.response?.statusCode == 401 && !isAuthCall) {
      SessionStore.instance.clear();
      Get.offAllNamed(Routes.login);
    }
    handler.next(err);
  }
}
