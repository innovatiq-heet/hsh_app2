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

  /// True if user navigated directly targeting a specific student from another screen
  final RxBool openedWithDirectTarget = false.obs;
  Map<String, dynamic>? _pendingTargetStudent;

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
    _checkInitialArguments();
    _loadRole();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _autoRefresh());
  }

  void _checkInitialArguments() {
    final args = Get.arguments;
    if (args is Map) {
      final map = Map<String, dynamic>.from(args);
      final aadhar = (map['aadhar'] ?? map['studentId'] ?? '').toString();
      final name = (map['name'] ?? map['fullName'] ?? '').toString();
      final room = (map['room'] ?? '').toString();

      openedWithDirectTarget.value = true;
      _pendingTargetStudent = map;

      if (aadhar.isNotEmpty && !aadhar.startsWith('stu_')) {
        selectStudent({
          'aadhar': aadhar,
          'name': name.isNotEmpty ? name : 'Student',
          'room': room.isNotEmpty ? room : 'N/A',
        });
      }
    }
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

        if (_pendingTargetStudent != null &&
            (selectedStudent.value == null ||
                (selectedStudent.value['aadhar'] ?? '').toString().isEmpty)) {
          _matchAndSelectPendingStudent();
        }
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchStudentsList error: $e');
    } finally {
      isLoadingStudents.value = false;
    }
  }

  void _matchAndSelectPendingStudent() {
    if (_pendingTargetStudent == null) return;
    final targetName = (_pendingTargetStudent!['name'] ??
            _pendingTargetStudent!['fullName'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
    final targetRoom =
        (_pendingTargetStudent!['room'] ?? '').toString().toLowerCase().trim();
    final targetAadhar = (_pendingTargetStudent!['aadhar'] ??
            _pendingTargetStudent!['studentId'] ??
            '')
        .toString()
        .trim();

    dynamic matched;
    for (final s in allStudents) {
      final sAadhar = (s['aadhar'] ?? '').toString().trim();
      final sName = (s['name'] ?? '').toString().toLowerCase().trim();
      final sRoom = (s['room'] ?? '').toString().toLowerCase().trim();

      if (targetAadhar.isNotEmpty &&
          sAadhar.isNotEmpty &&
          (sAadhar == targetAadhar ||
              sAadhar.endsWith(targetAadhar) ||
              targetAadhar.endsWith(sAadhar))) {
        matched = s;
        break;
      }
      if (targetName.isNotEmpty &&
          sName.isNotEmpty &&
          (sName == targetName ||
              sName.contains(targetName) ||
              targetName.contains(sName))) {
        matched = s;
        break;
      }
      if (targetRoom.isNotEmpty &&
          sRoom.isNotEmpty &&
          sRoom == targetRoom &&
          targetName.isNotEmpty &&
          sName.contains(targetName)) {
        matched = s;
        break;
      }
    }

    if (matched != null) {
      selectStudent(matched);
    } else if (targetAadhar.isNotEmpty && selectedStudent.value == null) {
      selectStudent(_pendingTargetStudent);
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

    // Retain all existing stats from the student object immediately so data is visible
    totalMinutesToday.value = toInt(student['totalScreenTimeMinutes']);
    nightMinutesToday.value = toInt(student['nightScreenTimeMinutes']);
    isOnline.value = student['isOnline'] == true;
    isScreenOn.value = student['isScreenOn'] == true;
    currentApp.value = (student['currentApp'] ?? 'Idle').toString();

    final directApps = _extractAppsList(student);
    if (directApps.isNotEmpty) {
      appBreakdown.assignAll(_sortedByMinutes(directApps));
    } else {
      appBreakdown.clear();
    }
    historyRecords.clear();

    final aadhar = (student['aadhar'] ?? '').toString().trim();
    final id = (student['_id'] ?? student['id'] ?? '').toString().trim();
    final studentId = (student['studentId'] ?? student['student_id'] ?? '').toString().trim();
    targetedAadhar.value = aadhar.isNotEmpty ? aadhar : (id.isNotEmpty ? id : studentId);

    debugPrint('[ScreenTime] selectStudent: ${student['name']}, aadhar=$aadhar, id=$id, studentId=$studentId, initialMins=${totalMinutesToday.value}, appsCount=${appBreakdown.length}');

    fetchLiveStatus();
    fetchHistory();
  }

  /// Return back to all students directory list
  void clearSelectedStudent() {
    selectedStudent.value = null;
    targetedAadhar.value = '';
    _pendingTargetStudent = null;
    openedWithDirectTarget.value = false;
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

  List<String> _getCandidateIdentifiers() {
    final s = selectedStudent.value;
    final list = <String>[];
    if (s is Map) {
      final id = (s['_id'] ?? s['id'] ?? '').toString().trim();
      final aadhar = (s['aadhar'] ?? '').toString().trim();
      final studentId = (s['studentId'] ?? s['student_id'] ?? '').toString().trim();
      final studentCode = (s['studentCode'] ?? s['bankCode'] ?? '').toString().trim();

      if (id.isNotEmpty) list.add(id);
      if (aadhar.isNotEmpty && !list.contains(aadhar)) list.add(aadhar);
      if (studentId.isNotEmpty && !list.contains(studentId)) list.add(studentId);
      if (studentCode.isNotEmpty && !list.contains(studentCode)) list.add(studentCode);
    }
    if (targetedAadhar.value.isNotEmpty && !list.contains(targetedAadhar.value)) {
      list.add(targetedAadhar.value);
    }
    return list;
  }

  /// Fetch live status from real API (for self or targeted student)
  Future<void> fetchLiveStatus() async {
    final candidates = _getCandidateIdentifiers();
    isLoading.value = true;
    try {
      if (candidates.isEmpty) {
        final response = await _apiClient.dio.get('/screen-time/live');
        _applyLiveStatusResponse(response.data);
        return;
      }

      bool success = false;
      for (final cand in candidates) {
        try {
          final endpoint = '/screen-time/live/$cand';
          debugPrint('[ScreenTime] Trying live endpoint: $endpoint');
          final response = await _apiClient.dio.get(endpoint);
          if (response.statusCode == 200 && response.data != null) {
            _applyLiveStatusResponse(response.data);
            success = true;
            break;
          }
        } catch (e) {
          debugPrint('[ScreenTime] live endpoint with $cand failed: $e');
        }
      }

      // If path param failed, try query param format
      if (!success) {
        for (final cand in candidates) {
          try {
            final response = await _apiClient.dio.get(
              '/screen-time/live',
              queryParameters: {'aadhar': cand, 'id': cand, 'studentId': cand},
            );
            if (response.statusCode == 200 && response.data != null) {
              _applyLiveStatusResponse(response.data);
              success = true;
              break;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchLiveStatus error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _applyLiveStatusResponse(dynamic raw) {
    final data = raw is Map ? (raw['data'] ?? raw) : null;
    if (data == null || data is! Map) return;

    debugPrint('[ScreenTime] _applyLiveStatusResponse data: $data');

    if (data['isOnline'] != null) {
      isOnline.value = data['isOnline'] == true;
    } else if (data['is_online'] != null) {
      isOnline.value = data['is_online'] == true;
    }

    if (data['isScreenOn'] != null) {
      isScreenOn.value = data['isScreenOn'] == true;
    } else if (data['is_screen_on'] != null) {
      isScreenOn.value = data['is_screen_on'] == true;
    }

    if (data['currentApp'] != null && data['currentApp'].toString().isNotEmpty) {
      currentApp.value = data['currentApp'].toString();
    } else if (data['current_app'] != null && data['current_app'].toString().isNotEmpty) {
      currentApp.value = data['current_app'].toString();
    }

    final liveTotal = toInt(
      data['totalScreenTimeMinutes'] ??
          data['total_screen_time_minutes'] ??
          data['totalMinutes'] ??
          data['total_minutes'] ??
          data['screenTime']?['totalScreenTimeMinutes'] ??
          data['screenTime']?['total_screen_time_minutes'] ??
          data['today']?['totalScreenTimeMinutes'] ??
          data['today']?['total_screen_time_minutes'] ??
          data['live']?['totalScreenTimeMinutes'] ??
          data['live']?['total_screen_time_minutes'],
    );
    if (liveTotal > 0 || totalMinutesToday.value == 0) {
      totalMinutesToday.value = liveTotal;
    }

    final liveNight = toInt(
      data['nightScreenTimeMinutes'] ??
          data['night_screen_time_minutes'] ??
          data['nightMinutes'] ??
          data['night_minutes'] ??
          data['screenTime']?['nightScreenTimeMinutes'] ??
          data['screenTime']?['night_screen_time_minutes'] ??
          data['today']?['nightScreenTimeMinutes'] ??
          data['today']?['night_screen_time_minutes'] ??
          data['live']?['nightScreenTimeMinutes'] ??
          data['live']?['night_screen_time_minutes'],
    );
    if (liveNight > 0 || nightMinutesToday.value == 0) {
      nightMinutesToday.value = liveNight;
    }

    final newApps = _extractAppsList(data);
    if (newApps.isNotEmpty) {
      appBreakdown.assignAll(_sortedByMinutes(newApps));
      debugPrint('[ScreenTime] updated appBreakdown with ${appBreakdown.length} apps. First app: ${appBreakdown.first}');

      if (totalMinutesToday.value == 0) {
        final appsSum = newApps.fold<int>(
          0,
          (sum, item) =>
              sum +
              toInt(
                item['minutes'] ??
                    item['total_minutes'] ??
                    item['totalMinutes'] ??
                    item['duration'] ??
                    item['time'] ??
                    item['usage_minutes'],
              ),
        );
        if (appsSum > 0) {
          totalMinutesToday.value = appsSum;
        }
      }
    }
  }

  /// Fetch history logs from real API
  Future<void> fetchHistory() async {
    final candidates = _getCandidateIdentifiers();
    try {
      if (candidates.isEmpty) {
        final response = await _apiClient.dio.get('/screen-time/history');
        _applyHistoryResponse(response.data);
        return;
      }

      for (final cand in candidates) {
        try {
          final endpoint = '/screen-time/history/$cand';
          debugPrint('[ScreenTime] Trying history endpoint: $endpoint');
          final response = await _apiClient.dio.get(endpoint);
          if (response.statusCode == 200 && response.data != null) {
            _applyHistoryResponse(response.data);
            break;
          }
        } catch (e) {
          debugPrint('[ScreenTime] history endpoint with $cand failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchHistory error: $e');
    }
  }

  void _applyHistoryResponse(dynamic raw) {
    final data = raw is Map ? (raw['data'] ?? raw) : raw;
    List<dynamic>? records;
    if (data is Map && data['records'] is List) {
      records = List<dynamic>.from(data['records']);
    } else if (data is Map && data['history'] is List) {
      records = List<dynamic>.from(data['history']);
    } else if (data is List) {
      records = List<dynamic>.from(data);
    }

    if (records != null && records.isNotEmpty) {
      historyRecords.assignAll(records);
      debugPrint('[ScreenTime] loaded ${historyRecords.length} history records: ${historyRecords.first}');
      _extractAppsFromHistoryIfEmpty();

      // If totalMinutesToday is still 0, check today's record in history
      if (totalMinutesToday.value == 0) {
        final firstRec = records.first;
        final historyMins = toInt(
          firstRec['total_screen_time_minutes'] ??
              firstRec['totalScreenTimeMinutes'] ??
              firstRec['totalMinutes'] ??
              firstRec['minutes'],
        );
        if (historyMins > 0) {
          totalMinutesToday.value = historyMins;
        }
      }
    }
  }

  void _extractAppsFromHistoryIfEmpty() {
    if (appBreakdown.isNotEmpty) return;
    for (final rec in historyRecords) {
      final apps = _extractAppsList(rec);
      if (apps.isNotEmpty) {
        appBreakdown.assignAll(_sortedByMinutes(apps));
        debugPrint('[ScreenTime] extracted ${appBreakdown.length} apps from history');
        break;
      }
    }
  }

  List<dynamic> _extractAppsList(dynamic source) {
    if (source == null) return [];
    if (source is Map) {
      final candidates = [
        source['appUsageBreakdown'],
        source['apps'],
        source['appBreakdown'],
        source['app_breakdown'],
        source['usageBreakdown'],
        source['screenTime']?['appUsageBreakdown'],
        source['today']?['appUsageBreakdown'],
        source['liveStatus']?['appUsageBreakdown'],
        source['student']?['appUsageBreakdown'],
        source['breakdown'],
      ];
      for (final c in candidates) {
        if (c is List && c.isNotEmpty) {
          return c;
        }
      }
    }
    return [];
  }

  List<dynamic> _sortedByMinutes(dynamic raw) {
    final list = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
    list.sort((a, b) {
      final mA = toInt(a['minutes'] ?? a['duration'] ?? a['time'] ?? a['timeInMinutes']);
      final mB = toInt(b['minutes'] ?? b['duration'] ?? b['time'] ?? b['timeInMinutes']);
      return mB.compareTo(mA);
    });
    return list;
  }

  /// The API may send minutes as int, double or string.
  static int toInt(dynamic value) {
    if (value is num) return value.round();
    if (value is String) return num.tryParse(value)?.round() ?? 0;
    return 0;
  }
}
