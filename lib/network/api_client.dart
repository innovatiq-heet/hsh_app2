import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_config.dart';
import 'interceptor/auth_interceptor.dart';

/// Shared Dio instance for every repository that talks to the real API.
/// Registered once in GlobalBindings, before any repository that reads it.
class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  /// Updates the default Authorization header on the underlying Dio instance.
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
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
        headers: const {
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(AuthInterceptor());
    if (kDebugMode) {
      dio.interceptors.add(_RedactingLogInterceptor());
    }
    return ApiClient._(dio);
  }
}

/// Debug-only request/response logger. Deliberately not `dio`'s own
/// [LogInterceptor] — that would print login/register request bodies
/// verbatim, including the plaintext password field.
class _RedactingLogInterceptor extends Interceptor {
  static const _redactedKeys = {'password'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log('--> ${options.method} ${options.uri}', name: 'HTTP');
    final authHeader = options.headers['Authorization'];
    if (authHeader is String && authHeader.isNotEmpty) {
      final preview = authHeader.length > 25
          ? '${authHeader.substring(0, 15)}...${authHeader.substring(authHeader.length - 6)}'
          : authHeader;
      developer.log('    header: Authorization = $preview', name: 'HTTP');
    } else {
      developer.log('    header: Authorization = [NONE]', name: 'HTTP');
    }
    final data = options.data;
    if (data is Map) {
      developer.log('    body: ${_redact(data)}', name: 'HTTP');
    } else if (data is FormData) {
      final fields = data.fields.map((f) => '${f.key}: "${f.value}"').join(', ');
      final files = data.files.map((f) => '${f.key}: "${f.value.filename}"').join(', ');
      developer.log('    form fields: {$fields}', name: 'HTTP');
      if (files.isNotEmpty) {
        developer.log('    form files: [$files]', name: 'HTTP');
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
      developer.log('    response body: ${err.response?.data}', name: 'HTTP');
      debugPrint('[HTTP ERROR RESPONSE] Status: ${err.response?.statusCode}, Body: ${err.response?.data}');
    }
    handler.next(err);
  }

  Map<String, dynamic> _redact(Map data) {
    return data.map(
      (key, value) => MapEntry(
        key.toString(),
        _redactedKeys.contains(key.toString().toLowerCase()) ? '••••••' : value,
      ),
    );
  }
}
