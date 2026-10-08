import '../../../core/storage/session_store.dart';
import '../../../core/enums/user_role.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../../core/network/repository/alumni/alumni_repository.dart';

class AlumniController extends GetxController {
  final AlumniRepository _repository = Get.find<AlumniRepository>();

  final RxBool isLoading = false.obs;
  final RxBool isDirectoryLoading = false.obs;
  final RxBool isEventsLoading = false.obs;
  final RxBool isJobsLoading = false.obs;
  final RxBool isMentorshipLoading = false.obs;
  final RxBool isNewsLoading = false.obs;
  final RxBool isSavingProfile = false.obs;
  final RxBool isSubmitting = false.obs;

  final Rxn<AlumniProfileModel> myProfile = Rxn<AlumniProfileModel>();
  final RxList<AlumniProfileModel> directoryList = <AlumniProfileModel>[].obs;
  final RxList<AlumniEventModel> eventsList = <AlumniEventModel>[].obs;
  final RxList<AlumniJobModel> jobsList = <AlumniJobModel>[].obs;
  final RxList<AlumniProfileModel> mentorsList = <AlumniProfileModel>[].obs;
  final RxList<AlumniMentorshipRequestModel> sentRequests = <AlumniMentorshipRequestModel>[].obs;
  final RxList<AlumniMentorshipRequestModel> receivedRequests = <AlumniMentorshipRequestModel>[].obs;
  final RxList<HostelNewsModel> newsList = <HostelNewsModel>[].obs;

  // Directory Filter state
  final RxString directorySearch = ''.obs;
  final RxnInt selectedBatchYear = RxnInt();
  final RxString selectedField = ''.obs;
  final RxString selectedCity = ''.obs;
  final RxString selectedCompany = ''.obs;
  final RxBool onlyMentors = false.obs;

  // Job Filter state
  final RxString jobFilterType = 'all'.obs;
  final RxString jobSearchQuery = ''.obs;

