import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/models/geofence/geofence_policy_model.dart';
import '../../../core/network/repository/geofence/geofence_repository.dart';
import '../models/screen_time_policy.dart';
import '../services/app_icon_cache.dart';

/// Screen-time and Parental Control controller for Administrators.
///
/// Restricted to Admin / Warden roles. Allows monitoring student phone telemetry,
/// inspecting live app usage, blocking distracting apps remotely, locking devices,
/// and setting bedtime curfews.
class StudentScreenTimeController extends GetxController with WidgetsBindingObserver {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final GeofenceRepository _geofenceRepo = GeofenceRepository();

  /// Hostel-wide curfew policy (enforced natively on student phones).
  final Rx<GeofencePolicyModel> globalCurfewPolicy = const GeofencePolicyModel().obs;
  final RxBool isLoadingCurfew = false.obs;
  final RxBool isUpdatingCurfew = false.obs;

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

  /// When the student's phone last reported in, and what it reported about
  /// its own monitoring health (Usage Access / Accessibility / battery).
  final Rx<DateTime?> lastSeenAt = Rx<DateTime?>(null);
  final RxMap<String, dynamic> compliance = <String, dynamic>{}.obs;
  /// Package of the foreground app (for its icon); [currentApp] is the label.
  final RxString currentPackage = ''.obs;

  /// Monitoring on the selected student's phone has been switched off.
  bool get isTampered => isStudentTampered({'compliance': compliance});

  /// Share of the daily allowance used on the selected day (0 when unlimited).
  double get limitProgress => dailyLimitMinutes.value > 0
      ? (selectedDayTotalMinutes / dailyLimitMinutes.value).clamp(0.0, 1.0)
      : 0.0;

  // Directory quick filter: All / Online / Locked / Restricted / Night / Attention
  final RxString directoryFilter = 'All'.obs;
  static const directoryFilters = ['All', 'Online', 'Locked', 'Restricted', 'Night', 'Attention'];

  void setDirectoryFilter(String filter) {
    directoryFilter.value = filter;
    filterStudents(searchFilterController.text);
  }

  int directoryCount(String filter) =>
      allStudents.where((s) => _matchesDirectoryFilter(s, filter)).length;

  static bool _matchesDirectoryFilter(dynamic s, String filter) {
    switch (filter) {
      case 'Online':
        return s is Map && s['isOnline'] == true;
      case 'Locked':
        return isStudentLocked(s);
      case 'Restricted':
        return isStudentRestricted(s);
      case 'Night':
        return s is Map && toInt(s['nightScreenTimeMinutes'] ?? s['night_screen_time_minutes']) > 0;
      case 'Attention':
        return isStudentTampered(s) || isStudentLocked(s);
      default:
        return true;
    }
  }

  // ---------- Student-row helpers (directory entries are raw API maps) ----------

  static Map<String, dynamic>? complianceOf(dynamic s) =>
      s is Map && s['compliance'] is Map ? Map<String, dynamic>.from(s['compliance']) : null;

  static bool isStudentTampered(dynamic s) {
    final c = complianceOf(s);
    if (c == null || c.isEmpty) return false;
    return c['usageAccess'] == false || c['accessibilityEnabled'] == false;
  }

  static bool isStudentLocked(dynamic s) {
    if (s is! Map) return false;
    final pol = s['policy'] is Map ? s['policy'] as Map : s;
    return pol['is_locked'] == true || pol['isLocked'] == true || pol['is_locked'] == 1;
  }

  static List<String> blockedOf(dynamic s) {
    if (s is! Map) return const [];
    final pol = s['policy'] is Map ? s['policy'] as Map : const {};
    final raw = s['blockedPackages'] ?? s['blocked_packages'] ?? pol['blockedPackages'] ?? pol['blocked_packages'];
    return raw is List ? raw.map((e) => e.toString()).toList() : const [];
  }

  static bool isStudentRestricted(dynamic s) => blockedOf(s).isNotEmpty;

