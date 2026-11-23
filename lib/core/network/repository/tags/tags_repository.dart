import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';
import '../../../models/tags/student_tag_model.dart';

class StudentTagsResult {
  final int studentId;
  final StudentTag? systemTag;
  final List<StudentTag> assignedTags;
  final int maxAllowed;

  const StudentTagsResult({
    required this.studentId,
    this.systemTag,
    required this.assignedTags,
    this.maxAllowed = 99,
  });

  List<StudentTag> get allTags => [
    ?systemTag,
    ...assignedTags,
  ];
}

/// What the server says after a tag change (assign, remove, rename, delete).
///
/// The student list (`GET /students`) is cached on the server, so a change can
/// take up to [refreshInSeconds] to show there. [notice] is the server's
/// message for the admin ("Saved. The student list may take up to 18 seconds
/// to show this change."), or null when nothing is cached.
class TagWriteResult {
  final int refreshInSeconds;
  final String? notice;

  const TagWriteResult({this.refreshInSeconds = 0, this.notice});

  static const none = TagWriteResult();

  factory TagWriteResult.fromBody(dynamic body) {
    if (body is! Map) return none;
    final raw = body['refresh_in_seconds'];
    final seconds = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}') ?? 0;
    final notice = body['notice'];
    final text = notice is String && notice.trim().isNotEmpty ? notice.trim() : null;
    return TagWriteResult(refreshInSeconds: seconds < 0 ? 0 : seconds, notice: text);
  }

  /// [message] followed by the server's notice, when there is one.
  String addTo(String message) => notice == null ? message : '$message\n$notice';

  /// The later of two waits (several writes in a row, e.g. a bulk assign).
  TagWriteResult laterOf(TagWriteResult other) =>
      other.refreshInSeconds > refreshInSeconds ? other : this;
}

/// Repository for the student tag subsystem (`/tags`).
class TagsRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  /// The result of the most recent tag change (also for [updateTag], which
  /// returns the tag itself).
  TagWriteResult lastWrite = TagWriteResult.none;

  TagWriteResult _remember(Response response) => lastWrite = TagWriteResult.fromBody(response.data);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Lists all tags with student counts.
  Future<List<StudentTag>> getTags() => _guard(() async {
        final response = await _dio.get('/tags');
        final body = response.data;
        final data = body is Map ? body['data'] : body;
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => StudentTag.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return const [];
      });

  /// Creates a new tag (Admin only).
  Future<StudentTag> createTag({
    required String name,
    String? color,
    String? description,
  }) =>
      _guard(() async {
        final response = await _dio.post('/tags', data: {
          'name': name.trim(),
          if (color != null && color.isNotEmpty) 'color': color.trim(),
          if (description != null && description.isNotEmpty) 'description': description.trim(),
        });
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        if (data is! Map) throw const ApiException('Unexpected server response');
        return StudentTag.fromJson(Map<String, dynamic>.from(data));
      });

  /// Updates / renames an existing tag (Admin only).
  Future<StudentTag> updateTag({
    required int id,
    required String name,
    String? color,
    String? description,
  }) =>
      _guard(() async {
        final response = await _dio.put('/tags/$id', data: {
          'name': name.trim(),
          if (color != null && color.isNotEmpty) 'color': color.trim(),
          if (description != null) 'description': description.trim(),
        });
        _remember(response);
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        if (data is! Map) throw const ApiException('Unexpected server response');
        return StudentTag.fromJson(Map<String, dynamic>.from(data));
      });

  /// Deletes a custom tag (Admin only).
  Future<TagWriteResult> deleteTag(int tagId) => _guard(() async {
        return _remember(await _dio.delete('/tags/$tagId'));
      });

  /// Fetches tags assigned to a student along with dynamic system tag.
  Future<StudentTagsResult> getStudentTags(int studentId) => _guard(() async {
        final response = await _dio.get('/tags/student/$studentId');
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        if (data is! Map) throw const ApiException('Student tags data not found');

        StudentTag? sysTag;
        if (data['system_tag'] is Map) {
          sysTag = StudentTag.fromJson(Map<String, dynamic>.from(data['system_tag']));
        }

        final assigned = <StudentTag>[];
        if (data['assigned_tags'] is List) {
          for (final item in data['assigned_tags']) {
            if (item is Map) {
              assigned.add(StudentTag.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }

        return StudentTagsResult(
          studentId: studentId,
          systemTag: sysTag,
          assignedTags: assigned,
          maxAllowed: int.tryParse(data['max_allowed']?.toString() ?? '99') ?? 99,
        );
      });

  /// Assigns a tag to a student.
  Future<TagWriteResult> assignTag({
    required int studentId,
    required int tagId,
  }) =>
      _guard(() async {
        return _remember(await _dio.post('/tags/student/$studentId', data: {
          'tag_id': tagId,
        }));
      });

  /// Assigns multiple tags to a student in one batch request.
  Future<TagWriteResult> assignTags({
    required int studentId,
    required List<int> tagIds,
  }) =>
      _guard(() async {
        return _remember(await _dio.post('/tags/student/$studentId', data: {
          'tag_ids': tagIds,
        }));
      });

  /// Removes an assigned tag from a student.
  Future<TagWriteResult> removeTag({
    required int studentId,
    required int tagId,
  }) =>
      _guard(() async {
        return _remember(await _dio.delete('/tags/student/$studentId/$tagId'));
      });

  /// Fetches all students with their assigned tags and room information.
  Future<List<Map<String, dynamic>>> getStudentsForAssignment() =>
      _guard(() async {
        final response =
            await _dio.get('/students', queryParameters: {'all': 'true'});
        final body = response.data;
        final data = body is Map ? (body['data'] ?? body['students']) : body;
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        return const [];
      });
}
