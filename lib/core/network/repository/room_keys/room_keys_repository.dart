import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../models/room_keys/room_key_models.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';

/// Room keys (`/room-keys`): door and cupboard keys per room and who has
/// them. Contract: docs/ROOM_KEYS_DOCS.md. A student is always the numeric
/// `students.id`.
///
/// Methods throw [ApiException] on failure.
class RoomKeysRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  static List<RoomKey> _keys(dynamic body) {
    final data = body is Map ? body['data'] : body;
    final list = data is Map ? data['keys'] : data;
    if (list is! List) throw const ApiException('Unexpected server response');
    return list.whereType<Map>().map((m) => RoomKey.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  static RoomKey _key(dynamic body) {
    final data = body is Map ? body['data'] : null;
    final map = data is Map && data['key'] is Map ? data['key'] : data;
    if (map is! Map) throw const ApiException('Unexpected server response');
    return RoomKey.fromJson(Map<String, dynamic>.from(map));
  }

  /// Every key of the hostel.
  Future<List<RoomKey>> list() => _guard(() async => _keys((await _dio.get('/room-keys')).data));

  /// Adds [keys] to [roomNumber] in one go (a room's door and cupboard keys).
  Future<List<RoomKey>> addMany(String roomNumber, List<NewRoomKey> keys) => _guard(() async {
    final res = await _dio.post(
      '/room-keys/batch',
      data: {
        'room_number': normalizeRoom(roomNumber),
        'keys': [for (final k in keys) k.toJson()],
      },
    );
    return _keys(res.data);
  });

  /// Partial update of a key's details: send only the changed fields
  /// (`key_number`, `label`, `key_type`, `notes`).
  Future<RoomKey> update(int id, Map<String, dynamic> fields) =>
      _guard(() async => _key((await _dio.put('/room-keys/$id', data: fields)).data));

  /// Gives the key to [studentId], returns it to the office, or marks it
  /// lost / found. Returns the key as saved.
  Future<RoomKey> act(int id, KeyAction action, {int? studentId, String? note}) => _guard(() async {
    final res = await _dio.post(
      '/room-keys/$id/action',
      data: {
        'action': action.wire,
        'student_id': ?studentId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _key(res.data);
  });

  /// Removes a key (its history is kept on the server).
  Future<void> delete(int id) => _guard(() => _dio.delete('/room-keys/$id'));

  /// The key's history, newest first.
  Future<List<RoomKeyLog>> history(int id) => _guard(() async {
    final body = (await _dio.get('/room-keys/$id/history')).data;
    final data = body is Map ? body['data'] : body;
    final list = data is Map ? data['logs'] : data;
    if (list is! List) return const [];
    return list.whereType<Map>().map((m) => RoomKeyLog.fromJson(Map<String, dynamic>.from(m))).toList();
  });
}
