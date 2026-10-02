import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/storage/session_store.dart';

/// Screen-time UI state.
///
/// Usage is *collected* natively (see [ScreenTimeService]) — this controller
/// only triggers an immediate sync for the student's own device and reads the
/// results back from the API.
class StudentScreenTimeController extends GetxController with WidgetsBindingObserver {
  final ApiClient _apiClient = Get.find<ApiClient>();

  static const _refreshInterval = Duration(minutes: 1);

  final RxBool isLoading = false.obs;
  final RxBool isLoadingStudents = false.obs;
  final RxBool isOnline = false.obs;
  final RxBool isScreenOn = false.obs;
  final RxString currentApp = ''.obs;
  final RxInt totalMinutesToday = 0.obs;
  final RxInt nightMinutesToday = 0.obs;
  final RxList<dynamic> appBreakdown = <dynamic>[].obs;
  final RxList<dynamic> historyRecords = <dynamic>[].obs;

  /// False when this (student's) device hasn't granted Usage access.
  final RxBool hasUsagePermission = true.obs;

  // Student directory state for Leaders & Operators
  final RxList<dynamic> allStudents = <dynamic>[].obs;
  final RxList<dynamic> filteredStudents = <dynamic>[].obs;
  final Rx<dynamic> selectedStudent = Rx<dynamic>(null);

  final searchFilterController = TextEditingController();
  final RxString searchText = ''.obs;
  final RxString targetedAadhar = ''.obs;
  final Rx<UserRole> currentRole = UserRole.student.obs;

  Timer? _refreshTimer;

  bool get _isViewingOwnDevice =>
      !currentRole.value.canViewScreenTime && targetedAadhar.isEmpty;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadRole();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _autoRefresh());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    searchFilterController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoRefresh();
  }

  Future<void> _loadRole() async {
    final role = await Get.find<SessionStore>().role;
    currentRole.value = role;

    if (role.canViewScreenTime) {
      await fetchStudentsList();
    } else {
      await refreshOwn();
    }
  }

  Future<void> _autoRefresh() async {
    if (_isViewingOwnDevice) {
      await refreshOwn();
    } else if (targetedAadhar.isNotEmpty) {
      await Future.wait([fetchLiveStatus(), fetchHistory()]);
    } else {
      await fetchStudentsList(silent: true);
    }
  }

  /// Student viewing their own device: push fresh usage first, then read it back.
  Future<void> refreshOwn() async {
    hasUsagePermission.value = !ScreenTimeService.isSupported ||
        await ScreenTimeService.hasUsagePermission();
    await ScreenTimeService.syncNow();
    await Future.wait([fetchLiveStatus(), fetchHistory()]);
  }

  Future<void> openUsageSettings() => ScreenTimeService.openUsageSettings();

  /// Manual refresh button.
  Future<void> refreshAll() async {
    if (currentRole.value.canViewScreenTime && selectedStudent.value == null) {
      await fetchStudentsList();
    } else if (_isViewingOwnDevice) {
      await refreshOwn();
    } else {
      await Future.wait([fetchLiveStatus(), fetchHistory()]);
    }
  }

  /// Leader/Staff fetches directory of all students with today screen time overview from real API
  Future<void> fetchStudentsList({String? search, bool silent = false}) async {
    if (!silent) isLoadingStudents.value = true;
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.dio.get(
        '/screen-time/students',
        queryParameters: queryParams,
      );
      final data = response.data['data'] ?? response.data;

      if (data != null && data['students'] != null) {
        allStudents.assignAll(List<dynamic>.from(data['students']));
        filterStudents(searchFilterController.text);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchStudentsList error: $e');
    } finally {
      isLoadingStudents.value = false;
    }
  }

  /// Filter students locally by name, room, or Aadhar
  void filterStudents(String query) {
    searchText.value = query;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      filteredStudents.assignAll(allStudents);
      return;
    }

    final matched = allStudents.where((student) {
      final name = (student['name'] ?? '').toString().toLowerCase();
      final room = (student['room'] ?? '').toString().toLowerCase();
      final aadhar = (student['aadhar'] ?? '').toString();
      return name.contains(q) || room.contains(q) || aadhar.contains(q);
    }).toList();

    filteredStudents.assignAll(matched);
  }

  /// Select a student from list to inspect detailed screen time from real API
  void selectStudent(dynamic student) {
    selectedStudent.value = student;
    targetedAadhar.value = (student['aadhar'] ?? '').toString();
    // Never show the previously selected student's numbers under this name.
    _resetDetail();
    fetchLiveStatus();
    fetchHistory();
  }

  /// Return back to all students directory list
  void clearSelectedStudent() {
    selectedStudent.value = null;
    targetedAadhar.value = '';
    _resetDetail();
    searchFilterController.clear();
    filterStudents('');
  }

  void _resetDetail() {
    isOnline.value = false;
    isScreenOn.value = false;
    currentApp.value = '';
    totalMinutesToday.value = 0;
    nightMinutesToday.value = 0;
    appBreakdown.clear();
    historyRecords.clear();
  }

  /// Fetch live status from real API (for self or targeted student aadhar)
  Future<void> fetchLiveStatus() async {
    final queryAadhar = targetedAadhar.value;
    isLoading.value = true;
    try {
      final endpoint = queryAadhar.isNotEmpty
          ? '/screen-time/live/$queryAadhar'
          : '/screen-time/live';

      final response = await _apiClient.dio.get(endpoint);
      // Selection changed while the request was in flight — drop the result.
      if (queryAadhar != targetedAadhar.value) return;
      final data = response.data['data'] ?? response.data;

      if (data != null) {
        isOnline.value = data['isOnline'] == true;
        isScreenOn.value = data['isScreenOn'] == true;
        currentApp.value = (data['currentApp'] ?? 'Idle').toString();
        totalMinutesToday.value = toInt(data['totalScreenTimeMinutes']);
        nightMinutesToday.value = toInt(data['nightScreenTimeMinutes']);
        appBreakdown.assignAll(_sortedByMinutes(data['appUsageBreakdown']));
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchLiveStatus error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch history logs from real API
  Future<void> fetchHistory() async {
    final queryAadhar = targetedAadhar.value;
    try {
      final endpoint = queryAadhar.isNotEmpty
          ? '/screen-time/history/$queryAadhar'
          : '/screen-time/history';

      final response = await _apiClient.dio.get(endpoint);
      if (queryAadhar != targetedAadhar.value) return;
      final data = response.data['data'] ?? response.data;
      if (data != null && data['records'] != null) {
        historyRecords.assignAll(data['records']);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchHistory error: $e');
    }
  }

  List<dynamic> _sortedByMinutes(dynamic raw) {
    final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
    list.sort((a, b) => toInt(b['minutes']).compareTo(toInt(a['minutes'])));
    return list;
  }

  /// The API may send minutes as int, double or string.
  static int toInt(dynamic value) {
    if (value is num) return value.round();
    if (value is String) return num.tryParse(value)?.round() ?? 0;
    return 0;
  }
}
