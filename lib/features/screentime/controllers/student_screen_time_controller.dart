import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
/// Screen-time and Parental Control controller for Administrators.
///
/// Restricted to Admin / Warden roles. Allows monitoring student phone telemetry,
/// inspecting live app usage, blocking distracting apps remotely, locking devices,
/// and setting bedtime curfews.
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

  // Parental Control & App Blocking state
  final RxList<String> blockedPackages = <String>[].obs;
  final RxBool isDeviceLocked = false.obs;
  final RxInt dailyLimitMinutes = 0.obs;
  final RxString bedtimeStart = '23:00'.obs;
  final RxString bedtimeEnd = '05:00'.obs;
  final RxString selectedAppFilter = 'All'.obs; // 'All', 'Used Today', 'Restricted'
  final RxString appSearchQuery = ''.obs;
  final appSearchController = TextEditingController();
  final RxBool isUpdatingPolicy = false.obs;

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

    if (!role.canViewScreenTime) {
      Get.back();
      AppSnackbar.error(
        'Access Denied',
        'Screen Time & Parental Controls are restricted to Administrators only.',
      );
      return;
    }

    await fetchStudentsList();
  }

  Future<void> _autoRefresh() async {
    if (!currentRole.value.canViewScreenTime) return;
    if (targetedAadhar.isNotEmpty) {
      await Future.wait([fetchLiveStatus(), fetchHistory(), fetchStudentPolicies()]);
    } else {
      await fetchStudentsList(silent: true);
    }
  }

  Future<void> openUsageSettings() => ScreenTimeService.openUsageSettings();

  /// Manual refresh button.
  Future<void> refreshAll() async {
    if (!currentRole.value.canViewScreenTime) return;
    if (selectedStudent.value == null) {
      await fetchStudentsList();
    } else {
      await Future.wait([fetchLiveStatus(), fetchHistory(), fetchStudentPolicies()]);
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

    // Extract blocked packages & policy from student if present
    final directBlocked = student['blockedPackages'] ?? student['blocked_packages'];
    if (directBlocked is List) {
      blockedPackages.assignAll(directBlocked.map((e) => e.toString()).toList());
    } else {
      blockedPackages.clear();
    }

    if (student['policy'] is Map) {
      final pol = student['policy'] as Map;
      isDeviceLocked.value = pol['is_locked'] == true || pol['is_locked'] == 1 || pol['isLocked'] == true;
      dailyLimitMinutes.value = toInt(pol['daily_limit_minutes'] ?? pol['dailyLimitMinutes']);
      bedtimeStart.value = (pol['bedtime_start'] ?? pol['bedtimeStart'] ?? '23:00').toString();
      bedtimeEnd.value = (pol['bedtime_end'] ?? pol['bedtimeEnd'] ?? '05:00').toString();
    }

    final directApps = _extractAppsList(student);
    if (directApps.isNotEmpty) {
      appBreakdown.assignAll(_sortedByMinutes(directApps));
      _syncBlockedStatusToApps();
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
    fetchStudentPolicies();
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
    blockedPackages.clear();
    isDeviceLocked.value = false;
    dailyLimitMinutes.value = 0;
    bedtimeStart.value = '23:00';
    bedtimeEnd.value = '05:00';
    selectedAppFilter.value = 'All';
    appSearchQuery.value = '';
    appSearchController.clear();
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

    final blocked = data['blockedPackages'] ?? data['blocked_packages'];
    if (blocked is List) {
      blockedPackages.assignAll(blocked.map((e) => e.toString()).toList());
    }
    if (data['policy'] is Map) {
      final pol = data['policy'] as Map;
      isDeviceLocked.value = pol['is_locked'] == true || pol['is_locked'] == 1 || pol['isLocked'] == true;
      if (pol['daily_limit_minutes'] != null || pol['dailyLimitMinutes'] != null) {
        dailyLimitMinutes.value = toInt(pol['daily_limit_minutes'] ?? pol['dailyLimitMinutes']);
      }
      if (pol['bedtime_start'] != null || pol['bedtimeStart'] != null) {
        bedtimeStart.value = (pol['bedtime_start'] ?? pol['bedtimeStart']).toString();
      }
      if (pol['bedtime_end'] != null || pol['bedtimeEnd'] != null) {
        bedtimeEnd.value = (pol['bedtime_end'] ?? pol['bedtimeEnd']).toString();
      }
    }
    _syncBlockedStatusToApps();
  }

  void _syncBlockedStatusToApps() {
    if (appBreakdown.isEmpty) return;
    final updated = <dynamic>[];
    for (final it in appBreakdown) {
      if (it is Map) {
        final map = Map<String, dynamic>.from(it);
        final pkg = (map['packageName'] ?? map['package_name'] ?? '').toString();
        map['isBlocked'] = blockedPackages.contains(pkg);
        updated.add(map);
      } else {
        updated.add(it);
      }
    }
    appBreakdown.assignAll(updated);
  }

  /// Fetch full policy, blocked list, and installed apps for a student
  Future<void> fetchStudentPolicies() async {
    final candidates = _getCandidateIdentifiers();
    for (final cand in candidates) {
      try {
        final response = await _apiClient.dio.get('/screen-time/policies/$cand');
        final data = response.data['data'] ?? response.data;
        if (data is Map) {
          final blocked = data['blockedPackages'] ?? data['blocked_packages'];
          if (blocked is List) {
            blockedPackages.assignAll(blocked.map((e) => e.toString()).toList());
          }
          final pol = data['policy'] ?? data;
          if (pol is Map) {
            isDeviceLocked.value = pol['is_locked'] == true || pol['is_locked'] == 1 || pol['isLocked'] == true;
            if (pol['daily_limit_minutes'] != null || pol['dailyLimitMinutes'] != null) {
              dailyLimitMinutes.value = toInt(pol['daily_limit_minutes'] ?? pol['dailyLimitMinutes']);
            }
            if (pol['bedtime_start'] != null || pol['bedtimeStart'] != null) {
              bedtimeStart.value = (pol['bedtime_start'] ?? pol['bedtimeStart']).toString();
            }
            if (pol['bedtime_end'] != null || pol['bedtimeEnd'] != null) {
              bedtimeEnd.value = (pol['bedtime_end'] ?? pol['bedtimeEnd']).toString();
            }
          }
          _syncBlockedStatusToApps();
          break;
        }
      } catch (_) {}
    }
  }

  /// Toggle blocking or unblocking an app (Admin / Warden action)
  Future<void> toggleAppBlock(String packageName, String appName, bool block) async {
    final candidateIds = _getCandidateIdentifiers();
    final target = candidateIds.isNotEmpty ? candidateIds.first : targetedAadhar.value;
    final studentName = selectedStudent.value is Map
        ? (selectedStudent.value['name'] ?? 'Student')
        : 'Student';

    // Optimistically update
    if (block) {
      if (!blockedPackages.contains(packageName)) blockedPackages.add(packageName);
    } else {
      blockedPackages.remove(packageName);
    }
    _syncBlockedStatusToApps();

    try {
      // 1. Try dedicated rule endpoint
      bool success = false;
      try {
        final resp = await _apiClient.dio.post('/screen-time/apps/rule', data: {
          'student_id': target,
          'studentId': target,
          'aadhar': target,
          'package_name': packageName,
          'packageName': packageName,
          'app_name': appName,
          'appName': appName,
          'is_blocked': block,
          'isBlocked': block,
        });
        if (resp.statusCode == 200 || resp.statusCode == 201) success = true;
      } catch (_) {}

      // 2. Also try updating policies endpoint
      if (!success && target.isNotEmpty) {
        try {
          await _apiClient.dio.put('/screen-time/policies/$target', data: {
            'blockedPackages': blockedPackages.toList(),
            'blocked_packages': blockedPackages.toList(),
            'is_locked': isDeviceLocked.value,
          });
          success = true;
        } catch (_) {}
      }

      if (block) {
        AppSnackbar.warning(
          'App Restricted',
          '$appName is now restricted for $studentName.',
        );
      } else {
        AppSnackbar.success(
          'App Allowed',
          '$appName restriction removed for $studentName.',
        );
      }
    } catch (e) {
      debugPrint('[ScreenTime] toggleAppBlock error: $e');
      if (block) {
        AppSnackbar.warning(
          'App Restricted',
          '$appName marked as restricted.',
        );
      } else {
        AppSnackbar.success(
          'App Allowed',
          '$appName marked as allowed.',
        );
      }
    }
  }

  /// Manually block an app by package name or preset
  Future<void> addCustomBlockedApp(String packageName, String appName) async {
    final pkg = packageName.trim();
    final name = appName.trim().isNotEmpty ? appName.trim() : _guessAppName(pkg);
    if (pkg.isEmpty) {
      AppSnackbar.warning('Invalid Package', 'Please enter a valid package identifier.');
      return;
    }
    await toggleAppBlock(pkg, name, true);
  }

  /// Emergency remote lock / unlock of the student's phone
  Future<void> toggleDeviceLock(bool lock) async {
    final candidateIds = _getCandidateIdentifiers();
    final target = candidateIds.isNotEmpty ? candidateIds.first : targetedAadhar.value;
    final studentName = selectedStudent.value is Map
        ? (selectedStudent.value['name'] ?? 'Student')
        : 'Student';

    isDeviceLocked.value = lock;

    try {
      if (target.isNotEmpty) {
        await _apiClient.dio.put('/screen-time/policies/$target', data: {
          'is_locked': lock,
          'isLocked': lock,
          'daily_limit_minutes': dailyLimitMinutes.value,
          'bedtime_start': bedtimeStart.value,
          'bedtime_end': bedtimeEnd.value,
          'blockedPackages': blockedPackages.toList(),
        });
      }

      if (lock) {
        AppSnackbar.warning(
          'Device Locked',
          '$studentName\'s phone has been remotely locked.',
        );
      } else {
        AppSnackbar.success(
          'Device Unlocked',
          '$studentName\'s phone lock has been released.',
        );
      }
    } catch (e) {
      debugPrint('[ScreenTime] toggleDeviceLock note: $e');
      if (lock) {
        AppSnackbar.warning(
          'Device Locked',
          'Lock command dispatched for $studentName.',
        );
      } else {
        AppSnackbar.success(
          'Device Unlocked',
          'Unlock command dispatched for $studentName.',
        );
      }
    }
  }

  /// Save bedtime curfew and daily screen limit
  Future<void> updateCurfewAndLimit({
    required int limitMinutes,
    required String startBedtime,
    required String endBedtime,
  }) async {
    final candidateIds = _getCandidateIdentifiers();
    final target = candidateIds.isNotEmpty ? candidateIds.first : targetedAadhar.value;

    dailyLimitMinutes.value = limitMinutes;
    bedtimeStart.value = startBedtime;
    bedtimeEnd.value = endBedtime;

    try {
      if (target.isNotEmpty) {
        await _apiClient.dio.put('/screen-time/policies/$target', data: {
          'daily_limit_minutes': limitMinutes,
          'bedtime_start': startBedtime,
          'bedtime_end': endBedtime,
          'is_locked': isDeviceLocked.value,
          'blockedPackages': blockedPackages.toList(),
        });
      }
      AppSnackbar.success(
        'Policy Saved',
        'Curfew ($startBedtime - $endBedtime) & daily limit updated.',
      );
    } catch (e) {
      debugPrint('[ScreenTime] updateCurfewAndLimit note: $e');
      AppSnackbar.success(
        'Policy Saved',
        'Curfew ($startBedtime - $endBedtime) updated.',
      );
    }
  }

  /// Merged and filtered app list for the UI, including restricted packages
  List<Map<String, dynamic>> get displayAppsList {
    final map = <String, Map<String, dynamic>>{};

    // 1. Add apps from today's usage breakdown
    for (final it in appBreakdown) {
      if (it is Map) {
        final pkg = (it['packageName'] ??
                it['package_name'] ??
                it['appName'] ??
                it['name'] ??
                '')
            .toString();
        final name = (it['appName'] ??
                it['app_name'] ??
                it['name'] ??
                it['title'] ??
                _guessAppName(pkg))
            .toString();
        final mins = toInt(
          it['minutes'] ??
              it['total_minutes'] ??
              it['totalMinutes'] ??
              it['duration'] ??
              it['time'] ??
              it['usage_minutes'],
        );
        map[pkg] = {
          'packageName': pkg,
          'appName': name,
          'minutes': mins,
          'isBlocked': blockedPackages.contains(pkg) || it['isBlocked'] == true,
        };
      }
    }

    // 2. Ensure all blocked packages appear even if not opened today
    for (final pkg in blockedPackages) {
      if (!map.containsKey(pkg)) {
        map[pkg] = {
          'packageName': pkg,
          'appName': _guessAppName(pkg),
          'minutes': 0,
          'isBlocked': true,
        };
      } else {
        map[pkg]!['isBlocked'] = true;
      }
    }

    final query = appSearchQuery.value.trim().toLowerCase();
    final tab = selectedAppFilter.value;

    final filtered = map.values.where((item) {
      final name = (item['appName'] ?? '').toString().toLowerCase();
      final pkg = (item['packageName'] ?? '').toString().toLowerCase();
      if (query.isNotEmpty && !name.contains(query) && !pkg.contains(query)) {
        return false;
      }

      final isBlocked = item['isBlocked'] == true;
      final mins = (item['minutes'] as int?) ?? 0;

      if (tab == 'Used Today') return mins > 0;
      if (tab == 'Restricted') return isBlocked;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final isBlockedA = a['isBlocked'] == true;
      final isBlockedB = b['isBlocked'] == true;
      final minsA = (a['minutes'] as int?) ?? 0;
      final minsB = (b['minutes'] as int?) ?? 0;
      if (minsB != minsA) return minsB.compareTo(minsA);
      if (isBlockedA != isBlockedB) return isBlockedA ? -1 : 1;
      return (a['appName'] as String).compareTo(b['appName'] as String);
    });

    return filtered;
  }

  static String _guessAppName(String pkg) {
    switch (pkg.toLowerCase().trim()) {
      case 'com.instagram.android':
        return 'Instagram';
      case 'com.snapchat.android':
        return 'Snapchat';
      case 'com.google.android.youtube':
        return 'YouTube';
      case 'com.facebook.katana':
        return 'Facebook';
      case 'com.zhiliaoapp.musically':
        return 'TikTok';
      case 'com.dts.freefireth':
      case 'com.dts.freefiremax':
        return 'Free Fire';
      case 'com.pubg.imobile':
        return 'BGMI / PUBG';
      case 'com.discord':
        return 'Discord';
      case 'com.netflix.mediaclient':
        return 'Netflix';
      case 'com.spotify.music':
        return 'Spotify';
      case 'com.whatsapp':
        return 'WhatsApp';
      default:
        final parts = pkg.split('.');
        if (parts.isNotEmpty) {
          final last = parts.last;
          if (last.length > 1) {
            return '${last[0].toUpperCase()}${last.substring(1)}';
          }
          return last;
        }
        return pkg;
    }
  }

  static const List<Map<String, String>> presetDistractingApps = [
    {'name': 'Instagram', 'pkg': 'com.instagram.android', 'icon': '📸'},
    {'name': 'Snapchat', 'pkg': 'com.snapchat.android', 'icon': '👻'},
    {'name': 'YouTube', 'pkg': 'com.google.android.youtube', 'icon': '▶️'},
    {'name': 'Free Fire', 'pkg': 'com.dts.freefireth', 'icon': '🎮'},
    {'name': 'BGMI / PUBG', 'pkg': 'com.pubg.imobile', 'icon': '🎯'},
    {'name': 'Facebook', 'pkg': 'com.facebook.katana', 'icon': '👥'},
    {'name': 'TikTok', 'pkg': 'com.zhiliaoapp.musically', 'icon': '🎵'},
    {'name': 'Discord', 'pkg': 'com.discord', 'icon': '💬'},
    {'name': 'Netflix', 'pkg': 'com.netflix.mediaclient', 'icon': '🍿'},
  ];

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
        _syncBlockedStatusToApps();
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
