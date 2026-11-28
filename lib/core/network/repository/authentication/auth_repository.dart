import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../../services/device_identity_service.dart';
import '../base_repository.dart';
import '../../request/authentication/login_request.dart';
import '../../responses/authentication/auth_session_response.dart';

class AuthRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<AuthSessionResponse> autoLogin(
    List<String> simNumbers, {
    String? code,
  }) async {
    try {
      final identity = await DeviceIdentityService.instance.getIdentity();
      final response = await _dio.post(
        '/auth/auto-login',
        data: {
          'sim_numbers': simNumbers,
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          ...identity.toJson(),
        },
      );
      return _parseSession(response.data);
    } on DioException catch (e) {
      throw ApiException(
        errorMessage(e),
        statusCode: e.response?.statusCode,
        code: _extractErrorCode(e.response?.data),
      );
    }
  }

  Future<AuthSessionResponse> login(LoginRequest request) async {
    try {
      final payload = request.toJson();
      if (!payload.containsKey('device_uuid')) {
        final identity = await DeviceIdentityService.instance.getIdentity();
        payload.addAll(identity.toJson());
      }
      final response = await _dio.post('/auth/login', data: payload);
      return _parseSession(response.data);
    } on DioException catch (e) {
      throw ApiException(
        errorMessage(e),
        statusCode: e.response?.statusCode,
        code: _extractErrorCode(e.response?.data),
      );
    }
  }

  static String? _extractErrorCode(dynamic body) {
    if (body is Map) {
      final raw = body['code'];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        return raw.toString().trim();
      }
    }
    return null;
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

    // A student/leader's second login onward needs a warden-issued code
    // (docs/PARENT_CONTROL_DOCS.md §5.7a); `statusCode: 428` lets
    // LoginController tell this apart from a plain wrong-credentials error.
    if (parsed is Map && parsed['requires_code'] == true) {
      throw ApiException(
        (parsed['message'] ?? "Enter the code your warden gave you.").toString(),
        statusCode: 428,
      );
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
