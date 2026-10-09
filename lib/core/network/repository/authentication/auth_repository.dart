import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';
import '../../request/authentication/login_request.dart';
import '../../responses/authentication/auth_session_response.dart';

class AuthRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<AuthSessionResponse> autoLogin(List<String> simNumbers) async {
    try {
      final response = await _dio.post(
        '/auth/auto-login',
        data: {'sim_numbers': simNumbers},
      );
      return _parseSession(response.data);
    } on DioException catch (e) {
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  Future<AuthSessionResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post('/auth/login', data: request.toJson());
      return _parseSession(response.data);
    } on DioException catch (e) {
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  /// Registration creates the account but doesn't return a token, so a
  /// successful register immediately logs in with the same credentials to
  /// obtain a real session.
  Future<AuthSessionResponse> register(RegisterRequest request) async {
    try {
      await _dio.post('/auth/register', data: request.toJson());
    } on DioException catch (e) {
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
    return login(LoginRequest(email: request.email, password: request.password));
  }

  /// Returns `null` on any failure (expired/invalid token) rather than
  /// throwing — the splash flow treats "couldn't verify" and "not logged in"
  /// the same way.
  Future<AuthSessionResponse?> checkSession(String token) async {
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final body = response.data;
      final data = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : (body is Map ? body as Map<String, dynamic> : <String, dynamic>{});
      final user = (data['user'] ?? data) as Map<String, dynamic>;
      return AuthSessionResponse.fromJson(user, token: token);
    } on DioException {
      return null;
    }
  }

  AuthSessionResponse _parseSession(dynamic body) {
    dynamic parsed = body;
    if (parsed is String) {
      try {
        parsed = jsonDecode(parsed);
      } catch (_) {}
    }

    if (parsed is Map) {
      final success = parsed['success'];
      final status = parsed['status'];
      if (success == false ||
          status == false ||
          status == 0 ||
          status == 'error' ||
          status == 'fail') {
        final msg = parsed['message'] ?? parsed['error'] ?? 'User not found or invalid credentials.';
        throw ApiException(msg.toString());
      }
    }

    final data = parsed is Map && parsed['data'] is Map
        ? parsed['data'] as Map<String, dynamic>
        : (parsed is Map ? parsed as Map<String, dynamic> : <String, dynamic>{});
    final token = (data['token'] ?? (parsed is Map ? parsed['token'] : null) ?? '').toString();
    final user = (data['user'] ?? (parsed is Map ? parsed['user'] : null) ?? data) as Map<String, dynamic>;

    if (token.isEmpty && (user.isEmpty || user['id'] == null)) {
      final msg = parsed is Map ? (parsed['message'] ?? parsed['error']) : null;
      throw ApiException(msg?.toString() ?? 'User not found or invalid credentials.');
    }

    final isAlumni = (parsed is Map && parsed['is_alumni'] == true) ||
        (data.isNotEmpty && data['is_alumni'] == true) ||
        (user.isNotEmpty && (user['is_alumni'] == true || user['role']?.toString().toLowerCase().trim() == 'alumni'));

    return AuthSessionResponse.fromJson(user, token: token, isAlumni: isAlumni);
  }

  /// Registers the device's FCM push notification token with the backend.
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _dio.post(
        '/auth/fcm-token',
        data: {
          'fcm_token': fcmToken,
          'fcmToken': fcmToken,
          'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
        },
      );
    } on DioException catch (e) {
      throw ApiException(errorMessage(e), statusCode: e.response?.statusCode);
    }
  }
}
