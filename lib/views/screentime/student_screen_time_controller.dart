import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common_enums/user_role.dart';
import '../../constants/app_config.dart';
import '../../network/api_client.dart';
import '../../storage/session_store.dart';

class StudentScreenTimeController extends GetxController with WidgetsBindingObserver {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final RxBool isLoading = false.obs;
  final RxBool isLoadingStudents = false.obs;
  final RxBool isOnline = false.obs;
  final RxBool isScreenOn = false.obs;
  final RxString currentApp = ''.obs;
  final RxInt totalMinutesToday = 0.obs;
  final RxInt nightMinutesToday = 0.obs;
  final RxList<dynamic> appBreakdown = <dynamic>[].obs;
  final RxList<dynamic> historyRecords = <dynamic>[].obs;

  // Student directory state for Leaders & Operators
  final RxList<dynamic> allStudents = <dynamic>[].obs;
  final RxList<dynamic> filteredStudents = <dynamic>[].obs;
  final Rx<dynamic> selectedStudent = Rx<dynamic>(null);

  final searchFilterController = TextEditingController();
  final RxString targetedAadhar = ''.obs;
  final Rx<UserRole> currentRole = UserRole.student.obs;

  Timer? _heartbeatTimer;
  DateTime? _lastResumeTime;
  int _sessionMinutes = 0;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _lastResumeTime = DateTime.now();
    _loadRole();
    startHeartbeatTimer();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    searchFilterController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastResumeTime = DateTime.now();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _flushActiveTime();
    }
  }

  void _flushActiveTime() {
    if (_lastResumeTime != null) {
      final elapsed = DateTime.now().difference(_lastResumeTime!).inMinutes;
      if (elapsed > 0) {
        _sessionMinutes += elapsed;
      }
      _lastResumeTime = DateTime.now();
    }
  }

  Future<void> _loadRole() async {
    final role = await SessionStore.instance.role;
    currentRole.value = role;

    if (role.canViewScreenTime) {
      await fetchStudentsList();
    } else {
      await fetchLiveStatus();
      await fetchHistory();
    }
  }

  /// Start periodic 10-minute ping from device
  void startHeartbeatTimer() {
    pingHeartbeat();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      pingHeartbeat();
    });
  }

  /// 10-minute real device heartbeat ping to backend
  Future<void> pingHeartbeat() async {
    try {
      _flushActiveTime();
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final isResumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

      final currentPackage = 'com.hsh.hostelapp';
      final currentAppName = AppConfig.appName;

      final breakdown = <Map<String, dynamic>>[];
      if (_sessionMinutes > 0) {
        breakdown.add({
          'packageName': currentPackage,
          'appName': currentAppName,
          'minutes': _sessionMinutes,
        });
      }

      await _apiClient.dio.post(
        '/screen-time/ping',
        data: {
          'date': dateStr,
          'totalScreenTimeMinutes': _sessionMinutes,
          'isScreenOn': isResumed,
          'currentApp': currentPackage,
          if (breakdown.isNotEmpty) 'appUsageBreakdown': breakdown,
        },
      );
    } catch (e) {
      debugPrint('[ScreenTime] Ping error: $e');
    }
  }

  /// Leader/Staff fetches directory of all students with today screen time overview from real API
  Future<void> fetchStudentsList([String? search]) async {
    isLoadingStudents.value = true;
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
        final list = List<dynamic>.from(data['students']);
        allStudents.assignAll(list);
        filteredStudents.assignAll(list);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchStudentsList error: $e');
    } finally {
      isLoadingStudents.value = false;
    }
  }

  /// Filter students locally by name, room, or Aadhar
  void filterStudents(String query) {
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
    final aadhar = (student['aadhar'] ?? '').toString();
    targetedAadhar.value = aadhar;
    fetchLiveStatus(aadhar);
    fetchHistory(aadhar);
  }

  /// Return back to all students directory list
  void clearSelectedStudent() {
    selectedStudent.value = null;
    targetedAadhar.value = '';
    searchFilterController.clear();
    filteredStudents.assignAll(allStudents);
  }

  /// Fetch live status from real API (for self or targeted student aadhar)
  Future<void> fetchLiveStatus([String? aadhar]) async {
    isLoading.value = true;
    try {
      final queryAadhar = aadhar ?? targetedAadhar.value;
      final endpoint = queryAadhar.isNotEmpty
          ? '/screen-time/live/$queryAadhar'
          : '/screen-time/live';

      final response = await _apiClient.dio.get(endpoint);
      final data = response.data['data'] ?? response.data;

      if (data != null) {
        isOnline.value = data['isOnline'] ?? false;
        isScreenOn.value = data['isScreenOn'] ?? false;
        currentApp.value = data['currentApp'] ?? 'Idle';
        totalMinutesToday.value = data['totalScreenTimeMinutes'] ?? 0;
        nightMinutesToday.value = data['nightScreenTimeMinutes'] ?? 0;
        appBreakdown.assignAll(data['appUsageBreakdown'] ?? []);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchLiveStatus error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch history logs from real API
  Future<void> fetchHistory([String? aadhar]) async {
    try {
      final queryAadhar = aadhar ?? targetedAadhar.value;
      final endpoint = queryAadhar.isNotEmpty
          ? '/screen-time/history/$queryAadhar'
          : '/screen-time/history';

      final response = await _apiClient.dio.get(endpoint);
      final data = response.data['data'] ?? response.data;
      if (data != null && data['records'] != null) {
        historyRecords.assignAll(data['records']);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchHistory error: $e');
    }
  }
}
