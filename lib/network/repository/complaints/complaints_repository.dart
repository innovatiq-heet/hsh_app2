import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import '../../../common_enums/complaint_status.dart';
import '../../../common_models/attachments/attachment_model.dart';
import '../../api_client.dart';
import '../../api_exception.dart';
import '../../request/complaints/submit_complaint_request.dart';
import '../../request/complaints/update_complaint_request.dart';
import '../../responses/complaints/complaint_response.dart';

class ComplaintsRepository {
  Dio get _dio => Get.find<ApiClient>().dio;

  final List<ComplaintResponse> _complaints = [
    ComplaintResponse(
      id: 'c1',
      studentAadhar: '123456789012',
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      category: 'Electrical',
      title: 'Fan regulator broken & ceiling fan jerky',
      description:
          'The ceiling fan regulator in room A-204 is completely jammed at full speed, and the fan makes loud humming noises.',
      status: ComplaintStatus.pending,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
      phone: '+91 98765 43210',
      imagesCount: 2,
    ),
    ComplaintResponse(
      id: 'c2',
      studentAadhar: '234567890123',
      studentName: 'Aarav Patel',
      room: 'B-105',
      category: 'Plumbing',
      title: 'Washroom tap leaking continuously',
      description:
          'The sink tap in the washroom cannot be closed tightly and has been dripping water constantly for 2 days.',
      status: ComplaintStatus.reviewed,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 1, hours: 4)),
      review: 'Plumber Mahendra assigned. Inspection scheduled today at 4:30 PM.',
      reviewTime: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
      phone: '+91 98234 56789',
      imagesCount: 1,
    ),
    ComplaintResponse(
      id: 'c3',
      studentAadhar: '345678901234',
      studentName: 'Rohan Sharma',
      room: 'A-204',
      category: 'Furniture',
      title: 'Study table drawer slider stuck',
      description: 'The right side drawer rail came off its hinges and won\'t close completely.',
      status: ComplaintStatus.resolved,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 4)),
      review: 'Carpenter inspected and ordered replacement slider.',
      reviewTime: DateTime.now().toUtc().subtract(const Duration(days: 3)),
      feedback: 'Replaced rail sliders and tightened drawer brackets. Tested and working smoothly.',
      resolveTime: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      phone: '+91 97123 45678',
      imagesCount: 0,
    ),
    ComplaintResponse(
      id: 'c4',
      studentAadhar: '456789012345',
      studentName: 'Devang Joshi',
      room: 'C-302',
      category: 'Internet/Wifi',
      title: 'No Wi-Fi signal in C-Block corridor',
      description:
          'Repeated disconnection and low RSSI near room C-302. Access point LED shows blinking amber.',
      status: ComplaintStatus.pending,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(hours: 8)),
      phone: '+91 99012 34567',
      imagesCount: 1,
    ),
    ComplaintResponse(
      id: 'c5',
      studentAadhar: '567890123456',
      studentName: 'Manan Shah',
      room: 'A-101',
      category: 'Housekeeping',
      title: 'Window glass panel dirty & spider cobwebs',
      description: 'Outer window mesh has torn and dust accumulation needs deep cleaning.',
      status: ComplaintStatus.reviewed,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      review: 'Housekeeping supervisor Ravi instructed to assign morning shift crew.',
      reviewTime: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      phone: '+91 91234 56780',
      imagesCount: 1,
    ),
    ComplaintResponse(
      id: 'c6',
      studentAadhar: '678901234567',
      studentName: 'Harshil Mehta',
      room: 'B-208',
      category: 'Plumbing',
      title: 'Hot water geyser tripping MCB',
      description: 'Whenever geyser switch is toggled, main MCB trips immediately. Possible short circuit.',
      status: ComplaintStatus.resolved,
      submittedAt: DateTime.now().toUtc().subtract(const Duration(days: 6)),
      review: 'High priority electrical & plumbing check assigned.',
      reviewTime: DateTime.now().toUtc().subtract(const Duration(days: 5)),
      feedback: 'Geyser heating element was corroded causing earth fault. Element replaced with genuine 2kW spare.',
      resolveTime: DateTime.now().toUtc().subtract(const Duration(days: 4)),
      phone: '+91 93456 78901',
      imagesCount: 2,
    ),
  ];

  // --- Categories ---
  Future<List<String>> categories() async {
    try {
      final response = await _dio.get('/complains/categories');
      final data = response.data;
      if (data is Map && data['data'] is Map && data['data']['categories'] is List) {
        return (data['data']['categories'] as List).map((e) => e.toString()).toList();
      }
    } catch (e) {
      developer.log('GET /complains/categories fallback: $e', name: 'ComplaintsRepository');
    }
    return [
      'Electrical',
      'Plumbing',
      'Furniture',
      'Housekeeping',
      'Internet/Wifi',
      'Other',
    ];
  }

  // --- List Own Complaints (Student) ---
  Future<List<ComplaintResponse>> list({String? studentAadhar}) async {
    try {
      final response = await _dio.get('/complains');
      final list = _extractComplaintList(response.data);
      if (list.isNotEmpty) return list;
    } catch (e) {
      developer.log('GET /complains fallback: $e', name: 'ComplaintsRepository');
    }
    if (studentAadhar == null) return List.unmodifiable(_complaints);
    return _complaints.where((c) => c.studentAadhar == studentAadhar).toList();
  }

  // --- List All Complaints (Admin/Solver Desk) ---
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
      final list = _extractComplaintList(response.data);
      if (list.isNotEmpty) return list;
    } catch (e) {
      developer.log('GET /complains (admin) fallback: $e', name: 'ComplaintsRepository');
    }

    // Fallback to in-memory list
    return _complaints.where((c) {
      if (status != null && c.status != status) return false;
      if (room != null && room.isNotEmpty && !c.room.toLowerCase().contains(room.toLowerCase())) {
        return false;
      }
      if (aadhar != null && aadhar.isNotEmpty && !c.studentAadhar.contains(aadhar)) {
        return false;
      }
      return true;
    }).toList();
  }

  // --- Detail ---
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
    } catch (e) {
      developer.log('GET /complains/$id fallback: $e', name: 'ComplaintsRepository');
    }
    return _complaints.firstWhere(
      (c) => c.id == id,
      orElse: () => _complaints.first,
    );
  }

  // --- Submit Complaint ---
  Future<ComplaintResponse> submit(SubmitComplaintRequest request) async {
    try {
      final formData = FormData.fromMap({
        'aadhar': request.studentAadhar,
        'compType': request.category,
        'compDesc': '${request.title}\n\n${request.description}',
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
      if (data is Map && data['data'] is Map && data['data']['complain'] is Map) {
        final newComp = ComplaintResponse.fromJson(data['data']['complain']);
        _complaints.insert(0, newComp);
        return newComp;
      }
    } catch (e) {
      developer.log('POST /complains fallback: $e', name: 'ComplaintsRepository');
    }

    // Mock fallback
    final complaint = ComplaintResponse(
      id: 'c${_complaints.length + 1}',
      studentAadhar: request.studentAadhar,
      studentName: 'Krutarth Solanki',
      room: 'A-204',
      category: request.category,
      title: request.title,
      description: request.description,
      status: ComplaintStatus.pending,
      submittedAt: DateTime.now().toUtc(),
      attachments: request.images.map((f) => AttachmentModel(file: f)).toList(),
      imagesCount: request.images.length,
    );
    _complaints.insert(0, complaint);
    return complaint;
  }

  // --- Update Complaint (Admin/Solver) ---
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
      if (data is Map && data['data'] is Map && data['data']['complain'] is Map) {
        final updated = ComplaintResponse.fromJson(data['data']['complain']);
        final idx = _complaints.indexWhere((c) => c.id == id);
        if (idx != -1) _complaints[idx] = updated;
        return updated;
      }
    } catch (e) {
      developer.log('PATCH /complains/$id fallback: $e', name: 'ComplaintsRepository');
    }

    // In-memory update
    final index = _complaints.indexWhere((c) => c.id == id);
    if (index == -1) throw ApiException('Complaint not found');

    final current = _complaints[index];
    final updated = current.copyWith(
      status: request.status ?? current.status,
      feedback: request.response ?? current.feedback,
      review: request.review ?? current.review,
      reviewTime: request.status == ComplaintStatus.reviewed ? DateTime.now() : current.reviewTime,
      resolveTime: request.status == ComplaintStatus.resolved ? DateTime.now() : current.resolveTime,
    );
    _complaints[index] = updated;
    return updated;
  }

  // --- Delete Complaint (Admin) ---
  Future<void> deleteComplaint(String id) async {
    try {
      await _dio.delete('/complains/$id');
    } catch (e) {
      developer.log('DELETE /complains/$id fallback: $e', name: 'ComplaintsRepository');
    }
    _complaints.removeWhere((c) => c.id == id);
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
