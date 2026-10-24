import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../../models/birthday/birthday_models.dart';
import '../../api_client.dart';
import '../base_repository.dart';

class BirthdayRepository extends BaseRepository {
  ApiClient get _apiClient => Get.find<ApiClient>();

  /// Fetch full dashboard state: config, today's & tomorrow's celebrants, logs, connection state
  Future<BirthdayDashboardData> fetchDashboard() async {
    final response = await _apiClient.dio.get('/whatsapp/birthday');
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return BirthdayDashboardData.fromJson(Map<String, dynamic>.from(data['data']));
    }
    throw Exception('Failed to load birthday dashboard data');
  }

  /// Save automation configuration and message template
  Future<BirthdayConfigModel> saveConfig(BirthdayConfigModel config) async {
    final response = await _apiClient.dio.post(
      '/whatsapp/birthday/config',
      data: config.toJson(),
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return BirthdayConfigModel.fromJson(Map<String, dynamic>.from(data['data']));
    }
    return config;
  }

  /// Manually trigger birthday wishes or send a test wish
  Future<Map<String, dynamic>> triggerWishes({String? testPhone}) async {
    final response = await _apiClient.dio.post(
      '/whatsapp/birthday/trigger',
      data: {
        if (testPhone != null && testPhone.trim().isNotEmpty)
          'testPhone': testPhone.trim(),
      },
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {'success': true};
  }

  /// Fetch all students directory (including room N/A)
  Future<List<BirthdayStudentModel>> fetchAllStudents({String? search}) async {
    final response = await _apiClient.dio.get(
      '/whatsapp/birthday/all-students',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
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

  /// Disconnect current WhatsApp session
  Future<void> disconnectWhatsApp() async {
    await _apiClient.dio.post('/whatsapp/disconnect');
  }

  /// Trigger WhatsApp reconnection
  Future<void> connectWhatsApp() async {
    await _apiClient.dio.post('/whatsapp/connect');
  }
}
