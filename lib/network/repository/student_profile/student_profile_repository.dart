import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../common_models/student_profile/student_profile_model.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../request/student_profile/update_profile_request.dart';

class StudentProfileRepository {
  final Dio _dio = Get.find<ApiClient>().dio;

  Future<StudentProfileModel> fetchProfile([String? aadhar]) async {
    try {
      final path = (aadhar != null && aadhar.isNotEmpty) ? '/students/$aadhar' : '/students/me';
      final response = await _dio.get(path);
      final data = response.data;
      Map<String, dynamic> student;
      if (data is Map && data['data'] is Map) {
        student = Map<String, dynamic>.from(data['data']['student'] ?? data['data']);
      } else {
        student = Map<String, dynamic>.from(data);
      }
      return StudentProfileModel.fromJson(student);
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  Future<StudentProfileModel> updateProfile(
    String aadhar,
    UpdateProfileRequest request,
  ) async {
    try {
      final response = await _dio.patch(
        '/students/$aadhar',
        data: request.toJson(),
      );
      final student = response.data['data']['student'] as Map<String, dynamic>;
      return StudentProfileModel.fromJson(student);
    } on DioException catch (e) {
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? 'Something went wrong. Please try again.';
  }
}
