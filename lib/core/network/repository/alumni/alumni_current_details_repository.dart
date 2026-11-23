import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../../models/alumni/alumni_current_details.dart';
import '../../api_client.dart';
import '../base_repository.dart';

/// An alumnus's current city, company, role and address, read and written by
/// admins. [studentId] is always the numeric `students.id`.
class AlumniCurrentDetailsRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  String _path(int studentId) => '/alumni/admin/students/$studentId/current-details';

  AlumniCurrentDetails _parse(Response response) {
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    return data is Map ? AlumniCurrentDetails.fromJson(Map<String, dynamic>.from(data)) : AlumniCurrentDetails.empty;
  }

  Future<AlumniCurrentDetails> fetch(int studentId) async {
    try {
      return _parse(await _dio.get(_path(studentId)));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Saves only [changes] (see [AlumniCurrentDetails.changes]).
  Future<AlumniCurrentDetails> save(int studentId, Map<String, String> changes) async {
    try {
      return _parse(await _dio.put(_path(studentId), data: changes));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
