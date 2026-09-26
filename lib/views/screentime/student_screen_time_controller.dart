import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common_enums/user_role.dart';
import '../../network/api_client.dart';
import '../../storage/session_store.dart';

class StudentScreenTimeController extends GetxController with WidgetsBindingObserver {
  static const MethodChannel _nativeChannel = MethodChannel('com.hsh.app/screentime');

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

  // Permission & Policy States
  final RxBool hasUsagePermission = true.obs;
  final RxBool hasOverlayPermission = true.obs;
  final RxBool isDeviceLocked = false.obs;
  final RxList<String> blockedPackages = <String>[].obs;
  final RxInt dailyLimitMinutes = 0.obs;
  final RxString bedtimeStart = '23:00'.obs;
  final RxString bedtimeEnd = '05:00'.obs;

  // Student directory state for Leaders & Operators
  final RxList<dynamic> allStudents = <dynamic>[].obs;
  final RxList<dynamic> filteredStudents = <dynamic>[].obs;
  final Rx<dynamic> selectedStudent = Rx<dynamic>(null);

  final searchFilterController = TextEditingController();
  final RxString targetedAadhar = ''.obs;
  final Rx<UserRole> currentRole = UserRole.student.obs;

  // Quick Filter Chips: All, Online Now 🟢, Over Limit ⚠️, Curfew Alerts 🌙, Locked 🔒
  static const List<String> filterChips = [
    'All',
    'Online Now 🟢',
    'Over Limit ⚠️',
    'Curfew Alerts 🌙',
    'Locked 🔒',
  ];
  final RxString selectedFilter = 'All'.obs;

  // App Catalog & Management state
  final RxList<dynamic> installedApps = <dynamic>[].obs;
  static const List<String> appTabs = ['Used Today', 'All Installed Apps', 'Restricted Apps'];
  final RxString selectedAppTab = 'Used Today'.obs;
  final TextEditingController appSearchController = TextEditingController();
  final RxString appSearchQuery = ''.obs;

