import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../../../utils/image_type.dart';
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

  // --- admin & group leader ---

  static String _prefix(bool isLeader) => isLeader ? '/leader/broadcasts' : '/broadcasts';

  /// Leader-only: summary counts & linked WhatsApp status for their own group.
  Future<Map<String, dynamic>> leaderAudienceSummary() => _guard(() async {
        final res = await _dio.get('/leader/broadcasts/audience');
        return _data(res.data);
      });

  /// Leader-only: active residents & alumni strictly within their own group.
  Future<List<Map<String, dynamic>>> leaderGroupMembers({String? search}) => _guard(() async {
        final res = await _dio.get('/leader/broadcasts/students', queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        });
        return _list(res.data);
      });

  /// How many active students [tagIds] ∪ [studentIds] (or [audiencePreset]) reach.
  Future<BroadcastPreview> preview({
    required List<int> tagIds,
    required List<int> studentIds,
    String? audiencePreset,
    bool isLeader = false,
  }) =>
      _guard(() async {
        final res = await _dio.post('${_prefix(isLeader)}/preview', data: {
          'tag_ids': tagIds,
          'student_ids': studentIds,
          if (audiencePreset != null && audiencePreset.isNotEmpty) 'audience_preset': audiencePreset,
        });
        return BroadcastPreview.fromJson(_data(res.data));
      });

  /// Sends a broadcast. A repeat of [clientRequestId] returns the original
  /// broadcast (200) and sends nothing again.
  Future<Broadcast> send({
    required String clientRequestId,
    String? title,
    required String message,
    required List<int> tagIds,
    required List<int> studentIds,
    String channels = 'both',
    String? imageId,
    String? audiencePreset,
    bool isLeader = false,
  }) =>
      _guard(() async {
        final payload = <String, dynamic>{
          'client_request_id': clientRequestId,
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
          'message': message,
          if (imageId != null && imageId.isNotEmpty) 'image_id': imageId,
          'channels': channels,
          'tag_ids': tagIds,
          'student_ids': studentIds,
          if (audiencePreset != null && audiencePreset.isNotEmpty) 'audience_preset': audiencePreset,
        };
        final res = await _dio.post(_prefix(isLeader), data: payload);
        return Broadcast.fromJson(_data(res.data));
      });

  /// Uploads the picture for a broadcast. Send the returned id as `imageId` to [send].
  Future<BroadcastImageUpload> uploadImage(File file, {bool isLeader = false}) => _guard(() async {
        final mimeType = ImageType.sniffMimeType(await _header(file));
        if (mimeType == null) {
          throw const ApiException('Picture must be a JPEG, PNG or WebP image');
        }
        final form = FormData.fromMap({
          'image': await MultipartFile.fromFile(
            file.path,
            filename: 'broadcast.${mimeType.split('/').last}',
            contentType: DioMediaType.parse(mimeType),
          ),
        });
        final res = await _dio.post('${_prefix(isLeader)}/image', data: form);
        return BroadcastImageUpload.fromJson(_data(res.data));
      });

  static Future<List<int>> _header(File file) async {
    final raf = await file.open();
    try {
      return await raf.read(16);
    } finally {
      await raf.close();
    }
  }

  /// This admin/leader's sent broadcasts, newest first.
  Future<BroadcastPage> history({int limit = 20, int offset = 0, bool isLeader = false}) => _guard(() async {
        final res = await _dio.get(_prefix(isLeader), queryParameters: {
          'limit': limit,
          'offset': offset,
        });
        final items = _list(res.data).map(Broadcast.fromJson).toList();
        return BroadcastPage(items, _total(res.data, offset + items.length));
      });

  /// One broadcast with its recipients.
  Future<Broadcast> detail(int id, {bool isLeader = false}) => _guard(() async {
        final res = await _dio.get('${_prefix(isLeader)}/$id');
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
