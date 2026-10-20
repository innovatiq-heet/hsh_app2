import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';
import '../../request/staff_users/save_staff_user_request.dart';
import '../../responses/staff_users/staff_user.dart';

/// Admin → Manage Users (platform admin only). Staff created here log in
/// with their phone number alone.
class StaffUsersRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<StaffUserList> list() async {
    try {
      final response = await _dio.get('/admin/users');
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final roles = body is Map ? body['roles'] : null;
      return StaffUserList(
        users: data is List
            ? data
                .whereType<Map>()
                .map((e) => StaffUser.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        roles: roles is List ? roles.map((e) => e.toString()).toList() : const [],
      );
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<StaffUser> create(SaveStaffUserRequest request) async {
    try {
      final response = await _dio.post('/admin/users', data: request.toJson());
      return _user(response.data);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Partial update: send only the fields that changed.
  Future<StaffUser> update(int id, SaveStaffUserRequest request) async {
    try {
      final response = await _dio.put('/admin/users/$id', data: request.toJson());
      return _user(response.data);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/admin/users/$id');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  StaffUser _user(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) throw const ApiException('Unexpected server response');
    return StaffUser.fromJson(Map<String, dynamic>.from(data));
  }
}
