import 'package:get/get.dart';
import '../../../models/birthday/birthday_models.dart';
import '../../api_client.dart';

class BirthdayRepository {
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
}