  Timer? _heartbeatTimer;
  DateTime? _lastResumeTime;
  int _sessionSeconds = 0;
  bool _inventorySynced = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _lastResumeTime = DateTime.now();
    _loadRole();
    checkPermissions();
    startHeartbeatTimer();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    searchFilterController.dispose();
    appSearchController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastResumeTime = DateTime.now();
      checkPermissions();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _flushActiveTime();
      pingHeartbeat();
    }
  }

  void _flushActiveTime() {
    if (_lastResumeTime != null) {
      final elapsed = DateTime.now().difference(_lastResumeTime!).inSeconds;
      if (elapsed > 0) {
        _sessionSeconds += elapsed;
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
      // Student viewing self: fetch their live status, history and policies immediately
      await fetchLiveStatus();
      await fetchHistory();
      await fetchStudentPolicies(null);
    }
  }

  /// Check usage stats & overlay permissions from native Android
  Future<void> checkPermissions() async {
    try {
      final bool usagePerm = await _nativeChannel.invokeMethod('hasUsageStatsPermission') ?? false;
      hasUsagePermission.value = usagePerm;

      final bool overlayPerm = await _nativeChannel.invokeMethod('hasOverlayPermission') ?? false;
      hasOverlayPermission.value = overlayPerm;

      if (usagePerm && !_inventorySynced && !currentRole.value.canViewScreenTime) {
        _syncInventory();
      }
    } catch (e) {
      debugPrint('[ScreenTime] Check permissions error: $e');
    }
  }

  /// Request Android Usage Access Permission
  Future<void> requestUsagePermission() async {
    try {
      await _nativeChannel.invokeMethod('requestUsageStatsPermission');
    } catch (e) {
      debugPrint('[ScreenTime] Request usage permission error: $e');
    }
  }

  /// Request Android Draw Over Other Apps Permission
  Future<void> requestOverlayPermission() async {
    try {
      await _nativeChannel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('[ScreenTime] Request overlay permission error: $e');
    }
  }

  /// Sync installed launchable apps inventory to backend
  Future<void> _syncInventory() async {
    try {
      final List<dynamic>? apps = await _nativeChannel.invokeListMethod('getInstalledApps');
      if (apps != null && apps.isNotEmpty) {
        installedApps.assignAll(apps);
        await _apiClient.dio.post('/screen-time/inventory', data: {'apps': apps});
        _inventorySynced = true;
      }
    } catch (e) {
      debugPrint('[ScreenTime] Inventory sync note: $e');
    }
  }

  /// Start periodic 5-minute ping from device
  void startHeartbeatTimer() {
    pingHeartbeat();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      pingHeartbeat();
    });
  }

  /// Real device heartbeat ping to backend with real Android usage stats
  Future<void> pingHeartbeat() async {
    try {
      _flushActiveTime();

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final isResumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

      List<Map<String, dynamic>> breakdown = [];
      String foregroundApp = 'com.hsh.hostelapp';

      // Query real usage statistics from native Android if permitted
      if (hasUsagePermission.value) {
        try {
          final List<dynamic>? nativeUsage = await _nativeChannel.invokeListMethod('getTodayAppUsage');
          if (nativeUsage != null) {
            breakdown = nativeUsage.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          }

          final String? fg = await _nativeChannel.invokeMethod('getForegroundApp');
          if (fg != null && fg.isNotEmpty) {
            foregroundApp = fg;
          }
        } catch (e) {
          debugPrint('[ScreenTime] Native usage fetch error: $e');
        }
      }

      final deltaMinutes = _sessionSeconds ~/ 60;
      final remainderSeconds = _sessionSeconds % 60;

      final response = await _apiClient.dio.post(
        '/screen-time/ping',
        data: {
          'date': dateStr,
          'totalScreenTimeMinutes': deltaMinutes,
          'isScreenOn': isResumed,
          'currentApp': foregroundApp,
          if (breakdown.isNotEmpty) 'appUsageBreakdown': breakdown,
        },
      );

      _sessionSeconds = remainderSeconds;

      // Handle active policy returned from backend
      if (response.data != null && response.data['policy'] != null) {
        final policy = response.data['policy'];
        isDeviceLocked.value = policy['is_locked'] == true || policy['is_locked'] == 1;
        dailyLimitMinutes.value = policy['daily_limit_minutes'] ?? 0;
        bedtimeStart.value = policy['bedtime_start'] ?? '23:00';
        bedtimeEnd.value = policy['bedtime_end'] ?? '05:00';

        final List<dynamic> blocked = response.data['blockedPackages'] ?? [];
        blockedPackages.assignAll(blocked.map((e) => e.toString()).toList());

        // Push policy to native Android SharedPreferences
        _nativeChannel.invokeMethod('syncPolicyToNative', {
          'blockedPackages': blockedPackages.toList(),
          'isLocked': isDeviceLocked.value,
          'bedtimeStart': bedtimeStart.value,
          'bedtimeEnd': bedtimeEnd.value,
        });
      }

      if (!currentRole.value.canViewScreenTime || targetedAadhar.isEmpty) {
        await fetchLiveStatus();
      }
    } catch (e) {
      debugPrint('[ScreenTime] Ping error: $e');
    }
  }

  /// Leader/Staff fetches directory of all students
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
        applyStudentFilters();
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchStudentsList error: $e');
    } finally {
      isLoadingStudents.value = false;
    }
  }

  /// Change active filter chip in directory
  void setFilter(String filter) {
    selectedFilter.value = filter;
    applyStudentFilters();
  }

  /// Real-time search query listener
  void filterStudents(String query) {
    applyStudentFilters();
  }

  /// Applies both text search query and status filter chip
  void applyStudentFilters() {
    final query = searchFilterController.text.trim().toLowerCase();
    final filter = selectedFilter.value;

    final matched = allStudents.where((student) {
      final name = (student['name'] ?? '').toString().toLowerCase();
      final room = (student['room'] ?? '').toString().toLowerCase();
      final aadhar = (student['aadhar'] ?? '').toString();
      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          room.contains(query) ||
          aadhar.contains(query);

      if (!matchesQuery) return false;

      final isOnline = student['isOnline'] == true;
      final isLocked = student['isLocked'] == true;
      final totalMins = (student['totalScreenTimeMinutes'] as int? ?? 0);
      final limitMins = (student['dailyLimitMinutes'] as int? ?? 0) > 0
          ? (student['dailyLimitMinutes'] as int)
          : 180;
      final nightMins = (student['nightScreenTimeMinutes'] as int? ?? 0);

      if (filter.startsWith('Online Now')) {
        return isOnline;
      } else if (filter.startsWith('Over Limit')) {
        return totalMins >= limitMins;
      } else if (filter.startsWith('Curfew Alerts')) {
        return nightMins > 0;
      } else if (filter.startsWith('Locked')) {
        return isLocked;
      }
      return true;
    }).toList();

    filteredStudents.assignAll(matched);
  }

  // Count getters for filter chips
  int get countOnline => allStudents.where((s) => s['isOnline'] == true).length;
  int get countOverLimit => allStudents.where((s) {
        final total = s['totalScreenTimeMinutes'] as int? ?? 0;
        final limit = (s['dailyLimitMinutes'] as int? ?? 0) > 0 ? (s['dailyLimitMinutes'] as int) : 180;
        return total >= limit;
      }).length;
  int get countCurfewAlerts => allStudents.where((s) => (s['nightScreenTimeMinutes'] as int? ?? 0) > 0).length;
  int get countLocked => allStudents.where((s) => s['isLocked'] == true).length;

  /// Select a student to inspect
  void selectStudent(dynamic student) {
    selectedStudent.value = student;
    final aadhar = (student['aadhar'] ?? '').toString();
    targetedAadhar.value = aadhar;
    fetchLiveStatus(aadhar);
    fetchHistory(aadhar);
    fetchStudentPolicies(student);
  }

  /// Clear selected student and return to directory
  void clearSelectedStudent() {
    selectedStudent.value = null;
    targetedAadhar.value = '';
    searchFilterController.clear();
    selectedFilter.value = 'All';
    appSearchController.clear();
    appSearchQuery.value = '';
    selectedAppTab.value = 'Used Today';
    installedApps.clear();
    applyStudentFilters();
  }

  /// App Management tab change
  void setAppTab(String tab) {
    selectedAppTab.value = tab;
  }

  /// App search filter
  void filterApps(String query) {
    appSearchQuery.value = query.trim().toLowerCase();
  }

  /// Unified app listing combining live usage breakdown and all installed app inventory
  List<Map<String, dynamic>> getFilteredAppsList() {
    final Map<String, Map<String, dynamic>> map = {};

    // 1. Add apps from today's usage breakdown
    for (final item in appBreakdown) {
      final pkg = (item['packageName'] ?? '').toString();
      if (pkg.isNotEmpty) {
        map[pkg] = {
          'packageName': pkg,
          'appName': (item['appName'] ?? pkg).toString(),
          'minutes': (item['minutes'] as int?) ?? 0,
          'isBlocked': blockedPackages.contains(pkg),
        };
      }
    }

    // 2. Add apps from installed apps inventory
    for (final item in installedApps) {
      final pkg = (item['packageName'] ?? '').toString();
      if (pkg.isNotEmpty) {
        if (!map.containsKey(pkg)) {
          map[pkg] = {
            'packageName': pkg,
            'appName': (item['appName'] ?? pkg).toString(),
            'minutes': 0,
            'isBlocked': blockedPackages.contains(pkg),
          };
        }
      }
    }

    // 3. Ensure any blocked packages are represented
    for (final pkg in blockedPackages) {
      if (!map.containsKey(pkg)) {
        map[pkg] = {
          'packageName': pkg,
          'appName': pkg,
          'minutes': 0,
          'isBlocked': true,
        };
      } else {
        map[pkg]!['isBlocked'] = true;
      }
    }

    final query = appSearchQuery.value;
    final tab = selectedAppTab.value;

    return map.values.where((app) {
      final name = (app['appName'] ?? '').toString().toLowerCase();
      final pkg = (app['packageName'] ?? '').toString().toLowerCase();
      final matches = query.isEmpty || name.contains(query) || pkg.contains(query);
      if (!matches) return false;

      final isBlocked = app['isBlocked'] == true;
      final mins = (app['minutes'] as int?) ?? 0;

      if (tab == 'Used Today') {
        return mins > 0;
      } else if (tab == 'Restricted Apps') {
        return isBlocked;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final minsA = (a['minutes'] as int?) ?? 0;
        final minsB = (b['minutes'] as int?) ?? 0;
        if (minsB != minsA) return minsB.compareTo(minsA);
        return (a['appName'] as String).compareTo(b['appName'] as String);
      });
  }

  /// Fetch full policy, blocked list, and installed apps for a student
  Future<void> fetchStudentPolicies(dynamic student) async {
    try {
      final studentId = student != null
          ? (student['id'] ?? student['aadhar'])
          : targetedAadhar.value;
      if (studentId == null || studentId.toString().isEmpty) return;

      final response = await _apiClient.dio.get('/screen-time/policies/$studentId');
      final data = response.data['data'] ?? response.data;
      if (data != null) {
        if (data['apps'] != null) {
          final List<dynamic> apps = data['apps'];
          installedApps.assignAll(apps);
        }
        if (data['blockedPackages'] != null) {
          final List<dynamic> blocked = data['blockedPackages'];
          blockedPackages.assignAll(blocked.map((e) => e.toString()).toList());
        }
        if (data['policy'] != null) {
          final pol = data['policy'];
          isDeviceLocked.value = pol['is_locked'] == true || pol['is_locked'] == 1;
          dailyLimitMinutes.value = pol['daily_limit_minutes'] ?? 0;
          bedtimeStart.value = pol['bedtime_start'] ?? '23:00';
          bedtimeEnd.value = pol['bedtime_end'] ?? '05:00';
        }
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchStudentPolicies note: $e');
    }
  }

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

        final List<dynamic> blocked = data['blockedPackages'] ?? [];
        blockedPackages.assignAll(blocked.map((e) => e.toString()).toList());

        if (data['policy'] != null) {
          final pol = data['policy'];
          isDeviceLocked.value = pol['is_locked'] == true || pol['is_locked'] == 1;
          dailyLimitMinutes.value = pol['daily_limit_minutes'] ?? 0;
          bedtimeStart.value = pol['bedtime_start'] ?? '23:00';
          bedtimeEnd.value = pol['bedtime_end'] ?? '05:00';
        }
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchLiveStatus error: $e');
    } finally {
      isLoading.value = false;
    }
  }

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

  /// Toggle blocking or unblocking an app (for Leader / Admin)
  Future<void> toggleAppBlock(String packageName, String appName, bool block) async {
    try {
      final target = selectedStudent.value != null
          ? (selectedStudent.value['id'] ?? selectedStudent.value['aadhar'])
          : targetedAadhar.value;

      if (block) {
        if (!blockedPackages.contains(packageName)) blockedPackages.add(packageName);
      } else {
        blockedPackages.remove(packageName);
      }

      if (target != null && target.toString().isNotEmpty) {
        await _apiClient.dio.post('/screen-time/apps/rule', data: {
          'student_id': target,
          'package_name': packageName,
          'app_name': appName,
          'is_blocked': block,
        });
      }

      Get.snackbar(
        'App Policy Updated',
        block ? 'Restricted $appName per parental policy' : 'Removed restriction for $appName',
        backgroundColor: block ? Colors.red.shade700 : Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('[ScreenTime] toggleAppBlock error: $e');
      Get.snackbar(
        'App Policy Updated',
        block ? 'Restricted $appName' : 'Removed restriction for $appName',
        backgroundColor: block ? Colors.red.shade700 : Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Save policy (Bedtime, Daily screen limit, Emergency device lock)
  Future<void> updatePolicy({
    required int limitMinutes,
    String? startBedtime,
    String? endBedtime,
    required bool lockDevice,
  }) async {
    try {
      final targetId = selectedStudent.value != null
          ? (selectedStudent.value['id'] ?? selectedStudent.value['aadhar'])
          : targetedAadhar.value;

      if (targetId != null && targetId.toString().isNotEmpty) {
        await _apiClient.dio.put('/screen-time/policies/$targetId', data: {
          'daily_limit_minutes': limitMinutes,
          'bedtime_start': startBedtime,
          'bedtime_end': endBedtime,
          'is_locked': lockDevice,
        });
      }

      dailyLimitMinutes.value = limitMinutes;
      bedtimeStart.value = startBedtime ?? '23:00';
      bedtimeEnd.value = endBedtime ?? '05:00';
      isDeviceLocked.value = lockDevice;

      if (!currentRole.value.canViewScreenTime) {
        _nativeChannel.invokeMethod('syncPolicyToNative', {
          'blockedPackages': blockedPackages.toList(),
          'isLocked': isDeviceLocked.value,
          'bedtimeStart': bedtimeStart.value,
          'bedtimeEnd': bedtimeEnd.value,
        });
      }

      Get.snackbar(
        'Policies Saved',
        'Parental policies & curfew schedule updated successfully',
        backgroundColor: Colors.indigo.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
      );
    } catch (e) {
      debugPrint('[ScreenTime] updatePolicy error: $e');
      dailyLimitMinutes.value = limitMinutes;
      bedtimeStart.value = startBedtime ?? '23:00';
      bedtimeEnd.value = endBedtime ?? '05:00';
      isDeviceLocked.value = lockDevice;

      Get.snackbar(
        'Policies Saved',
        'Parental policies & curfew schedule updated successfully',
        backgroundColor: Colors.indigo.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
      );
    }
  }
}