  // News Filter state
  final RxString newsCategory = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  /// Initial dashboard loader
  Future<void> loadDashboard() async {
    isLoading.value = true;
    try {
      await Future.wait([
        loadMyProfile(),
        loadEvents(),
        loadJobs(),
        loadNews(),
      ]);
    } catch (e) {
      developer.log('Error loading alumni dashboard: $e', name: 'AlumniController');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load authenticated student's profile
  Future<void> loadMyProfile() async {
    try {
      final profile = await _repository.getMyProfile();
      if (profile != null) {
        myProfile.value = profile;
      }
    } catch (e) {
      developer.log('loadMyProfile error: $e', name: 'AlumniController');
    }
  }

  /// Update alumni profile
  Future<bool> saveMyProfile(AlumniProfileModel updated) async {
    isSavingProfile.value = true;
    try {
      final saved = await _repository.updateMyProfile(updated);
      myProfile.value = saved;
      Get.snackbar(
        'Profile Saved',
        'Your alumni profile has been updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      // Reload directory to reflect updates
      loadDirectory();
      return true;
    } catch (e) {
      Get.snackbar(
        'Save Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return false;
    } finally {
      isSavingProfile.value = false;
    }
  }

  /// Load Alumni Directory
  Future<void> loadDirectory({bool showSpinner = true}) async {
    if (showSpinner) isDirectoryLoading.value = true;
    try {
      final list = await _repository.fetchDirectory(
        search: directorySearch.value.isNotEmpty ? directorySearch.value : null,
        batchYear: selectedBatchYear.value,
        field: selectedField.value.isNotEmpty ? selectedField.value : null,
        company: selectedCompany.value.isNotEmpty ? selectedCompany.value : null,
        city: selectedCity.value.isNotEmpty ? selectedCity.value : null,
        isMentor: onlyMentors.value ? true : null,
      );
      directoryList.assignAll(list);
    } catch (e) {
      developer.log('loadDirectory error: $e', name: 'AlumniController');
    } finally {
      if (showSpinner) isDirectoryLoading.value = false;
    }
  }

  /// Load Events & Reunions
  Future<void> loadEvents() async {
    isEventsLoading.value = true;
    try {
      final list = await _repository.fetchEvents();
      eventsList.assignAll(list);
    } catch (e) {
      developer.log('loadEvents error: $e', name: 'AlumniController');
    } finally {
      isEventsLoading.value = false;
    }
  }

  /// Submit RSVP for an event
  Future<bool> submitRsvp(int eventId, String status, {int guests = 0, String notes = ''}) async {
    isSubmitting.value = true;
    try {
      await _repository.submitRsvp(eventId, status: status, guestsCount: guests, notes: notes);
      Get.snackbar(
        'RSVP Recorded',
        'Your attendance status has been updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      await loadEvents();
      return true;
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Load Mentors
  Future<void> loadMentors({String? topic, String? search}) async {
    isMentorshipLoading.value = true;
    try {
      final list = await _repository.fetchMentors(topic: topic, search: search);
      mentorsList.assignAll(list);
    } catch (e) {
      developer.log('loadMentors error: $e', name: 'AlumniController');
    } finally {
      isMentorshipLoading.value = false;
    }
  }

  /// Send Mentorship Request
  Future<bool> sendMentorshipRequest({
    required int mentorStudentId,
    required String topic,
    required String message,
  }) async {
    isSubmitting.value = true;
    try {
      await _repository.requestMentorship(
        mentorStudentId: mentorStudentId,
        topic: topic,
        message: message,
      );
      Get.snackbar(
        'Request Sent',
        'Your guidance request has been sent to the mentor.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      await loadMyMentorshipRequests();
      return true;
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Load Sent and Received Mentorship Requests
  Future<void> loadMyMentorshipRequests() async {
    isMentorshipLoading.value = true;
    try {
      final map = await _repository.fetchMyMentorshipRequests();
      sentRequests.assignAll(map['sent'] ?? []);
      receivedRequests.assignAll(map['received'] ?? []);
    } catch (e) {
      developer.log('loadMyMentorshipRequests error: $e', name: 'AlumniController');
    } finally {
      isMentorshipLoading.value = false;
    }
  }

  /// Update Mentorship Status (as mentor)
  Future<bool> updateMentorshipStatus(int requestId, String status, {String? notes}) async {
    isSubmitting.value = true;
    try {
      await _repository.updateMentorshipStatus(requestId, status: status, notes: notes);
      Get.snackbar(
        'Updated',
        'Mentorship request marked as ${status.toUpperCase()}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      await loadMyMentorshipRequests();
      return true;
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Load Job Board & Referrals
  Future<void> loadJobs() async {
    isJobsLoading.value = true;
    try {
      final list = await _repository.fetchJobs(
        search: jobSearchQuery.value.isNotEmpty ? jobSearchQuery.value : null,
        jobType: jobFilterType.value != 'all' ? jobFilterType.value : null,
      );
      jobsList.assignAll(list);
    } catch (e) {
      developer.log('loadJobs error: $e', name: 'AlumniController');
    } finally {
      isJobsLoading.value = false;
    }
  }

  /// Post a job opening or referral
  Future<bool> postJob({
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
    isSubmitting.value = true;
    try {
      await _repository.postJob(
        title: title,
        company: company,
        jobType: jobType,
        location: location,
        isRemote: isRemote,
        experienceRequired: experienceRequired,
        description: description,
        requirements: requirements,
        applyUrl: applyUrl,
        contactEmail: contactEmail,
      );
      Get.snackbar(
        'Job Posted',
        'Thank you! The referral opening is now visible to hostel alumni and juniors.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      await loadJobs();
      return true;
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Delete a job opening
  Future<void> deleteJob(int jobId) async {
    try {
      await _repository.deleteJob(jobId);
      jobsList.removeWhere((j) => j.id == jobId);
      Get.snackbar('Deleted', 'Job posting removed.', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// Load Hostel News & Giving Back
  Future<void> loadNews() async {
    isNewsLoading.value = true;
    try {
      final list = await _repository.fetchHostelNews(
        category: newsCategory.value != 'all' ? newsCategory.value : null,
      );
      newsList.assignAll(list);
    } catch (e) {
      developer.log('loadNews error: $e', name: 'AlumniController');
    } finally {
      isNewsLoading.value = false;
    }
  }

  // ---------- Admin Observables ----------
  final Rx<AlumniAdminStatsModel> adminStats = const AlumniAdminStatsModel().obs;
  final RxList<AlumniProfileModel> adminProfiles = <AlumniProfileModel>[].obs;
  final RxList<AlumniRsvpAttendeeModel> currentEventRsvps = <AlumniRsvpAttendeeModel>[].obs;
  final RxBool isAdminStatsLoading = false.obs;
  final RxBool isAdminProfilesLoading = false.obs;
  final RxBool isRsvpsLoading = false.obs;

  bool get isOperatorOrAdmin {
    final role = Get.find<SessionStore>().currentSession?.role;
    return role != null && role.canOperate;
  }

  Future<void> loadAdminStats() async {
    isAdminStatsLoading.value = true;
    try {
      final stats = await _repository.fetchAdminStats();
      adminStats.value = stats;
    } catch (e) {
      developer.log('Failed to load admin stats: $e', name: 'AlumniCtrl');
    } finally {
      isAdminStatsLoading.value = false;
    }
  }

  Future<void> loadAdminProfiles({String? search, int? graduationYear, bool? isVerified, bool? isMentor}) async {
    isAdminProfilesLoading.value = true;
    try {
      final list = await _repository.fetchAdminProfiles(
        search: search,
        graduationYear: graduationYear,
        isVerified: isVerified,
        isMentor: isMentor,
      );
      adminProfiles.assignAll(list);
    } catch (e) {
      developer.log('Failed to load admin profiles: $e', name: 'AlumniCtrl');
    } finally {
      isAdminProfilesLoading.value = false;
    }
  }

  Future<void> loadEventRsvps(int eventId) async {
    isRsvpsLoading.value = true;
    try {
      final list = await _repository.fetchEventRsvps(eventId);
      currentEventRsvps.assignAll(list);
    } catch (e) {
      developer.log('Failed to load event RSVPs: $e', name: 'AlumniCtrl');
    } finally {
      isRsvpsLoading.value = false;
    }
  }

  Future<bool> adminCreateEvent(Map<String, dynamic> data) async {
    try {
      await _repository.createEvent(data);
      Get.snackbar('Success', 'Event created successfully', snackPosition: SnackPosition.BOTTOM);
      await loadEvents();
      await loadAdminStats();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create event: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> adminUpdateEvent(int eventId, Map<String, dynamic> data) async {
    try {
      await _repository.updateEvent(eventId, data);
      Get.snackbar('Success', 'Event updated successfully', snackPosition: SnackPosition.BOTTOM);
      await loadEvents();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to update event: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> adminDeleteEvent(int eventId) async {
    try {
      await _repository.deleteEvent(eventId);
      Get.snackbar('Deleted', 'Event deleted successfully', snackPosition: SnackPosition.BOTTOM);
      await loadEvents();
      await loadAdminStats();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete event: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> adminCreateNews(Map<String, dynamic> data) async {
    try {
      await _repository.createNews(data);
      Get.snackbar('Success', 'News / Initiative published', snackPosition: SnackPosition.BOTTOM);
      await loadNews();
      await loadAdminStats();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to publish news: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> adminUpdateNews(int newsId, Map<String, dynamic> data) async {
    try {
      await _repository.updateNews(newsId, data);
      Get.snackbar('Success', 'News / Initiative updated', snackPosition: SnackPosition.BOTTOM);
      await loadNews();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to update news: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> adminDeleteNews(int newsId) async {
    try {
      await _repository.deleteNews(newsId);
      Get.snackbar('Deleted', 'News item removed', snackPosition: SnackPosition.BOTTOM);
      await loadNews();
      await loadAdminStats();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete news: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> adminToggleVerification(int studentId, bool newStatus) async {
    try {
      await _repository.updateProfileVerification(studentId, isVerified: newStatus);
      Get.snackbar('Updated', 'Alumnus verification updated', snackPosition: SnackPosition.BOTTOM);
      await loadAdminProfiles();
      await loadAdminStats();
    } catch (e) {
      Get.snackbar('Error', 'Failed to update verification: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> adminToggleMentor(int studentId, bool newStatus) async {
    try {
      await _repository.updateProfileVerification(studentId, isMentor: newStatus);
      Get.snackbar('Updated', 'Mentor status updated', snackPosition: SnackPosition.BOTTOM);
      await loadAdminProfiles();
      await loadAdminStats();
    } catch (e) {
      Get.snackbar('Error', 'Failed to update mentor: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> adminToggleJob(int jobId) async {
    try {
      await _repository.toggleJobStatus(jobId);
      Get.snackbar('Updated', 'Job posting visibility toggled', snackPosition: SnackPosition.BOTTOM);
      await loadJobs();
      await loadAdminStats();
    } catch (e) {
      Get.snackbar('Error', 'Failed to toggle job: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

}
