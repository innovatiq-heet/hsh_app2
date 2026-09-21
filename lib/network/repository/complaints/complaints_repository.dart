import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../../../common_enums/complaint_status.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../request/complaints/submit_complaint_request.dart';
import '../../request/complaints/update_complaint_request.dart';
import '../../responses/complaints/complaint_response.dart';

class ComplaintsRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ??
        'Server communication error. Please check your network connection.';
  }

  // --- Categories (GET /complains/categories) ---
  Future<List<String>> categories() async {
    try {
      final response = await _dio.get('/complains/categories');
      final data = response.data;
      if (data is Map &&
          data['data'] is Map &&
          data['data']['categories'] is List) {
        return (data['data']['categories'] as List)
            .map((e) => e.toString())
            .toList();
      }
    } on DioException catch (e) {
      developer.log(
        'GET /complains/categories error: ${e.message}',
        name: 'ComplaintsRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'GET /complains/categories error: $e',
        name: 'ComplaintsRepository',
      );
    }
    return const [
      'Electrical',
      'Plumbing',
      'Furniture',
      'Housekeeping',
      'Internet/Wifi',
      'Other',
    ];
  }

  // --- List Own Complaints (Student: GET /complains) ---
  Future<List<ComplaintResponse>> list({String? studentAadhar}) async {
    try {
      final query = <String, dynamic>{};
      if (studentAadhar != null && studentAadhar.isNotEmpty) {
        query['aadhar'] = studentAadhar;
      }
      final response = await _dio.get('/complains', queryParameters: query);
      return _extractComplaintList(response.data);
    } on DioException catch (e) {
      developer.log(
        'GET /complains error: ${e.message}',
        name: 'ComplaintsRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'GET /complains parsing error: $e',
        name: 'ComplaintsRepository',
      );
      throw ApiException('Failed to load complaints: $e');
    }
  }

  // --- List All Complaints (Admin/Solver: GET /complains) ---
  Future<List<ComplaintResponse>> adminComplaints({
    ComplaintStatus? status,
    String? room,
    String? aadhar,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (status != null) query['status'] = status.apiValue;
      if (room != null && room.isNotEmpty) query['room'] = room;
      if (aadhar != null && aadhar.isNotEmpty) query['aadhar'] = aadhar;

      final response = await _dio.get('/complains', queryParameters: query);
      return _extractComplaintList(response.data);
    } on DioException catch (e) {
      developer.log(
        'GET /complains (admin) error: ${e.message}',
        name: 'ComplaintsRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'GET /complains (admin) parsing error: $e',
        name: 'ComplaintsRepository',
      );
      throw ApiException('Failed to load complaints: $e');
    }
  }

  // --- Complaint Details (GET /complains/:id) ---
  Future<ComplaintResponse> detail(String id) async {
    try {
      final response = await _dio.get('/complains/$id');
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final compJson = data['data']['complain'] ?? data['data'];
        if (compJson is Map<String, dynamic>) {
          return ComplaintResponse.fromJson(compJson);
        }
      }
      throw ApiException('Unexpected server response format');
    } on DioException catch (e) {
      developer.log(
        'GET /complains/$id error: ${e.message}',
        name: 'ComplaintsRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'GET /complains/$id error: $e',
        name: 'ComplaintsRepository',
      );
      throw ApiException('Failed to load complaint details: $e');
    }
  }

  // --- Submit Complaint (POST /complains) ---
  Future<ComplaintResponse> submit(SubmitComplaintRequest request) async {
    try {
      final formData = FormData.fromMap({
        'aadhar': request.studentAadhar,
        'room': request.room,
        'compType': request.category,
        'compDesc': request.title.isNotEmpty
            ? '${request.title}\n\n${request.description}'
            : request.description,
      });

      for (int i = 0; i < request.images.length; i++) {
        final f = request.images[i];
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(f.path, filename: 'photo_$i.jpg'),
          ),
        );
      }

      final response = await _dio.post('/complains', data: formData);
      final data = response.data;
      if (data is Map &&
          data['data'] is Map &&
          data['data']['complain'] is Map) {
        return ComplaintResponse.fromJson(data['data']['complain']);
      }
      throw ApiException('Unexpected server response format');
    } on DioException catch (e) {
      developer.log(
        'POST /complains error: ${e.message}',
        name: 'ComplaintsRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'POST /complains error: $e',
        name: 'ComplaintsRepository',
      );
      throw ApiException('Failed to submit complaint: $e');
    }
  }

  // --- Update Complaint (PATCH /complains/:id) ---
  Future<ComplaintResponse> updateComplaint(
    String id,
    UpdateComplaintRequest request,
  ) async {
    try {
      final response = await _dio.patch(
        '/complains/$id',
        data: request.toJson(),
      );
      final data = response.data;
      if (data is Map &&
          data['data'] is Map &&
          data['data']['complain'] is Map) {
        return ComplaintResponse.fromJson(data['data']['complain']);
      }
      throw ApiException('Unexpected server response format');
    } on DioException catch (e) {
      developer.log(
        'PATCH /complains/$id error: ${e.message}',
        name: 'ComplaintsRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    } catch (e) {
      developer.log(
        'PATCH /complains/$id error: $e',
        name: 'ComplaintsRepository',
      );
      throw ApiException('Failed to update complaint: $e');
    }
  }

  // --- Delete Complaint (DELETE /complains/:id) ---
  Future<void> deleteComplaint(String id) async {
    try {
      await _dio.delete('/complains/$id');
    } on DioException catch (e) {
      developer.log(
        'DELETE /complains/$id error: ${e.message}',
        name: 'ComplaintsRepository',
      );
      throw ApiException(_message(e), statusCode: e.response?.statusCode);
    }
  }

  // --- Backward compatibility helpers ---
  Future<ComplaintResponse> updateStatus(String id, ComplaintStatus status) {
    return updateComplaint(id, UpdateComplaintRequest(status: status));
  }

  Future<ComplaintResponse> addFeedback(String id, String feedback) {
    return updateComplaint(
      id,
      UpdateComplaintRequest(
        status: ComplaintStatus.resolved,
        response: feedback,
      ),
    );
  }

  List<ComplaintResponse> _extractComplaintList(dynamic body) {
    if (body is! Map) return const [];
    final data = body['data'];
    List? rawList;
    if (data is Map && data['complains'] is List) {
      rawList = data['complains'] as List;
    } else if (body['complains'] is List) {
      rawList = body['complains'] as List;
    } else if (data is List) {
      rawList = data;
    }
    if (rawList == null) return const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((j) => ComplaintResponse.fromJson(j))
        .toList();
  }
}