  static DateTime? lastSeenOf(dynamic s) {
    if (s is! Map) return null;
    final raw = s['lastSeenAt'] ?? s['lastSeen'] ?? s['last_seen'] ?? s['lastPing'] ?? s['last_ping'] ?? s['updatedAt'];
    if (raw == null) return null;
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw > 1e12 ? raw.toInt() : raw.toInt() * 1000);
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  /// "just now", "4 min ago", "3 h ago", "2 d ago".
  static String relativeTime(DateTime t) => DateFormatting.relativeTime(t);

  static String formatMinutes(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  // Day-wise selection state
  final RxString selectedDate = ''.obs; // 'yyyy-MM-dd' or empty for today

  String get todayDateStr {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get isTodaySelected {
    return selectedDate.value.isEmpty || selectedDate.value == todayDateStr;
  }

  String get effectiveSelectedDate {
    return selectedDate.value.isEmpty ? todayDateStr : selectedDate.value;
  }

  void selectDate(String dateStr) {
    selectedDate.value = dateStr;
  }

  List<Map<String, String>> get availableDays {
    final list = <Map<String, String>>[];
    final now = DateTime.now();
    final today = todayDateStr;
    final yest = now.subtract(const Duration(days: 1));
    final yestStr = '${yest.year.toString().padLeft(4, '0')}-${yest.month.toString().padLeft(2, '0')}-${yest.day.toString().padLeft(2, '0')}';

    list.add({'date': today, 'label': 'Today'});

    final seenDates = {today};
    for (final r in historyRecords) {
      if (r is Map) {
        final raw = (r['date'] ?? r['day'] ?? r['createdAt'] ?? '').toString();
        final d = raw.split('T').first.trim();
        if (d.isNotEmpty && !seenDates.contains(d)) {
          seenDates.add(d);
          if (d == yestStr) {
            list.add({'date': d, 'label': 'Yesterday'});
          } else {
            try {
              final parsed = DateTime.parse(d);
              final label = DateFormat('EEE, d MMM').format(parsed);
              list.add({'date': d, 'label': label});
            } catch (_) {
              list.add({'date': d, 'label': d});
            }
          }
        }
      }
    }
    return list;
  }

  static const _ownPackage = 'com.example.hsh_app2';
  bool _isOurApp(String pkg) => pkg == _ownPackage;

  int get selectedDayTotalMinutes {
    // 1. If we have the app list for the selected day, sum the actual tracked apps (excluding our own app)
    final apps = currentDayRawApps;
    if (apps.isNotEmpty) {
      final sum = apps.fold<int>(0, (acc, item) {
        if (item is Map) {
          final pkg = (item['packageName'] ?? item['package_name'] ?? '').toString();
          if (_isOurApp(pkg)) return acc;
          return acc +
              toInt(
                item['minutes'] ??
                    item['total_minutes'] ??
                    item['totalMinutes'] ??
                    item['duration'] ??
                    item['time'] ??
                    item['usage_minutes'],
              );
        }
        return acc;
      });
      if (sum > 0) return sum;
    }

    if (isTodaySelected) {
      return totalMinutesToday.value;
    }

    final rec = _findHistoryRecord(selectedDate.value);
    if (rec != null) {
      return toInt(
        rec['total_screen_time_minutes'] ??
            rec['totalScreenTimeMinutes'] ??
            rec['totalMinutes'] ??
            rec['total_minutes'] ??
            rec['minutes'] ??
            rec['usage_minutes'],
      );
    }
    return 0;
  }

  int get selectedDayNightMinutes {
    if (isTodaySelected) {
      return nightMinutesToday.value;
    }
    final rec = _findHistoryRecord(selectedDate.value);
    if (rec != null) {
      return toInt(
        rec['night_screen_time_minutes'] ??
            rec['nightScreenTimeMinutes'] ??
            rec['nightMinutes'] ??
            rec['night_minutes'] ??
            rec['night'],
      );
    }
    return 0;
  }

  Map<String, dynamic>? _findHistoryRecord(String dateStr) {
    for (final r in historyRecords) {
      if (r is Map) {
        final raw = (r['date'] ?? r['day'] ?? r['createdAt'] ?? '').toString();
        final d = raw.split('T').first.trim();
        if (d == dateStr || d.startsWith(dateStr) || dateStr.startsWith(d)) {
          return Map<String, dynamic>.from(r);
        }
      }
    }
    return null;
  }

  List<dynamic> get currentDayRawApps {
    if (isTodaySelected) {
      return appBreakdown;
    }
    final rec = _findHistoryRecord(selectedDate.value);
    if (rec != null) {
      final extracted = _extractAppsList(rec);
      if (extracted.isNotEmpty) {
        return extracted.where((a) {
          final pkg = (a is Map ? (a['packageName'] ?? a['package_name'] ?? '') : '').toString();
          return !_isOurApp(pkg);
        }).toList();
      }
    }
    return [];
  }

  // -------------------------------------------------------------
  // Analytics & Graph Data
  // -------------------------------------------------------------

  /// 7-day chronological usage points for trend graphs
  List<Map<String, dynamic>> get trendGraphPoints {
    final list = <Map<String, dynamic>>[];
    final now = DateTime.now();

    // Map existing history records by yyyy-MM-dd
    final mapByDate = <String, Map<String, dynamic>>{};
    for (final r in historyRecords) {
      if (r is Map) {
        final raw = (r['date'] ?? r['day'] ?? r['createdAt'] ?? '').toString();
        final d = raw.split('T').first.trim();
        if (d.isNotEmpty) {
          mapByDate[d] = Map<String, dynamic>.from(r);
        }
      }
    }

    final today = todayDateStr;
    mapByDate[today] = {
      'date': today,
      'totalMinutes': totalMinutesToday.value,
      'nightMinutes': nightMinutesToday.value,
    };

    // Build the last 7 calendar days in chronological order (Oldest -> Today)
    for (int i = 6; i >= 0; i--) {
      final dt = now.subtract(Duration(days: i));
      final dStr = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final rec = mapByDate[dStr];

      int total = 0;
      int night = 0;

      if (dStr == today) {
        total = totalMinutesToday.value;
        night = nightMinutesToday.value;
      } else if (rec != null) {
        final apps = _extractAppsList(rec);
        if (apps.isNotEmpty) {
          total = apps.fold<int>(0, (sum, a) {
            final pkg = (a is Map ? (a['packageName'] ?? a['package_name'] ?? '') : '').toString();
            if (_isOurApp(pkg)) return sum;
            return sum + toInt(a['minutes'] ?? a['total_minutes'] ?? a['totalMinutes'] ?? a['duration'] ?? a['time']);
          });
        }
        if (total == 0) {
          total = toInt(rec['total_screen_time_minutes'] ?? rec['totalScreenTimeMinutes'] ?? rec['totalMinutes'] ?? rec['minutes']);
        }
        night = toInt(rec['night_screen_time_minutes'] ?? rec['nightScreenTimeMinutes'] ?? rec['nightMinutes'] ?? rec['night']);
      }

      final dayLabel = DateFormat('E').format(dt); // e.g. Mon, Tue
      final shortDate = DateFormat('d MMM').format(dt); // e.g. 29 Sep

      final double hVal = total / 60.0;
      final double nVal = night / 60.0;
      final bool isSel = dStr == effectiveSelectedDate;

      list.add({
        'date': dStr,
        'dayLabel': dayLabel,
        'shortDate': shortDate,
        'dateLabel': shortDate,
        'totalMinutes': total,
        'nightMinutes': night,
        'isToday': dStr == today,
        'isSelected': isSel,
        'hours': hVal,
        'nightHours': nVal,
        'hoursFormatted': hVal.toStringAsFixed(1),
      });
    }

    return list;
  }

  /// Average daily screen time minutes across the tracked trend period
  int get averageDailyMinutes {
    final pts = trendGraphPoints;
    final nonZero = pts.where((p) => (p['totalMinutes'] as int) > 0).toList();
    if (nonZero.isEmpty) return selectedDayTotalMinutes;
    final sum = nonZero.fold<int>(0, (acc, p) => acc + (p['totalMinutes'] as int));
    return sum ~/ nonZero.length;
  }

  /// Categorizes applications into student focus groups
  static String categorizeApp(String pkg, String name) {
    final p = pkg.toLowerCase();
    final n = name.toLowerCase();
    if (p.contains('instagram') ||
        p.contains('snapchat') ||
        p.contains('facebook') ||
        p.contains('whatsapp') ||
        p.contains('telegram') ||
        p.contains('discord') ||
        p.contains('reddit') ||
        p.contains('twitter') ||
        p.contains('musically') ||
        p.contains('tiktok') ||
        n.contains('insta') ||
        n.contains('chat') ||
        n.contains('social')) {
      return 'Social Media';
    }
    if (p.contains('youtube') ||
        p.contains('netflix') ||
        p.contains('videolan') ||
        p.contains('vlc') ||
        p.contains('spotify') ||
        p.contains('hotstar') ||
        p.contains('primevideo') ||
        n.contains('video') ||
        n.contains('movie') ||
        n.contains('music')) {
      return 'Entertainment';
    }
    if (p.contains('pubg') ||
        p.contains('freefire') ||
        p.contains('dts') ||
        p.contains('game') ||
        p.contains('supercell') ||
        p.contains('roblox') ||
        p.contains('candycrush') ||
        n.contains('game') ||
        n.contains('battle') ||
        n.contains('fire')) {
      return 'Gaming';
    }
    if (p.contains('chrome') ||
        p.contains('classroom') ||
        p.contains('docs') ||
        p.contains('drive') ||
        p.contains('pdf') ||
        p.contains('calculator') ||
        p.contains('notes') ||
        p.contains('wiki') ||
        n.contains('study') ||
        n.contains('class') ||
        n.contains('learn')) {
      return 'Study & Tools';
    }
    return 'Other';
  }

  /// Breakdown of minutes grouped by application category for the selected day
  Map<String, int> get categoryMinutes {
    final result = <String, int>{
      'Social Media': 0,
      'Entertainment': 0,
      'Gaming': 0,
      'Study & Tools': 0,
      'Other': 0,
    };
    for (final it in displayAppsList) {
      final pkg = (it['packageName'] ?? '').toString();
      final name = (it['appName'] ?? '').toString();
      final mins = (it['minutes'] as int?) ?? 0;
      if (mins > 0) {
        final cat = categorizeApp(pkg, name);
        result[cat] = (result[cat] ?? 0) + mins;
      }
    }
    return result;
  }

  /// Hostel Digital Focus & Health score (0% to 100%)
  int get complianceScore {
    final total = selectedDayTotalMinutes;
    final night = selectedDayNightMinutes;
    final limit = dailyLimitMinutes.value;

    int score = 95;
    if (night > 0) score -= (night * 0.8).round().clamp(10, 30);
    if (limit > 0 && total > limit) {
      final over = total - limit;
      score -= (over * 0.5).round().clamp(10, 35);
    }
    final cat = categoryMinutes;
    final distracting = (cat['Social Media'] ?? 0) + (cat['Gaming'] ?? 0);
    if (total > 0 && (distracting / total) > 0.6) {
      score -= 15;
    }
    return score.clamp(30, 100);
  }



  // Parental Control & App Blocking state
  final RxList<String> blockedPackages = <String>[].obs;
  final RxBool isDeviceLocked = false.obs;
  final RxInt dailyLimitMinutes = 0.obs;
  /// "HH:mm"; both empty = no bedtime curfew for this student.
  final RxString bedtimeStart = ''.obs;
  final RxString bedtimeEnd = ''.obs;
  final RxString policyVersion = ''.obs;

  /// The selected student's policy as currently shown in the UI.
  ScreenTimePolicy get currentPolicy => ScreenTimePolicy(
        isLocked: isDeviceLocked.value,
        blockedPackages: blockedPackages.toSet(),
        dailyLimitMinutes: dailyLimitMinutes.value,
        bedtimeStart: bedtimeStart.value,
        bedtimeEnd: bedtimeEnd.value,
        version: policyVersion.value,
      );

  void _applyPolicy(ScreenTimePolicy p) {
    isDeviceLocked.value = p.isLocked;
    blockedPackages.assignAll(p.blockedPackages.toList());
    dailyLimitMinutes.value = p.dailyLimitMinutes;
    bedtimeStart.value = p.bedtimeStart;
    bedtimeEnd.value = p.bedtimeEnd;
    policyVersion.value = p.version;
    _syncBlockedStatusToApps();
  }

  /// Numeric `students.id` of the selected student (from the directory) — the
  /// only identifier ever sent to the API. Bank codes are never used: they
  /// are numeric too, so the API would read "0768" as student #768.
  String get _studentId {
    final s = selectedStudent.value;
    if (s is! Map) return '';
    final id = (s['id'] ?? s['_id'] ?? '').toString().trim();
    return _isStudentId(id) ? id : '';
  }

  static final _studentIdPattern = RegExp(r'^[1-9]\d*$');
  static bool _isStudentId(String value) => _studentIdPattern.hasMatch(value);
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

  /// True if another screen opened this one for one specific student (by id).
  final RxBool openedWithDirectTarget = false.obs;

  final searchFilterController = TextEditingController();
  final RxString searchText = ''.obs;
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

  /// Another screen opened this one. With a numeric student id (`id` or
  /// `studentId`) that student is opened directly. Without one — e.g. from
  /// the phonebook, whose records have no `students.id` — the directory opens
  /// searched by name and the warden picks the student, so nothing is ever
  /// guessed from a bank code or name.
  void _checkInitialArguments() {
    final args = Get.arguments;
    if (args is! Map) return;
    final map = Map<String, dynamic>.from(args);
    final name = (map['name'] ?? map['fullName'] ?? '').toString().trim();
    final room = (map['room'] ?? '').toString().trim();
    final id = (map['id'] ?? map['studentId'] ?? '').toString().trim();

    if (_isStudentId(id)) {
      openedWithDirectTarget.value = true;
      selectStudent({
        'id': id,
        'name': name.isNotEmpty ? name : 'Student',
        'room': room.isNotEmpty ? room : 'N/A',
      });
      return;
    }

    if (name.isNotEmpty) {
      searchFilterController.text = name;
      searchText.value = name;
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

    await Future.wait([
      fetchStudentsList(),
      loadGlobalCurfew(),
    ]);
  }

  Future<void> _autoRefresh() async {
    if (!currentRole.value.canViewScreenTime) return;
    if (_studentId.isNotEmpty) {
      await Future.wait([fetchLiveStatus(), fetchHistory(), fetchStudentPolicies()]);
    } else {
      await Future.wait([
        fetchStudentsList(silent: true),
        loadGlobalCurfew(),
      ]);
    }
  }

  Future<void> openUsageSettings() => ScreenTimeService.openUsageSettings();

  /// Manual refresh button.
  Future<void> refreshAll() async {
    if (!currentRole.value.canViewScreenTime) return;
    if (selectedStudent.value == null) {
      await Future.wait([
        fetchStudentsList(),
        loadGlobalCurfew(),
      ]);
    } else {
      await Future.wait([fetchLiveStatus(), fetchHistory(), fetchStudentPolicies()]);
    }
  }

  /// Load hostel-wide curfew policy (night curfew window & active status).
  Future<void> loadGlobalCurfew() async {
    if (!currentRole.value.canViewScreenTime) return;
    isLoadingCurfew.value = true;
    try {
      final policy = await _geofenceRepo.fetchPolicy();
      globalCurfewPolicy.value = policy;
    } catch (e) {
      debugPrint('[ScreenTime] loadGlobalCurfew error: $e');
    } finally {
      isLoadingCurfew.value = false;
    }
  }

  /// Turn ON or Turn OFF curfew time globally for all hostel students.
  Future<void> toggleGlobalCurfew(bool enable) async {
    final current = globalCurfewPolicy.value;
    if (current.isActive == enable && !isUpdatingCurfew.value) return;
    final updated = current.copyWith(isActive: enable);
    final previous = current;
    globalCurfewPolicy.value = updated; // optimistic update
    isUpdatingCurfew.value = true;

    try {
      await _geofenceRepo.savePolicy(updated);
      AppSnackbar.success(
        enable ? 'Curfew Turned ON' : 'Curfew Turned OFF',
        enable
            ? 'Hostel night curfew is now ACTIVE (${updated.formatTimeRange()}).'
            : 'Hostel night curfew is now TURNED OFF globally.',
      );
    } catch (e) {
      globalCurfewPolicy.value = previous; // rollback
      debugPrint('[ScreenTime] toggleGlobalCurfew error: $e');
      AppSnackbar.error(
        'Update Failed',
        'Could not update global curfew. Server might be unreachable.',
      );
    } finally {
      isUpdatingCurfew.value = false;
    }
  }

  /// Update the start and end time for the global curfew window.
  Future<void> updateGlobalCurfewTimes(TimeOfDay start, TimeOfDay end) async {
    final current = globalCurfewPolicy.value;
    final updated = current.copyWith(startTime: start, endTime: end);
    final previous = current;
    globalCurfewPolicy.value = updated;
    isUpdatingCurfew.value = true;

    try {
      await _geofenceRepo.savePolicy(updated);
      AppSnackbar.success(
        'Curfew Window Updated',
        'Global curfew is now set to ${updated.formatTimeRange()}.',
      );
    } catch (e) {
      globalCurfewPolicy.value = previous;
      debugPrint('[ScreenTime] updateGlobalCurfewTimes error: $e');
      AppSnackbar.error('Update Failed', 'Could not save new curfew hours.');
    } finally {
      isUpdatingCurfew.value = false;
    }
  }

  /// Leader/Staff fetches directory of all students with today screen time overview from real API.
  /// Uses batching with limit 500 and pagination offsets to retrieve every student in the hostel.
  Future<void> fetchStudentsList({String? search, bool silent = false}) async {
    if (!silent) isLoadingStudents.value = true;
    try {
      final query = (search ?? searchFilterController.text).trim();
      final baseParams = <String, dynamic>{
        'limit': 500,
        if (query.isNotEmpty) 'search': query,
      };

      final response = await _apiClient.dio.get(
        '/screen-time/students',
        queryParameters: {...baseParams, 'offset': 0},
      );
      final data = response.data['data'] ?? response.data;

      if (data != null && data['students'] != null) {
        final List<dynamic> loaded = List<dynamic>.from(data['students']);
        final int total = (data['total'] is num) ? (data['total'] as num).toInt() : loaded.length;

        // Fetch remaining pages if hostel has more than 500 students
        while (loaded.length < total) {
          final nextRes = await _apiClient.dio.get(
            '/screen-time/students',
            queryParameters: {...baseParams, 'offset': loaded.length},
          );
          final nextData = nextRes.data['data'] ?? nextRes.data;
          if (nextData != null &&
              nextData['students'] != null &&
              (nextData['students'] as List).isNotEmpty) {
            final nextList = List<dynamic>.from(nextData['students']);
            loaded.addAll(nextList);
          } else {
            break;
          }
        }

        allStudents.assignAll(loaded);
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
    final filter = directoryFilter.value;

    final matched = allStudents.where((student) {
      if (!_matchesDirectoryFilter(student, filter)) return false;
      if (q.isEmpty) return true;
      final name = (student['name'] ?? '').toString().toLowerCase();
      final room = (student['room'] ?? '').toString().toLowerCase();
      final aadhar = (student['aadhar'] ?? '').toString();
      return name.contains(q) || room.contains(q) || aadhar.contains(q);
    }).toList();

    // Students needing attention first, then heaviest users.
    matched.sort((a, b) {
      final attA = isStudentTampered(a) || isStudentLocked(a);
      final attB = isStudentTampered(b) || isStudentLocked(b);
      if (attA != attB) return attA ? -1 : 1;
      return toInt(b['totalScreenTimeMinutes']).compareTo(toInt(a['totalScreenTimeMinutes']));
    });
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
      final pol = ScreenTimePolicy.tryParse({'policy': student['policy']});
      if (pol != null) {
        isDeviceLocked.value = pol.isLocked;
        dailyLimitMinutes.value = pol.dailyLimitMinutes;
        bedtimeStart.value = pol.bedtimeStart;
        bedtimeEnd.value = pol.bedtimeEnd;
      }
    }

    final directApps = _extractAppsList(student);
    if (directApps.isNotEmpty) {
      appBreakdown.assignAll(_sortedByMinutes(directApps));
      _syncBlockedStatusToApps();
    } else {
      appBreakdown.clear();
    }
    historyRecords.clear();

    debugPrint('[ScreenTime] selectStudent: ${student['name']}, id=$_studentId, initialMins=${totalMinutesToday.value}, appsCount=${appBreakdown.length}');

    fetchLiveStatus();
    fetchHistory();
    fetchStudentPolicies();
  }

  /// Return back to all students directory list
  void clearSelectedStudent() {
    selectedStudent.value = null;
    openedWithDirectTarget.value = false;
    _resetDetail();
    searchFilterController.clear();
    filterStudents('');
  }

  void _resetDetail() {
    lastSeenAt.value = null;
    compliance.clear();
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
    bedtimeStart.value = '';
    bedtimeEnd.value = '';
    selectedAppFilter.value = 'All';
    appSearchQuery.value = '';
    appSearchController.clear();
  }

  /// Fetch live status of the selected student (by student id) from the real API
  Future<void> fetchLiveStatus() async {
    final id = _studentId;
    if (id.isEmpty) return;
    isLoading.value = true;
    try {
      final response = await _apiClient.dio.get('/screen-time/live/$id');
      if (id == _studentId) _applyLiveStatusResponse(response.data);
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

    final seen = lastSeenOf(data);
    if (seen != null) {
      lastSeenAt.value = seen;
    } else if (isOnline.value) {
      lastSeenAt.value = DateTime.now();
    }
    if (data['compliance'] is Map) {
      compliance.assignAll(Map<String, dynamic>.from(data['compliance']));
    }
    currentPackage.value = (data['currentPackage'] ?? data['current_package'] ?? '').toString();

    final rawApps = _extractAppsList(data);
    final newApps = rawApps.where((a) {
      final pkg = (a is Map ? (a['packageName'] ?? a['package_name'] ?? '') : '').toString();
      return !_isOurApp(pkg);
    }).toList();
    if (newApps.isNotEmpty) {
      appBreakdown.assignAll(_sortedByMinutes(newApps));
      debugPrint('[ScreenTime] updated appBreakdown with ${appBreakdown.length} apps. First app: ${appBreakdown.first}');

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
      totalMinutesToday.value = appsSum > 0 ? appsSum : liveTotal;
    } else if (liveTotal > 0 || totalMinutesToday.value == 0) {
      totalMinutesToday.value = liveTotal;
    }

    final policy = ScreenTimePolicy.tryParse(data, current: currentPolicy);
    if (policy != null) _applyPolicy(policy);
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

  /// Fetch full policy, blocked list, and installed apps for the selected student (by student id)
  Future<void> fetchStudentPolicies() async {
    final id = _studentId;
    if (id.isEmpty) return;
    try {
      final response = await _apiClient.dio.get('/screen-time/policies/$id');
      if (id != _studentId) return; // another student was selected meanwhile
      final policy = ScreenTimePolicy.tryParse(response.data, current: currentPolicy);
      if (policy != null) _applyPolicy(policy);
    } catch (e) {
      debugPrint('[ScreenTime] fetchStudentPolicies error: $e');
    }
  }

  /// Saves only the given policy [fields] for the selected student (the PUT is
  /// a partial update), so a change made before the policy finished loading
  /// can't overwrite the student's other rules. Throws on failure so callers
  /// can roll back their optimistic UI change.
  Future<void> _putPolicy(Map<String, dynamic> fields) async {
    final id = _studentId;
    if (id.isEmpty) throw StateError('No student selected');
    await _apiClient.dio.put('/screen-time/policies/$id', data: fields);
    policyVersion.value = DateTime.now().toIso8601String();
  }

  /// Toggle blocking or unblocking an app (Admin / Warden action)
  Future<void> toggleAppBlock(String packageName, String appName, bool block) async {
    final studentName = selectedStudent.value is Map
        ? (selectedStudent.value['name'] ?? 'Student')
        : 'Student';
    final previous = currentPolicy;
    final updated = previous.copyWith(
      blockedPackages: block
          ? {...previous.blockedPackages, packageName}
          : previous.blockedPackages.where((p) => p != packageName).toSet(),
    );

    // Optimistic update; rolled back below if the API rejects it.
    _applyPolicy(updated);
    try {
      final id = _studentId;
      if (id.isEmpty) throw StateError('No student selected');
      // One app at a time, so the rest of the student's block list is untouched.
      await _apiClient.dio.post('/screen-time/apps/rule', data: {
        'student_id': id,
        'package_name': packageName,
        'app_name': appName,
        'is_blocked': block,
      });
      policyVersion.value = DateTime.now().toIso8601String();
      if (block) {
        AppSnackbar.warning('App Restricted', '$appName is now restricted for $studentName.');
      } else {
        AppSnackbar.success('App Allowed', '$appName restriction removed for $studentName.');
      }
    } catch (e) {
      debugPrint('[ScreenTime] toggleAppBlock error: $e');
      _applyPolicy(previous);
      AppSnackbar.error('Not Saved', 'Could not update $appName for $studentName. Please try again.');
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
    final studentName = selectedStudent.value is Map
        ? (selectedStudent.value['name'] ?? 'Student')
        : 'Student';
    final previous = currentPolicy;

    _applyPolicy(previous.copyWith(isLocked: lock));
    try {
      await _putPolicy({'is_locked': lock});
      if (lock) {
        AppSnackbar.warning(
          'Device Locked',
          "$studentName's phone has been remotely locked. The device applies it within about 30 seconds.",
        );
      } else {
        AppSnackbar.success(
          'Device Unlocked',
          "$studentName's phone lock has been released. Access returns shortly.",
        );
      }
    } catch (e) {
      debugPrint('[ScreenTime] toggleDeviceLock error: $e');
      _applyPolicy(previous);
      AppSnackbar.error(
        lock ? 'Lock Failed' : 'Unlock Failed',
        "Could not reach the server. $studentName's phone is unchanged.",
      );
    }
  }

  /// Save bedtime curfew and daily screen limit
  Future<void> updateCurfewAndLimit({
    required int limitMinutes,
    required String startBedtime,
    required String endBedtime,
  }) async {
    final previous = currentPolicy;
    _applyPolicy(previous.copyWith(
      dailyLimitMinutes: limitMinutes,
      bedtimeStart: startBedtime,
      bedtimeEnd: endBedtime,
    ));

    try {
      await _putPolicy({
        'daily_limit_minutes': limitMinutes,
        'bedtime_start': startBedtime,
        'bedtime_end': endBedtime,
      });
      AppSnackbar.success(
        'Policy Saved',
        'Curfew ($startBedtime - $endBedtime) & daily limit updated.',
      );
    } catch (e) {
      debugPrint('[ScreenTime] updateCurfewAndLimit error: $e');
      _applyPolicy(previous);
      AppSnackbar.error('Not Saved', 'Could not save the curfew and daily limit. Please try again.');
    }
  }

  /// Merged and filtered app list for the UI, including restricted packages
  List<Map<String, dynamic>> get displayAppsList {
    final map = <String, Map<String, dynamic>>{};

    // 1. Add apps from the selected day's usage breakdown (excluding our own app)
    for (final it in currentDayRawApps) {
      if (it is Map) {
        final pkg = (it['packageName'] ??
                it['package_name'] ??
                it['appName'] ??
                it['name'] ??
                '')
            .toString();
        if (_isOurApp(pkg)) continue;

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

    // 2. Ensure all blocked packages appear even if not opened on this day
    for (final pkg in blockedPackages) {
      if (_isOurApp(pkg)) continue;
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

      if (tab == 'Used Today' || tab == 'Used on Day') return mins > 0;
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

  /// Fetch history logs of the selected student (by student id) from the real API
  Future<void> fetchHistory() async {
    final id = _studentId;
    if (id.isEmpty) return;
    try {
      final response = await _apiClient.dio.get('/screen-time/history/$id');
      if (id == _studentId) _applyHistoryResponse(response.data);
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
      for (final rec in records) {
        AppIconCache.ingest(_extractAppsList(rec));
      }
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
        final filteredApps = apps.where((a) {
          final pkg = (a is Map ? (a['packageName'] ?? a['package_name'] ?? '') : '').toString();
          return !_isOurApp(pkg);
        }).toList();
        if (filteredApps.isNotEmpty) {
          appBreakdown.assignAll(_sortedByMinutes(filteredApps));
          _syncBlockedStatusToApps();
          debugPrint('[ScreenTime] extracted ${appBreakdown.length} apps from history');
          break;
        }
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
          AppIconCache.ingest(c);
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
