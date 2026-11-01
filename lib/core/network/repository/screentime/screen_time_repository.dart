import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../responses/screentime/students_page.dart';
import '../base_repository.dart';

/// Every `/screen-time/*` call the app makes, in one place.
///
/// Warden writes are targeted, per the project rules: one app per
/// `POST /screen-time/apps/rule`, and `PUT /screen-time/policies/:id` carries
/// only the fields being changed. A student is always identified by the numeric
/// `students.id` (`studentId` below), never a bank code.
///
/// Methods throw [ApiException] on failure. The live / history / policy
/// readers hand back the response body as is: turning those into models is a
/// later step, and the screens still read them the way they always did.
class ScreenTimeRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // ------------------------------------------------------------- directory

  /// One page of the student directory, optionally narrowed by [search].
  Future<StudentsPage> students({
    required int limit,
    required int offset,
    String? search,
  }) =>
      _guard(() async {
        final response = await _dio.get(
          '/screen-time/students',
          queryParameters: {
            'limit': limit,
            'offset': offset,
            if (search != null && search.isNotEmpty) 'search': search,
          },
        );
        return StudentsPage.parse(response.data);
      });

  // ------------------------------------------------------- one student: read

  /// Today's live status, apps and usage.
  Future<dynamic> live(String studentId) =>
      _guard(() async => (await _dio.get('/screen-time/live/$studentId')).data);

  /// Day-by-day history; with [date] (`yyyy-MM-dd`) the usage of that day.
  Future<dynamic> history(String studentId, {String? date}) => _guard(() async {
        final response = await _dio.get(
          '/screen-time/history/$studentId',
          queryParameters: date == null ? null : {'date': date},
        );
        return response.data;
      });

  /// The student's policy (lock, daily limit, bedtime) with its apps.
  Future<dynamic> policy(String studentId) =>
      _guard(() async => (await _dio.get('/screen-time/policies/$studentId')).data);

  // ------------------------------------------------------ one student: write

  /// Partial update: send only the fields being changed.
  Future<void> updatePolicy(String studentId, Map<String, dynamic> fields) =>
      _guard(() => _dio.put('/screen-time/policies/$studentId', data: fields));

  /// Block / allow one app, optionally setting its daily limit. The rest of
  /// the student's rules are untouched.
  Future<void> setAppRule({
    required String studentId,
    required String packageName,
    required String appName,
    required bool isBlocked,
    int? dailyLimitMinutes,
  }) =>
      _guard(() => _dio.post('/screen-time/apps/rule', data: {
            'student_id': studentId,
            'package_name': packageName,
            'app_name': appName,
            'is_blocked': isBlocked,
            'daily_limit_minutes': ?dailyLimitMinutes,
          }));

  // ---------------------------------------------------------- app requests

  /// Pending app requests, for one student or (without [studentId]) all.
  Future<List<Map<String, dynamic>>> pendingAppRequests({String? studentId}) =>
      _guard(() async {
        final response = await _dio.get(
          '/screen-time/apps/requests',
          queryParameters: {
            'status': 'pending',
            if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
          },
        );
        final body = response.data;
        if (body is Map && body['data'] is List) {
          return (body['data'] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
        return <Map<String, dynamic>>[];
      });

  /// Approve or reject a request (warden). [action] is `approve` / `reject`.
  Future<void> reviewAppRequest(int requestId, String action, {required int durationMinutes}) =>
      _guard(() => _dio.post(
            '/screen-time/apps/request/$requestId/review',
            data: {'action': action, 'duration_minutes': durationMinutes},
          ));

  /// A student asks their warden for an app.
  Future<void> submitAppRequest({
    required String appName,
    required String packageName,
    required String reason,
  }) =>
      _guard(() => _dio.post('/screen-time/apps/request', data: {
            'app_name': appName.trim(),
            'package_name': packageName.trim(),
            'reason': reason.trim(),
          }));
}
