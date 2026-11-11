import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';
import '../../../models/forms/form_models.dart';

/// Forms & Polls (`/forms`). Admin/warden routes need an operator or
/// platform-admin token; student routes a student token.
/// Contract: docs/FORMS_DOCS.md.
class FormsRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  static Map<String, dynamic> _data(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) throw const ApiException('Unexpected server response');
    return Map<String, dynamic>.from(data);
  }

  static List<Map<String, dynamic>> _list(dynamic body) {
    final data = body is Map ? body['data'] : body;
    if (data is! List) return const [];
    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  // --- admin / warden ---

  Future<List<HostelForm>> list() => _guard(() async {
        final res = await _dio.get('/forms');
        return _list(res.data).map(HostelForm.fromJson).toList();
      });

  Future<HostelForm> get(int id) => _guard(() async {
        final res = await _dio.get('/forms/$id');
        return HostelForm.fromJson(_data(res.data));
      });

  /// Creates a form; returns its id (`form_id`).
  Future<int> create(Map<String, dynamic> body) => _guard(() async {
        final res = await _dio.post('/forms', data: body);
        final data = res.data;
        final raw = data is Map ? (data['form_id'] ?? (data['data'] is Map ? data['data']['id'] : null)) : null;
        return int.tryParse(raw?.toString() ?? '') ?? 0;
      });

  /// Partial update: only the keys in [changes] are touched.
  Future<void> update(int id, Map<String, dynamic> changes) => _guard(() async {
        await _dio.put('/forms/$id', data: changes);
      });

  /// Pauses or activates; returns the new `is_active`.
  Future<bool> toggle(int id) => _guard(() async {
        final res = await _dio.post('/forms/$id/toggle');
        final data = res.data;
        final raw = data is Map ? (data['is_active'] ?? (data['data'] is Map ? data['data']['is_active'] : null)) : null;
        return raw == true || raw == 1;
      });

  Future<void> delete(int id) => _guard(() async {
        await _dio.delete('/forms/$id');
      });

  Future<FormAnalytics> analytics(int id) => _guard(() async {
        final res = await _dio.get('/forms/$id/analytics');
        return FormAnalytics.fromJson(_data(res.data));
      });

  // --- student ---

  /// Open forms/polls this student may answer (mandatory first).
  Future<List<StudentForm>> active() => _guard(() async {
        final res = await _dio.get('/forms/student/active');
        return _list(res.data).map(StudentForm.fromJson).toList();
      });

  Future<void> recordView(int id) => _guard(() async {
        await _dio.post('/forms/$id/view');
      });

  Future<void> submit(int id, Map<String, dynamic> answers) => _guard(() async {
        await _dio.post('/forms/$id/submit', data: {'answers': answers});
      });

  /// This student's answers, or null if not submitted yet (404).
  Future<FormResponse?> myResponse(int id) async {
    try {
      final res = await _dio.get('/forms/student/$id/my-response');
      final body = res.data;
      return FormResponse.fromJson(body is Map ? body['data'] : null);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw toApiException(e);
    }
  }
}
