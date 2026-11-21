import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../../models/birthday/birthday_models.dart';
import '../../api_client.dart';
import '../base_repository.dart';

/// The parent was already wished today (server 409).
class ParentAlreadyWishedException implements Exception {
  final String message;
  const ParentAlreadyWishedException(this.message);
  @override
  String toString() => message;
}

class BirthdayRepository extends BaseRepository {
  ApiClient get _apiClient => Get.find<ApiClient>();

  /// Fetch full dashboard state: config, today's & tomorrow's celebrants, logs, connection state
  Future<BirthdayDashboardData> fetchDashboard({String? group}) async {
    final response = await _apiClient.dio.get(
      '/whatsapp/birthday',
      queryParameters: {
        if (group != null && group.trim().isNotEmpty) 'group': group.trim(),
      },
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return BirthdayDashboardData.fromJson(Map<String, dynamic>.from(data['data']));
    }
    throw Exception('Failed to load birthday dashboard data');
  }

  /// Save automation configuration and message template. A rejected config
  /// (400) throws with the backend's reason, e.g. a template with no name.
  Future<BirthdayConfigModel> saveConfig(BirthdayConfigModel config) async {
    final Response response;
    try {
      response = await _apiClient.dio.post(
        '/whatsapp/birthday/config',
        data: config.toJson(),
      );
    } on DioException catch (e) {
      throw Exception(errorMessage(e, fallback: 'Could not save the birthday settings. Please try again.'));
    }
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return BirthdayConfigModel.fromJson(Map<String, dynamic>.from(data['data']));
    }
    return config;
  }

  /// Wish logs whose wish date is between [from] and [to] (`yyyy-MM-dd`, inclusive;
  /// [to] defaults to [from]). The dashboard only carries the most recent logs.
  Future<List<BirthdayLogModel>> fetchLogs({required String from, String? to}) async {
    final Response response;
    try {
      response = await _apiClient.dio.get(
        '/whatsapp/birthday/logs',
        queryParameters: {'from': from, 'to': to ?? from},
      );
    } on DioException catch (e) {
      throw Exception(errorMessage(e, fallback: 'Could not load the logs for that day.'));
    }
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => BirthdayLogModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Manually trigger birthday wishes or send a test wish
  ///
  /// [accountId] picks the WhatsApp number to send from; without it the server
  /// uses the default birthday number.
  Future<Map<String, dynamic>> triggerWishes({String? testPhone, String? accountId}) async {
    final response = await _apiClient.dio.post(
      '/whatsapp/birthday/trigger',
      data: {
        if (testPhone != null && testPhone.trim().isNotEmpty)
          'testPhone': testPhone.trim(),
        if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      },
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {'success': true};
  }

  /// Wishes one student's father or mother on their own birthday through the
  /// server bot (`POST /whatsapp/birthday/send-parent-wish`). [studentId] is
  /// the numeric `students.id`. Throws with the server's message; a 409 (already
  /// wished today) throws [ParentAlreadyWishedException].
  Future<void> sendParentWish({
    required String role,
    required int studentId,
    String? accountId,
  }) async {
    try {
      await _apiClient.dio.post(
        '/whatsapp/birthday/send-parent-wish',
        data: {
          'role': role,
          'studentId': studentId,
          if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
        },
      );
    } on DioException catch (e) {
      final message = errorMessage(e, fallback: 'Could not send the birthday wish.');
      if (e.response?.statusCode == 409) throw ParentAlreadyWishedException(message);
      throw Exception(message);
    }
  }

  /// Fetch all students directory (including room N/A)
  Future<List<BirthdayStudentModel>> fetchAllStudents({String? search, String? group}) async {
    final response = await _apiClient.dio.get(
      '/whatsapp/birthday/all-students',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (group != null && group.trim().isNotEmpty) 'group': group.trim(),
      },
    );
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => BirthdayStudentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Get WhatsApp status (status, qr, isRegistered, user)
  Future<Map<String, dynamic>> getWhatsAppStatus() async {
    final response = await _apiClient.dio.get('/whatsapp/status');
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {};
  }

  /// Request 8-character pairing code to link phone. [phone] is digits with
  /// country code ("919876543210"), which is what WhatsApp expects.
  Future<String> requestPairingCode(String phone) async {
    final Response response;
    try {
      response = await _apiClient.dio.post(
        '/whatsapp/pair',
        data: {'phone': phone.trim()},
      );
    } on DioException catch (e) {
      throw Exception(errorMessage(e, fallback: 'Could not get a pairing code. Please try again.'));
    }
    final data = response.data;
    if (data is Map && data['code'] != null) {
      return data['code'].toString();
    }
    throw Exception(data['message'] ?? 'Failed to get pairing code');
  }

  /// Save leader's customized wish template on server
  Future<void> saveLeaderTemplate(String template) async {
    try {
      await _apiClient.dio.post(
        '/whatsapp/birthday/leader-template',
        data: {'template': template.trim()},
      );
    } on DioException catch (e) {
      throw Exception(errorMessage(e, fallback: 'Could not save the leader template. Please try again.'));
    }
  }

  /// Disconnect current WhatsApp session
  Future<void> disconnectWhatsApp() async {
    await _apiClient.dio.post('/whatsapp/disconnect');
  }

  /// Trigger WhatsApp reconnection
  Future<void> connectWhatsApp() async {
    await _apiClient.dio.post('/whatsapp/connect');
  }
}
