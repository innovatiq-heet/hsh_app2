import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../../models/anniversary/anniversary_models.dart';
import '../../../models/birthday/birthday_models.dart';
import '../../api_client.dart';
import '../base_repository.dart';

class AnniversaryRepository extends BaseRepository {
  ApiClient get _apiClient => Get.find<ApiClient>();

  /// Fetch full dashboard state: config, today's & tomorrow's celebrants, logs, connection state
  Future<AnniversaryDashboardData> fetchDashboard({String? group}) async {
    final response = await _apiClient.dio.get(
      '/whatsapp/anniversary',
      queryParameters: {
        if (group != null && group.trim().isNotEmpty) 'group': group.trim(),
      },
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return AnniversaryDashboardData.fromJson(Map<String, dynamic>.from(data['data']));
    }
    throw Exception('Failed to load anniversary dashboard data');
  }

  /// Save automation configuration and message template.
  Future<AnniversaryConfigModel> saveConfig(AnniversaryConfigModel config) async {
    final Response response;
    try {
      response = await _apiClient.dio.post(
        '/whatsapp/anniversary/config',
        data: config.toJson(),
      );
    } on DioException catch (e) {
      throw Exception(errorMessage(e, fallback: 'Could not save the anniversary settings. Please try again.'));
    }
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return AnniversaryConfigModel.fromJson(Map<String, dynamic>.from(data['data']));
    }
    return config;
  }

  /// History of anniversary wishes sent.
  Future<List<BirthdayLogModel>> fetchLogs({required String from, String? to, String? group}) async {
    final Response response;
    try {
      response = await _apiClient.dio.get(
        '/whatsapp/anniversary/logs',
        queryParameters: {
          'from': from,
          'to': to ?? from,
          if (group != null && group.trim().isNotEmpty) 'group': group.trim(),
        },
      );
    } on DioException catch (e) {
      throw Exception(errorMessage(e, fallback: 'Could not load anniversary logs.'));
    }
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => BirthdayLogModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Manually trigger anniversary wishes or send a test wish.
  ///
  /// [accountId] picks the WhatsApp number to send from; without it the server
  /// uses the default anniversary number.
  Future<Map<String, dynamic>> triggerWishes({bool force = false, String? testPhone, String? accountId}) async {
    final response = await _apiClient.dio.post(
      '/whatsapp/anniversary/trigger',
      data: {
        if (force) 'force': true,
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

  /// Send manual anniversary wish to a single student's parents (father, mother, or both).
  Future<Map<String, dynamic>> sendSingleWish({
    required int studentId,
    required String target,
    String? customPhone,
    String? customMessage,
    String? accountId,
  }) async {
    final Response response;
    try {
      response = await _apiClient.dio.post(
        '/whatsapp/anniversary/send-single',
        data: {
          'studentId': studentId,
          'target': target,
          if (customPhone != null && customPhone.trim().isNotEmpty) 'customPhone': customPhone.trim(),
          if (customMessage != null && customMessage.trim().isNotEmpty) 'customMessage': customMessage.trim(),
          if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
        },
      );
    } on DioException catch (e) {
      throw Exception(errorMessage(e, fallback: 'Failed to send anniversary wish'));
    }
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {'success': true};
  }

  /// Fetch all students directory with parents' marriage anniversary records.
  Future<List<AnniversaryStudentRecord>> fetchAllStudents({String? search, String? group}) async {
    final response = await _apiClient.dio.get(
      '/whatsapp/anniversary/all-students',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (group != null && group.trim().isNotEmpty) 'group': group.trim(),
      },
    );
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => AnniversaryStudentRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Get WhatsApp status (status, qr, isRegistered, user).
  Future<Map<String, dynamic>> getWhatsAppStatus() async {
    final response = await _apiClient.dio.get('/whatsapp/status');
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {'status': 'disconnected'};
  }
}
