import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';
import '../../../models/broadcasts/broadcast_models.dart';

/// Broadcast messages: admin compose/history (`/broadcasts`) and the
/// student inbox (`/me/broadcasts`). Contract: docs/BROADCAST_DOCS.md.
class BroadcastsRepository extends BaseRepository {
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

  static int _total(dynamic body, int fallback) {
    final raw = body is Map ? body['total'] : null;
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  // --- admin ---

  /// How many active students [tagIds] ∪ [studentIds] reach.
  Future<BroadcastPreview> preview({
    required List<int> tagIds,
    required List<int> studentIds,
  }) =>
      _guard(() async {
        final res = await _dio.post('/broadcasts/preview', data: {
          'tag_ids': tagIds,
          'student_ids': studentIds,
        });
        return BroadcastPreview.fromJson(_data(res.data));
      });

  /// Sends a broadcast. A repeat of [clientRequestId] returns the original
  /// broadcast (200) and sends nothing again.
  Future<Broadcast> send({
    required String clientRequestId,
    required String title,
    required String message,
    required List<int> tagIds,
    required List<int> studentIds,
  }) =>
      _guard(() async {
        final res = await _dio.post('/broadcasts', data: {
          'client_request_id': clientRequestId,
          'title': title,
          'message': message,
          'tag_ids': tagIds,
          'student_ids': studentIds,
        });
        return Broadcast.fromJson(_data(res.data));
      });

  /// This admin's sent broadcasts, newest first.
  Future<BroadcastPage> history({int limit = 20, int offset = 0}) => _guard(() async {
        final res = await _dio.get('/broadcasts', queryParameters: {
          'limit': limit,
          'offset': offset,
        });
        final items = _list(res.data).map(Broadcast.fromJson).toList();
        return BroadcastPage(items, _total(res.data, offset + items.length));
      });

  /// One broadcast with its recipients.
  Future<Broadcast> detail(int id) => _guard(() async {
        final res = await _dio.get('/broadcasts/$id');
        return Broadcast.fromJson(_data(res.data));
      });

  // --- recipient ---

  /// The logged-in student's inbox, newest first.
  Future<InboxPage> inbox({int limit = 20, int offset = 0}) => _guard(() async {
        final res = await _dio.get('/me/broadcasts', queryParameters: {
          'limit': limit,
          'offset': offset,
        });
        final items = _list(res.data).map(InboxBroadcast.fromJson).toList();
        final body = res.data;
        final unread = int.tryParse(
              (body is Map ? body['unread_count'] : null)?.toString() ?? '',
            ) ??
            items.where((i) => !i.isRead).length;
        return InboxPage(items, _total(body, offset + items.length), unread);
      });

  /// Marks one inbox message read (idempotent). Returns the server's read time.
  Future<DateTime?> markRead(int id) => _guard(() async {
        final res = await _dio.post('/me/broadcasts/$id/read');
        final body = res.data;
        final data = body is Map ? body['data'] : null;
        final raw = data is Map ? data['read_at'] : null;
        return raw == null ? null : DateTime.tryParse(raw.toString())?.toUtc();
      });
}
