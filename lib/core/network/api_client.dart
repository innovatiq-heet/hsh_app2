import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_config.dart';
import 'interceptor/auth_interceptor.dart';

/// Shared [Dio] instance for every repository that talks to the backend API.
///
/// Registered once in [GlobalBindings] and injected via `Get.find<ApiClient>()`.
/// Repositories should access `Get.find<ApiClient>().dio` rather than
/// constructing their own [Dio] instances.
class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  /// Updates the `Authorization` header on the underlying [Dio] instance.
  /// Called immediately after a successful login/auto-login.
  void setAuthToken(String? token) {
    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      dio.options.headers.remove('Authorization');
    }
  }

  factory ApiClient.create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        // Render's free tier can take ~50s to wake from idle.
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
        headers: const {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(AuthInterceptor());
    if (kDebugMode) {
      dio.interceptors.add(_RedactingLogInterceptor());
    }
    return ApiClient._(dio);
  }
}

/// Debug-only request/response logger.
///
/// Uses [developer.log] instead of `print` so messages appear in the
/// structured DevTools log view. Deliberately **not** using Dio's own
/// [LogInterceptor] — that logs request bodies verbatim, including plaintext
/// passwords on login/register calls.
class _RedactingLogInterceptor extends Interceptor {
  static const _redactedFields = {'password'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log('--> ${options.method} ${options.uri}', name: 'HTTP');
    final auth = options.headers['Authorization'];
    if (auth is String && auth.isNotEmpty) {
      final preview = auth.length > 25
          ? '${auth.substring(0, 15)}...${auth.substring(auth.length - 6)}'
          : auth;
      developer.log('    Authorization: $preview', name: 'HTTP');
    } else {
      developer.log('    Authorization: [NONE]', name: 'HTTP');
    }
    final data = options.data;
    if (data is Map) {
      developer.log('    body: ${_redact(data)}', name: 'HTTP');
    } else if (data is FormData) {
      final fields =
          data.fields.map((f) => '${f.key}: "${f.value}"').join(', ');
      final files =
          data.files.map((f) => '${f.key}: "${f.value.filename}"').join(', ');
      developer.log('    form-fields: {$fields}', name: 'HTTP');
      if (files.isNotEmpty) {
        developer.log('    form-files:  [$files]', name: 'HTTP');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    developer.log(
      '<-- ${response.statusCode} ${response.requestOptions.uri}',
      name: 'HTTP',
    );
    developer.log('    body: ${response.data}', name: 'HTTP');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '<-- ERROR ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}',
      name: 'HTTP',
    );
    if (err.response?.data != null) {
      developer.log('    error body: ${err.response?.data}', name: 'HTTP');
    }
    handler.next(err);
  }

  Map<String, dynamic> _redact(Map data) {
    return data.map(
      (key, value) => MapEntry(
        key.toString(),
        _redactedFields.contains(key.toString().toLowerCase()) ? '••••••' : value,
      ),
    );
  }
}
