import 'dart:convert';
import 'package:dio/dio.dart';
import '../api_exception.dart';

/// Base class for all repositories.
///
/// Provides a single, consistent [errorMessage] helper so every repository
/// parses the backend's `{status, message}` envelope the same way, without
/// duplicating the extraction logic in each subclass.
abstract class BaseRepository {
  /// Extracts a human-readable error string from a [DioException].
  ///
  /// Priority order:
  /// 1. `response.data['message']` — backend's own error copy.
  /// 2. `response.data['error']`   — secondary backend key.
  /// 3. Friendly timeout/connection copy.
  /// 4. Raw [DioException.message].
  String errorMessage(DioException e, {String fallback = 'Something went wrong. Please try again.'}) {
    dynamic data = e.response?.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      final err = data['error'];
      if (err is String && err.isNotEmpty) return err;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Connection timed out. Please check your internet and try again.';
    }
    if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
      return fallback;
    }
    return e.message ?? fallback;
  }

  /// Wraps [e] as an [ApiException] carrying the backend's message, except
  /// 5xx, whose body ("Server error") is not useful to show.
  ApiException toApiException(DioException e) {
    final code = e.response?.statusCode;
    final message = code != null && code >= 500
        ? 'Something went wrong, try again'
        : errorMessage(e);
    return ApiException(message, statusCode: code);
  }
}
