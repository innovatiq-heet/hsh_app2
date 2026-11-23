/// Client for the curfew-session and dashboard endpoints
/// (`/screen-time/sessions…`, `/overview`, `/attention`, `/students/:id/summary`).
///
/// Goes through the app's [ApiClient] Dio (base URL and bearer token come
/// from there). Every call throws [ScreenTimeApiException] with the server's
/// `message` on a non-2xx answer. Students are numeric `students.id` only.
library;

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'models.dart';

class ScreenTimeApiException extends ApiException {
  ScreenTimeApiException(int statusCode, super.message, [this.data]) : super(statusCode: statusCode);

  /// e.g. `{ "invalid_student_ids": [12, 40] }` on a refused bulk add.
  final Map<String, dynamic>? data;
}

class ScreenTimeApi {
  ScreenTimeApi({Dio? dio}) : _dioOverride = dio;

  final Dio? _dioOverride;
  Dio get _dio => _dioOverride ?? Get.find<ApiClient>().dio;

  Future<Map<String, dynamic>> _send(String method, String path, {Map<String, dynamic>? query, Object? body}) async {
    final q = <String, dynamic>{
      for (final e in (query ?? const <String, dynamic>{}).entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    try {
      final res = await _dio.request<dynamic>(
        '/screen-time$path',
        data: body,
        queryParameters: q.isEmpty ? null : q,
        options: Options(method: method),
      );
      final json = res.data is Map ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
      if (json['success'] == false) {
        throw ScreenTimeApiException(res.statusCode ?? 0, '${json['message'] ?? 'Request failed'}', _mapOf(json['data']));
      }
      return json;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final raw = e.response?.data;
      final json = raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};
      final message = json['message'] is String && code < 500
          ? json['message'] as String
          : code >= 500
              ? 'Something went wrong, try again'
              : code == 0
                  ? 'No connection. Check the internet and try again.'
                  : 'Request failed ($code)';
      throw ScreenTimeApiException(code, message, _mapOf(json['data']));
    }
  }

  static Map<String, dynamic>? _mapOf(dynamic v) => v is Map ? v.cast<String, dynamic>() : null;

  Map<String, dynamic> _data(Map<String, dynamic> json) => (json['data'] as Map).cast<String, dynamic>();

  // ---------------- sessions (warden / admin) ----------------

  Future<List<CurfewSession>> listSessions() async {
    final json = await _send('GET', '/sessions');
    return (json['data'] as List).cast<Map>().map((e) => CurfewSession.fromJson(e.cast())).toList();
  }

  /// Creates a session; pass [students] to assign in the same step.
  Future<CurfewSession> createSession(SessionDraft draft, {StudentSelection? students}) async {
    final json = await _send('POST', '/sessions', body: {...draft.toJson(), ...?students?.toJson()});
    return CurfewSession.fromJson(_data(json));
  }

  /// Partial edit (only the fields set on [draft]).
  Future<CurfewSession> updateSession(int id, SessionDraft draft) async =>
      CurfewSession.fromJson(_data(await _send('PATCH', '/sessions/$id', body: draft.toJson())));

  /// Switch the whole session on or off for every assigned student.
  Future<CurfewSession> setSessionActive(int id, bool isActive) => updateSession(id, SessionDraft(isActive: isActive));

  Future<void> deleteSession(int id) => _send('DELETE', '/sessions/$id');

  Future<SessionDetail> getSession(int id, {String? search, int limit = 100, int offset = 0}) async =>
      SessionDetail.fromJson(_data(await _send('GET', '/sessions/$id', query: {'search': search, 'limit': limit, 'offset': offset})));

  /// Who [students] covers. [sessionId] null = before creating a session.
  Future<SelectionPreview> previewStudents(StudentSelection students, {int? sessionId}) async {
    final path = sessionId == null ? '/sessions/preview' : '/sessions/$sessionId/students/preview';
    return SelectionPreview.fromJson(_data(await _send('POST', path, body: students.toJson())));
  }

  /// Returns how many were added (students already in are skipped).
  Future<int> addStudents(int sessionId, StudentSelection students) async =>
      (_data(await _send('POST', '/sessions/$sessionId/students', body: students.toJson()))['added_count'] as num).toInt();

  Future<int> removeStudents(int sessionId, StudentSelection students) async =>
      (_data(await _send('DELETE', '/sessions/$sessionId/students', body: students.toJson()))['removed_count'] as num).toInt();

  /// Pause / resume the session for one student only.
  Future<void> setStudentPaused(int sessionId, int studentId, bool isPaused) =>
      _send('PATCH', '/sessions/$sessionId/students/$studentId', body: {'is_paused': isPaused});

  Future<SessionLive> sessionLive(int sessionId) async => SessionLive.fromJson(_data(await _send('GET', '/sessions/$sessionId/live')));

  /// [sessionId] null = every session's history.
  Future<List<SessionLogEntry>> sessionHistory({int? sessionId, int limit = 50, int offset = 0}) async {
    final path = sessionId == null ? '/sessions/history' : '/sessions/$sessionId/history';
    final json = await _send('GET', path, query: {'limit': limit, 'offset': offset});
    return (json['data'] as List).cast<Map>().map((e) => SessionLogEntry.fromJson(e.cast())).toList();
  }

  // ---------------- dashboard (supervisors; leaders see their group) ----------------

  Future<ScreenTimeOverview> overview({int? floor, String? group}) async =>
      ScreenTimeOverview(_data(await _send('GET', '/overview', query: {'floor': floor, 'group': group})));

  /// [type]: protection_removed, offline, session_use, over_limit, block_attempts.
  Future<AttentionPage> attention({int? floor, String? group, String? type, int limit = 50, int offset = 0}) async =>
      AttentionPage.fromJson(await _send('GET', '/attention',
          query: {'floor': floor, 'group': group, 'type': type, 'limit': limit, 'offset': offset}));

  /// [range]: 7d, 14d or 30d.
  Future<StudentSummary> studentSummary(int studentId, {String range = '7d'}) async =>
      StudentSummary(_data(await _send('GET', '/students/$studentId/summary', query: {'range': range})));

  Future<List<CurfewSession>> studentSessions(int studentId) async {
    final data = _data(await _send('GET', '/students/$studentId/sessions'));
    return (data['sessions'] as List).cast<Map>().map((e) => CurfewSession.fromJson(e.cast())).toList();
  }

  /// The existing student list with the new quick filters and sort.
  /// [filter]: online, quiet, offline, in_curfew_now, using_in_session,
  /// over_limit, protection_removed, locked, no_session.
  /// [sort]: total, session_use, block_attempts, name, room.
  Future<Map<String, dynamic>> students({
    String? search,
    int? floor,
    String? group,
    String? filter,
    int? sessionId,
    String? sort,
    int limit = 500,
    int offset = 0,
  }) async =>
      _data(await _send('GET', '/students', query: {
        'search': search,
        'floor': floor,
        'group': group,
        'filter': filter,
        'session_id': sessionId,
        'sort': sort,
        'limit': limit,
        'offset': offset,
      }));
}
