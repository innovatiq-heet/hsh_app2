import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../../../enums/complaint_status.dart';
import '../../../utils/image_type.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../base_repository.dart';
import '../../request/complaints/submit_complaint_request.dart';
import '../../responses/complaints/complaint_catalog.dart';
import '../../responses/complaints/complaint_response.dart';

/// Room complaints: the category/item catalog, a student's own complaints,
/// and the solver queue (`/admin/complaints`, complain-solver + admin).
class ComplaintsRepository extends BaseRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  static const int pageSize = 50;

  Future<List<ComplaintCategory>> categories() async {
    try {
      final response = await _dio.get('/complaint-categories');
      return _dataList(response.data).map(ComplaintCategory.fromJson).toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Category ids the signed-in complaint solver is limited to (Admin →
  /// Manage Users), from `/auth/me`; `null` means all categories, which is
  /// also the answer for admins and when it can't be read (the API enforces
  /// the limit regardless).
  Future<List<int>?> assignedCategoryIds() async {
    try {
      final response = await _dio.get('/auth/me');
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final ids = data is Map ? data['complaint_category_ids'] : null;
      return ids is List ? ids.whereType<num>().map((id) => id.toInt()).toList() : null;
    } on DioException {
      return null;
    }
  }

  Future<List<ComplaintItem>> items(int categoryId) async {
    try {
      final response = await _dio.get(
        '/complaint-items',
        queryParameters: {'categoryId': categoryId},
      );
      return _dataList(response.data).map(ComplaintItem.fromJson).toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Sends multipart (photo in the `image` field) when there is a photo,
  /// plain JSON otherwise.
  Future<ComplaintResponse> submit(SubmitComplaintRequest request) async {
    try {
      final Object body;
      final image = request.image;
      if (image == null) {
        body = request.toJson();
      } else {
        // The API checks the declared type against the file's bytes, so the
        // part must carry the real type rather than octet-stream.
        final mimeType = ImageType.sniffMimeType(await _header(image));
        if (mimeType == null) {
          throw const ApiException('Photo must be a JPEG, PNG or WebP image');
        }
        body = FormData.fromMap({
          ...request.toJson().map((k, v) => MapEntry(k, v.toString())),
          'image': await MultipartFile.fromFile(
            image.path,
            filename: 'complaint.${mimeType.split('/').last}',
            contentType: DioMediaType.parse(mimeType),
          ),
        });
      }
      final response = await _dio.post('/complaints', data: body);
      return ComplaintResponse.fromJson(_dataMap(response.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// The signed-in student's complaints, newest first.
  Future<List<ComplaintResponse>> myComplaints({
    int limit = pageSize,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/complaints/my',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return _dataList(response.data).map(ComplaintResponse.fromJson).toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Students get only their own (404 otherwise); solvers get any, with
  /// the `student` field.
  Future<ComplaintResponse> detail(String id) async {
    try {
      final response = await _dio.get('/complaints/$id');
      return ComplaintResponse.fromJson(_dataMap(response.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Solver queue. Every filter is optional; [roomId] is an exact match.
  Future<List<ComplaintResponse>> adminComplaints({
    ComplaintStatus? status,
    int? categoryId,
    String? roomId,
    int? studentId,
    int limit = pageSize,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/complaints',
        queryParameters: {
          if (status != null) 'status': status.apiValue,
          'categoryId': ?categoryId,
          if (roomId != null && roomId.trim().isNotEmpty) 'room_id': roomId.trim(),
          'studentId': ?studentId,
          'limit': limit,
          'offset': offset,
        },
      );
      return _dataList(response.data).map(ComplaintResponse.fromJson).toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// Any status may move to any other. Returns the updated complaint.
  Future<ComplaintResponse> updateStatus(String id, ComplaintStatus status) async {
    try {
      final response = await _dio.patch(
        '/admin/complaints/$id/status',
        data: {'status': status.apiValue},
      );
      return ComplaintResponse.fromJson(_dataMap(response.data));
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<List<int>> _header(File file) async {
    final raf = await file.open();
    try {
      return await raf.read(16);
    } finally {
      await raf.close();
    }
  }

  Iterable<Map<String, dynamic>> _dataList(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e));
  }

  Map<String, dynamic> _dataMap(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) throw const ApiException('Unexpected server response');
    return Map<String, dynamic>.from(data);
  }
}
