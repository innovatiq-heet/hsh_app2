import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../responses/screentime/students_page.dart';
import '../../../../features/screentime/models/screen_time_alert.dart';
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

  /// One page of the student directory, optionally narrowed by [search] and
  /// to one hostel [group] (the server then counts that group only).
  Future<StudentsPage> students({
    required int limit,
    required int offset,
    String? search,
    String? group,
  }) => _guard(() async {
    final response = await _dio.get(
      '/screen-time/students',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (search != null && search.isNotEmpty) 'search': search,
        if (group != null && group.isNotEmpty) 'group': group,
      },
    );
    return StudentsPage.parse(response.data);
  });

  // ---------------------------------------------------------------- alerts

  /// Removal-protection alerts, newest first (HAMS_WEB `GET /screen-time/alerts`).
  /// The server limits a leader to their own group; [group] is sent too, as on
  /// every other leader request. Throws [ApiException] with status 404 while
  /// the backend doesn't have the endpoint yet.
  Future<List<ScreenTimeAlert>> alerts({
    bool unreadOnly = false,
    String? group,
    int limit = 50,
    int offset = 0,
  }) => _guard(() async {
    final response = await _dio.get(
      '/screen-time/alerts',
      queryParameters: {
        'status': unreadOnly ? 'unread' : 'all',
        'limit': limit,
        'offset': offset,
        if (group != null && group.isNotEmpty) 'group': group,
      },
    );
    return ScreenTimeAlert.parseList(response.data);
  });

  /// Marks one alert read.
  Future<void> markAlertRead(int alertId) =>
      _guard(() async => _dio.post('/screen-time/alerts/$alertId/read'));

  // ------------------------------------------------------- one student: read

  /// Today's live status, apps, policy and optional 30-day history.
  Future<dynamic> live(String studentId, {bool includeHistory = false}) =>
      _guard(
        () async => (await _dio.get(
          '/screen-time/live/$studentId',
          queryParameters: includeHistory ? {'include_history': 1} : null,
        )).data,
      );

  /// Day-by-day history; with [date] (`yyyy-MM-dd`) the usage of that day.
  Future<dynamic> history(String studentId, {String? date}) => _guard(() async {
    final response = await _dio.get(
      '/screen-time/history/$studentId',
      queryParameters: date == null ? null : {'date': date},
    );
    return response.data;
  });

  /// The student's policy (lock, daily limit, bedtime) with its apps.
  Future<dynamic> policy(String studentId) => _guard(
    () async => (await _dio.get('/screen-time/policies/$studentId')).data,
  );

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
  }) => _guard(
    () => _dio.post(
      '/screen-time/apps/rule',
      data: {
        'student_id': studentId,
        'package_name': packageName,
        'app_name': appName,
        'is_blocked': isBlocked,
        'daily_limit_minutes': ?dailyLimitMinutes,
      },
    ),
  );

  /// Batch update multiple app rules in a single atomic transaction.
  Future<Response<dynamic>> setAppBatchRules({
    required String studentId,
    required List<Map<String, dynamic>> rules,
  }) => _guard(
    () => _dio.post(
      '/screen-time/apps/batch-rules',
      data: {'student_id': studentId, 'rules': rules},
    ),
  );

  // ---------------------------------------------------------- app requests

  /// Pending app requests, for one student or (without [studentId]) all.
  Future<List<Map<String, dynamic>>> pendingAppRequests({String? studentId}) =>
      _guard(() async {
        final response = await _dio.get(
          '/screen-time/apps/requests',
          queryParameters: {
            'status': 'pending',
            if (studentId != null && studentId.isNotEmpty)
              'student_id': studentId,
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
  Future<void> reviewAppRequest(
    int requestId,
    String action, {
    required int durationMinutes,
  }) => _guard(() async {
    try {
      await _dio.post(
        '/screen-time/apps/request/$requestId/review',
        data: {'action': action, 'duration_minutes': durationMinutes},
      );
    } on DioException catch (e) {
      // If the backend router mounted under plural `/requests/:id/review` instead of singular,
      // try the alternate path before failing.
      if (e.response?.statusCode == 404) {
        await _dio.post(
          '/screen-time/apps/requests/$requestId/review',
          data: {'action': action, 'duration_minutes': durationMinutes},
        );
        return;
      }
      rethrow;
    }
  });

  /// A student asks their warden for an app.
  Future<void> submitAppRequest({
    required String appName,
    required String packageName,
    required String reason,
  }) => _guard(
    () => _dio.post(
      '/screen-time/apps/request',
      data: {
        'app_name': appName.trim(),
        'package_name': packageName.trim(),
        'reason': reason.trim(),
      },
    ),
  );

  // -------------------------------------------------------- removal codes

  /// Warden/admin: issues a one-time 6-digit code letting [studentId] turn
  /// off removal protection (device admin) on their own phone — the
  /// "break glass" path for a legitimate uninstall/handover, without the
  /// student needing a warden physically present at the phone. Returns the
  /// `code` and its `expiresAt` (server clock). Needs `hsh_api` support:
  /// `POST /screen-time/removal-codes` — see docs/PARENT_CONTROL_DOCS.md §5.7.
  Future<Map<String, dynamic>> generateRemovalCode(String studentId) =>
      _guard(() async {
        final response = await _dio.post(
          '/screen-time/removal-codes',
          data: {'student_id': studentId},
        );
        final body = response.data;
        return body is Map
            ? Map<String, dynamic>.from(
                body['data'] is Map ? body['data'] as Map : body,
              )
            : const {};
      });

  /// Student-side: checks a warden-issued code against the signed-in
  /// student's own account. True only on a confirmed match — any error
  /// (network, non-2xx, unexpected body) is treated as false, never as a
  /// pass. Same endpoint `BlockedAppActivity`'s native code field calls on
  /// the device-admin screen (`RemovalCodeVerifier.kt`); this is the Dart
  /// copy used when resuming the app after a different required permission
  /// (usage access, app rules, location) was turned off.
  Future<bool> verifyRemovalCode(String code) async {
    try {
      final response = await _dio.post(
        '/screen-time/removal-codes/verify',
        data: {'code': code},
      );
      final body = response.data;
      return body is Map && body['valid'] == true;
    } on DioException {
      return false;
    }
  }
}
