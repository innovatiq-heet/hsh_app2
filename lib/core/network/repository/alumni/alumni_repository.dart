import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../models/alumni/alumni_models.dart';
import '../../api_client.dart';
import '../base_repository.dart';

class AlumniRepository extends BaseRepository {
  final Dio _dio = Get.find<ApiClient>().dio;

  /// Fetches the authenticated student's alumni profile.
  Future<AlumniProfileModel?> getMyProfile() async {
    try {
      final response = await _dio.get('/alumni/me');
      if (response.data != null && response.data['data'] != null) {
        return AlumniProfileModel.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (e) {
      developer.log('AlumniRepository.getMyProfile error: ${errorMessage(e)}', name: 'AlumniRepo');
      rethrow;
    }
  }

  /// Updates or initializes the student's alumni profile.
  Future<AlumniProfileModel> updateMyProfile(AlumniProfileModel profile) async {
    try {
      final response = await _dio.put('/alumni/me', data: profile.toJson());
      if (response.data != null && response.data['data'] != null) {
        return AlumniProfileModel.fromJson(response.data['data']);
      }
      return profile;
    } on DioException catch (e) {
      developer.log('AlumniRepository.updateMyProfile error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Searches and filters fellow alumni.
  Future<List<AlumniProfileModel>> fetchDirectory({
    String? search,
    int? batchYear,
    String? field,
    String? company,
    String? city,
    bool? isMentor,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
      if (batchYear != null) queryParams['batch_year'] = batchYear;
      if (field != null && field.trim().isNotEmpty) queryParams['field'] = field.trim();
      if (company != null && company.trim().isNotEmpty) queryParams['company'] = company.trim();
      if (city != null && city.trim().isNotEmpty) queryParams['city'] = city.trim();
      if (isMentor == true) queryParams['is_mentor'] = 'true';

      final response = await _dio.get('/alumni/directory', queryParameters: queryParams);
      if (response.data != null && response.data['data'] is List) {
        return (response.data['data'] as List)
            .map((item) => AlumniProfileModel.fromJson(item))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      developer.log('AlumniRepository.fetchDirectory error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Fetches a specific alumnus profile by ID.
  Future<AlumniProfileModel> getProfile(int studentId) async {
    try {
      final response = await _dio.get('/alumni/profile/$studentId');
      if (response.data != null && response.data['data'] != null) {
        return AlumniProfileModel.fromJson(response.data['data']);
      }
      throw 'Profile not found';
    } on DioException catch (e) {
      developer.log('AlumniRepository.getProfile error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Fetches upcoming & past reunions and events.
  Future<List<AlumniEventModel>> fetchEvents() async {
    try {
      final response = await _dio.get('/alumni/events');
      if (response.data != null && response.data['data'] is List) {
        return (response.data['data'] as List)
            .map((item) => AlumniEventModel.fromJson(item))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      developer.log('AlumniRepository.fetchEvents error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Submits RSVP for an event.
  Future<void> submitRsvp(
    int eventId, {
    required String status,
    int guestsCount = 0,
    String notes = '',
  }) async {
    try {
      await _dio.post('/alumni/events/$eventId/rsvp', data: {
        'status': status,
        'guests_count': guestsCount,
        'notes': notes,
      });
    } on DioException catch (e) {
      developer.log('AlumniRepository.submitRsvp error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Fetches mentors available for guidance.
  Future<List<AlumniProfileModel>> fetchMentors({String? topic, String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (topic != null && topic.trim().isNotEmpty) queryParams['topic'] = topic.trim();
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final response = await _dio.get('/alumni/mentors', queryParameters: queryParams);
      if (response.data != null && response.data['data'] is List) {
        return (response.data['data'] as List)
            .map((item) => AlumniProfileModel.fromJson(item))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      developer.log('AlumniRepository.fetchMentors error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Sends a guidance/mentorship request to an alumnus.
  Future<void> requestMentorship({
    required int mentorStudentId,
    required String topic,
    required String message,
  }) async {
    try {
      await _dio.post('/alumni/mentorship/request', data: {
        'mentor_student_id': mentorStudentId,
        'topic': topic,
        'message': message,
      });
    } on DioException catch (e) {
      developer.log('AlumniRepository.requestMentorship error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Fetches sent and received mentorship requests.
  Future<Map<String, List<AlumniMentorshipRequestModel>>> fetchMyMentorshipRequests() async {
    try {
      final response = await _dio.get('/alumni/mentorship/my-requests');
      final data = response.data?['data'] ?? {};
      final sentList = (data['sent'] as List? ?? [])
          .map((item) => AlumniMentorshipRequestModel.fromJson(item))
          .toList();
      final receivedList = (data['received'] as List? ?? [])
          .map((item) => AlumniMentorshipRequestModel.fromJson(item))
          .toList();

      return {
        'sent': sentList,
        'received': receivedList,
      };
    } on DioException catch (e) {
      developer.log('AlumniRepository.fetchMyMentorshipRequests error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Updates status of a received mentorship request.
  Future<void> updateMentorshipStatus(
    int requestId, {
    required String status,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{'status': status};
      if (notes != null) data['notes'] = notes;
      await _dio.patch('/alumni/mentorship/requests/$requestId', data: data);
    } on DioException catch (e) {
      developer.log('AlumniRepository.updateMentorshipStatus error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Fetches job board and referral openings.
  Future<List<AlumniJobModel>> fetchJobs({
    String? search,
    String? jobType,
    String? location,
    bool? isRemote,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
      if (jobType != null && jobType != 'all') queryParams['job_type'] = jobType;
      if (location != null && location.trim().isNotEmpty) queryParams['location'] = location.trim();
      if (isRemote == true) queryParams['is_remote'] = 'true';

      final response = await _dio.get('/alumni/jobs', queryParameters: queryParams);
      if (response.data != null && response.data['data'] is List) {
        return (response.data['data'] as List)
            .map((item) => AlumniJobModel.fromJson(item))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      developer.log('AlumniRepository.fetchJobs error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Posts a job or internship referral.
  Future<void> postJob({
    required String title,
    required String company,
    required String jobType,
    required String location,
    required bool isRemote,
    String? experienceRequired,
    required String description,
    String? requirements,
    String? applyUrl,
    String? contactEmail,
  }) async {
    try {
      await _dio.post('/alumni/jobs', data: {
        'title': title,
        'company': company,
        'job_type': jobType,
        'location': location,
        'is_remote': isRemote,
        'experience_required': experienceRequired,
        'description': description,
        'requirements': requirements,
        'apply_url': applyUrl,
        'contact_email': contactEmail,
      });
    } on DioException catch (e) {
      developer.log('AlumniRepository.postJob error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Deletes a job posting.
  Future<void> deleteJob(int jobId) async {
    try {
      await _dio.delete('/alumni/jobs/$jobId');
    } on DioException catch (e) {
      developer.log('AlumniRepository.deleteJob error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }

  /// Fetches hostel news, renovations, achievements, and voluntary initiatives.
  Future<List<HostelNewsModel>> fetchHostelNews({String? category}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category != 'all') queryParams['category'] = category;

      final response = await _dio.get('/alumni/news', queryParameters: queryParams);
      if (response.data != null && response.data['data'] is List) {
        return (response.data['data'] as List)
            .map((item) => HostelNewsModel.fromJson(item))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      developer.log('AlumniRepository.fetchHostelNews error: ${errorMessage(e)}', name: 'AlumniRepo');
      throw errorMessage(e);
    }
  }
}
