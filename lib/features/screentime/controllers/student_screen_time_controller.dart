import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/models/geofence/geofence_policy_model.dart';
import '../../../core/network/repository/geofence/geofence_repository.dart';
import '../../phonebook/models/phonebook_models.dart';
import '../models/screen_time_policy.dart';
import '../services/app_icon_cache.dart';
import '../../phonebook/services/phonebook_database_service.dart';
import '../../phonebook/services/phonebook_sync_service.dart';

/// Screen-time and Parental Control controller for Administrators.
///
/// Restricted to Admin / Warden roles. Allows monitoring student phone telemetry,
/// inspecting live app usage, blocking distracting apps remotely, locking devices,
/// and setting bedtime curfews.
class StudentScreenTimeController extends GetxController with WidgetsBindingObserver {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final GeofenceRepository _geofenceRepo = GeofenceRepository();

  /// Hostel-wide curfew policy (enforced natively on student phones).
  final Rx<GeofencePolicyModel> globalCurfewPolicy = const GeofencePolicyModel()
      .obs;
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
  final RxMap<String, List<dynamic>> dateSpecificApps = <String, List<dynamic>>{}.obs;
  final RxMap<String, int> dateSpecificTotals = <String, int>{}.obs;
  final RxMap<String, int> dateSpecificNight = <String, int>{}.obs;
  final RxBool isLoadingDateUsage = false.obs;

  /// List of student app installation requests pending warden approval
  final RxList<Map<String, dynamic>> pendingAppRequests = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingAppRequests = false.obs;

  /// When the student's phone last reported in, and what it reported about
  /// its own monitoring health (Usage Access / Accessibility / battery).
  final Rx<DateTime?> lastSeenAt = Rx<DateTime?>(null);
  final RxMap<String, dynamic> compliance = <String, dynamic>{}.obs;

  /// Package of the foreground app (for its icon); [currentApp] is the label.
  final RxString currentPackage = ''.obs;

  /// Monitoring on the selected student's phone has been switched off.
  bool get isTampered => isStudentTampered({'compliance': compliance});

  /// Share of the daily allowance used on the selected day (0 when unlimited).
  double get limitProgress =>
      dailyLimitMinutes.value > 0
          ? (selectedDayTotalMinutes / dailyLimitMinutes.value).clamp(0.0, 1.0)
          : 0.0;

  // Directory quick filter: All / Online / Offline / Locked / Restricted / Night / Attention
  final RxString directoryFilter = 'All'.obs;
  static const directoryFilters = [
    'All',
    'Online',
    'Offline',
    'Locked',
    'Restricted',
    'Night',
    'Attention'
  ];

  static bool toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == '1' || s == 'true';
    }
    return false;
  }

  static bool isStudentOnline(dynamic s) {
    if (s is! Map) return false;
    final onlineVal = s['isOnline'] ?? s['is_online'] ?? s['online'];
    if (onlineVal != null) {
      return toBool(onlineVal);
    }
    final lastSeen = lastSeenOf(s);
    if (lastSeen != null) {
      return DateTime
          .now()
          .difference(lastSeen)
          .inMinutes <= 10;
    }
    return false;
  }

  static bool isStudentOffline(dynamic s) => !isStudentOnline(s);

  /// Returns true only if the student has an allocated hostel room (excludes Room N/A, alumni, day scholars).
  static bool hasValidRoom(dynamic s) {
    if (s is! Map) return false;
    final raw = (s['room'] ?? s['room_number'] ?? s['roomNumber'] ?? '').toString().trim();
    if (raw.isEmpty) return false;
    final lower = raw.toLowerCase();
    if (lower == 'n/a' ||
        lower == 'na' ||
        lower.contains('n/a') ||
        lower == 'none' ||
        lower == 'null' ||
        lower == 'alumni' ||
        lower == 'day scholar' ||
        lower == 'dayscholar' ||
        lower == 'unallocated' ||
        lower == '0' ||
        lower == '-') {
      return false;
    }
    return true;
  }

  static bool isStudentScreenOn(dynamic s) {
    if (s is! Map) return false;
    final screenVal = s['isScreenOn'] ?? s['is_screen_on'] ?? s['screenOn'] ??
        s['screen_on'];
    return toBool(screenVal);
  }

  void setDirectoryFilter(String filter) {
    directoryFilter.value = filter;
    visibleStudentCount.value = uiBatchSize;
    filterStudents(searchFilterController.text);
    unawaited(_fillViewport());
  }

  /// Per-filter counts, computed in one pass whenever [allStudents] settles,
  /// instead of once per chip/tile on every rebuild while scrolling.
  Map<String, int>? _directoryCounts;
  final RxInt _countsVersion = 0.obs;

  void _invalidateDirectoryCounts() {
    _directoryCounts = null;
    _countsVersion.value++;
  }

  Map<String, int> _computeDirectoryCounts() {
    var valid = 0, online = 0, locked = 0, restricted = 0, night = 0, attention = 0;
    for (final s in allStudents) {
      if (!hasValidRoom(s)) continue;
      valid++;
      if (isStudentOnline(s)) online++;
      if (isStudentLocked(s)) locked++;
      if (isStudentRestricted(s)) restricted++;
      if (s is Map &&
          toInt(s['nightScreenTimeMinutes'] ??
                  s['night_screen_time_minutes']) >
              0) {
        night++;
      }
      if (isStudentTampered(s) || isStudentLocked(s)) attention++;
    }
    return {
      'All': valid,
      'Online': online,
      'Offline': valid - online,
      'Locked': locked,
      'Restricted': restricted,
      'Night': night,
      'Attention': attention,
    };
  }

  /// Directory-wide counts reported by `/screen-time/students` (online,
  /// offline, locked, attention, and total when sent). Used for the summary
  /// tiles so they are right before every page is loaded.
  final RxMap<String, int> serverCounts = <String, int>{}.obs;

  static const _countKeys = {
    'All': ['total', 'totalStudents', 'total_students', 'totalCount', 'total_count'],
    'Online': ['online', 'onlineCount', 'online_count', 'onlineStudents', 'online_students'],
    'Offline': ['offline', 'offlineCount', 'offline_count', 'offlineStudents', 'offline_students'],
    'Locked': ['locked', 'lockedCount', 'locked_count', 'lockedStudents', 'locked_students'],
    'Attention': ['attention', 'attentionCount', 'attention_count', 'needsAttention', 'needs_attention'],
  };

  /// Reads the summary counts from a `/screen-time/students` response body.
  /// Looks at the body, its `data`, and a nested `summary` / `counts` / `stats`
  /// object. Only called for the unfiltered directory (a search narrows them).
  void _captureServerCounts(dynamic body) {
    final sources = <Map>[];
    void addMap(dynamic m) {
      if (m is Map) sources.add(m);
    }

    addMap(body);
    if (body is Map) {
      addMap(body['data']);
      for (final k in const ['summary', 'counts', 'stats', 'statistics']) {
        addMap(body[k]);
        if (body['data'] is Map) addMap((body['data'] as Map)[k]);
      }
    }
    final found = <String, int>{};
    _countKeys.forEach((filter, keys) {
      for (final src in sources) {
        for (final key in keys) {
          if (src[key] != null && src[key] is! Map && src[key] is! List) {
            found[filter] = toInt(src[key]);
            return;
          }
        }
      }
    });
    if (found.isNotEmpty) serverCounts.addAll(found);
  }

  @visibleForTesting
  void captureServerCountsForTest(dynamic body) => _captureServerCounts(body);

  int directoryCount(String filter) {
    _countsVersion.value; // rebuild when the cache is invalidated
    // The API's directory-wide numbers, unless a search narrows the list.
    final fromApi = serverCounts[filter];
    if (fromApi != null && searchText.value.trim().isEmpty) return fromApi;
    final counts = _directoryCounts ??= _computeDirectoryCounts();
    final count = counts[filter] ?? 0;
    // Only some pages may be loaded yet, so the loaded rows under-count the
    // directory. Use the server total for Total, and total - online for
    // Offline, so both are right on the first frame.
    final partial = hasMoreStudents.value &&
        searchText.value.trim().isEmpty &&
        totalStudentsCount.value > counts['All']!;
    if (partial) {
      if (filter == 'All') return totalStudentsCount.value;
      if (filter == 'Offline') {
        final offline = totalStudentsCount.value - (counts['Online'] ?? 0);
        return offline < 0 ? 0 : offline;
      }
    }
    return count;
  }

  static bool _matchesDirectoryFilter(dynamic s, String filter) {
    if (!hasValidRoom(s)) return false;

    switch (filter) {
      case 'Online':
        return isStudentOnline(s);
      case 'Offline':
        return isStudentOffline(s);
      case 'Locked':
        return isStudentLocked(s);
      case 'Restricted':
        return isStudentRestricted(s);
      case 'Night':
        return s is Map && toInt(
            s['nightScreenTimeMinutes'] ?? s['night_screen_time_minutes']) > 0;
      case 'Attention':
        return isStudentTampered(s) || isStudentLocked(s);
      default:
        return true;
    }
  }

  // ---------- Student-row helpers (directory entries are raw API maps) ----------

  static Map<String, dynamic>? complianceOf(dynamic s) =>
      s is Map && s['compliance'] is Map ? Map<String, dynamic>.from(
          s['compliance']) : null;

  static bool isStudentTampered(dynamic s) {
    final c = complianceOf(s);
    if (c == null || c.isEmpty) return false;
    final locPerm = (c['locationPermission'] ?? '').toString().toLowerCase();
    final locDisabled = locPerm == 'denied' || locPerm == 'foreground';
    final locServicesOff = c['locationEnabled'] == false;
    return c['usageAccess'] == false ||
        c['accessibilityEnabled'] == false ||
        locDisabled ||
        locServicesOff;
  }

  static bool isStudentLocked(dynamic s) {
    if (s is! Map) return false;
    final pol = s['policy'] is Map ? s['policy'] as Map : s;
    return pol['is_locked'] == true || pol['isLocked'] == true ||
        pol['is_locked'] == 1;
  }

  static List<String> blockedOf(dynamic s) {
    if (s is! Map) return const [];
    final pol = s['policy'] is Map ? s['policy'] as Map : const {};
    final raw = s['blockedPackages'] ?? s['blocked_packages'] ??
        pol['blockedPackages'] ?? pol['blocked_packages'];
    return raw is List ? raw.map((e) => e.toString()).toList() : const [];
  }

  static bool isStudentRestricted(dynamic s) => blockedOf(s).isNotEmpty;

  static DateTime? lastSeenOf(dynamic s) {
    if (s is! Map) return null;
    final raw = s['lastSeenAt'] ?? s['lastSeen'] ?? s['last_seen'] ??
        s['lastPing'] ?? s['last_ping'] ?? s['updatedAt'];
    if (raw == null) return null;
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(
          raw > 1e12 ? raw.toInt() : raw.toInt() * 1000);
    }
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

  /// Standardizes any date representation (DateTime, numeric epoch ms/s, or string)
  /// into 'yyyy-MM-dd'.
  static String extractRecordDate(dynamic r) {
    if (r == null) return '';
    if (r is DateTime) {
      return '${r.year.toString().padLeft(4, '0')}-${r.month.toString().padLeft(2, '0')}-${r.day.toString().padLeft(2, '0')}';
    }
    if (r is! Map) {
      return _normalizeDateString(r.toString());
    }
    final raw = r['date'] ??
        r['day'] ??
        r['usage_date'] ??
        r['usageDate'] ??
        r['created_at'] ??
        r['createdAt'] ??
        r['record_date'] ??
        r['recordDate'] ??
        r['timestamp'];
    if (raw == null) return '';
    if (raw is DateTime) {
      return '${raw.year.toString().padLeft(4, '0')}-${raw.month.toString().padLeft(2, '0')}-${raw.day.toString().padLeft(2, '0')}';
    }
    if (raw is num) {
      final ms = raw > 1e12 ? raw.toInt() : raw.toInt() * 1000;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return _normalizeDateString(raw.toString());
  }

  static String _normalizeDateString(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('T') || trimmed.contains('Z') || trimmed.contains(':')) {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        final dt = parsed.toLocal();
        return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
    }
    final reg = RegExp(r'^(\d{4}-\d{2}-\d{2})');
    final match = reg.firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!;
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final dt = parsed.toLocal();
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return trimmed.split('T').first.split(' ').first.trim();
  }

  String get todayDateStr {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month
        .toString()
        .padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool get isTodaySelected {
    return selectedDate.value.isEmpty || selectedDate.value == todayDateStr;
  }

  String get effectiveSelectedDate {
    return selectedDate.value.isEmpty ? todayDateStr : selectedDate.value;
  }

  static const String _kScreenTimeCachePrefix = 'hsh_st_cache_';

  /// Asynchronously loads persistent app-wise usage & screen time from SharedPreferences cache
  Future<void> _loadCachedStudentScreenTime(String studentId) async {
    if (studentId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Today's cached apps & totals
      final todayAppsJson = prefs.getString('${_kScreenTimeCachePrefix}apps_${studentId}_$todayDateStr') ??
          prefs.getString('${_kScreenTimeCachePrefix}apps_${studentId}_today');
      if (todayAppsJson != null && todayAppsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(todayAppsJson);
          if (decoded is List && decoded.isNotEmpty) {
            final apps = _deduplicateAndSortApps(decoded);
            if (appBreakdown.isEmpty) {
              appBreakdown.assignAll(apps);
            }
            dateSpecificApps[todayDateStr] = apps;
          }
        } catch (_) {}
      }

      final todayTotal = prefs.getInt('${_kScreenTimeCachePrefix}total_${studentId}_$todayDateStr') ??
          prefs.getInt('${_kScreenTimeCachePrefix}total_${studentId}_today');
      if (todayTotal != null && todayTotal > 0) {
        if (totalMinutesToday.value == 0) totalMinutesToday.value = todayTotal;
        dateSpecificTotals[todayDateStr] = todayTotal;
      }

      final todayNight = prefs.getInt('${_kScreenTimeCachePrefix}night_${studentId}_$todayDateStr') ??
          prefs.getInt('${_kScreenTimeCachePrefix}night_${studentId}_today');
      if (todayNight != null && todayNight > 0) {
        if (nightMinutesToday.value == 0) nightMinutesToday.value = todayNight;
        dateSpecificNight[todayDateStr] = todayNight;
      }

      // 2. Cached history records
      final historyJson = prefs.getString('${_kScreenTimeCachePrefix}history_$studentId');
      if (historyJson != null && historyJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(historyJson);
          if (decoded is List && decoded.isNotEmpty && historyRecords.isEmpty) {
            historyRecords.assignAll(decoded);
          }
        } catch (_) {}
      }

      // 3. Past 7 days app breakdowns & totals
      final now = DateTime.now();
      for (int i = 1; i <= 7; i++) {
        final dt = now.subtract(Duration(days: i));
        final dStr = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

        final dayAppsJson = prefs.getString('${_kScreenTimeCachePrefix}apps_${studentId}_$dStr');
        if (dayAppsJson != null && dayAppsJson.isNotEmpty) {
          try {
            final decoded = jsonDecode(dayAppsJson);
            if (decoded is List && decoded.isNotEmpty) {
              dateSpecificApps[dStr] = _deduplicateAndSortApps(decoded);
            }
          } catch (_) {}
        }

        final dayTotal = prefs.getInt('${_kScreenTimeCachePrefix}total_${studentId}_$dStr');
        if (dayTotal != null && dayTotal > 0) {
          dateSpecificTotals[dStr] = dayTotal;
        }

        final dayNight = prefs.getInt('${_kScreenTimeCachePrefix}night_${studentId}_$dStr');
        if (dayNight != null && dayNight > 0) {
          dateSpecificNight[dStr] = dayNight;
        }
      }
    } catch (e) {
      debugPrint('[ScreenTime] _loadCachedStudentScreenTime error: $e');
    }
  }

  Future<void> _saveCachedDateUsage(String studentId, String dateStr, List<dynamic> apps, int total, int night) async {
    if (studentId.isEmpty || dateStr.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (apps.isNotEmpty) {
        await prefs.setString('${_kScreenTimeCachePrefix}apps_${studentId}_$dateStr', jsonEncode(apps));
      }
      if (total > 0) {
        await prefs.setInt('${_kScreenTimeCachePrefix}total_${studentId}_$dateStr', total);
      }
      if (night > 0) {
        await prefs.setInt('${_kScreenTimeCachePrefix}night_${studentId}_$dateStr', night);
      }
      if (dateStr == todayDateStr) {
        if (apps.isNotEmpty) {
          await prefs.setString('${_kScreenTimeCachePrefix}apps_${studentId}_today', jsonEncode(apps));
        }
        if (total > 0) {
          await prefs.setInt('${_kScreenTimeCachePrefix}total_${studentId}_today', total);
        }
        if (night > 0) {
          await prefs.setInt('${_kScreenTimeCachePrefix}night_${studentId}_today', night);
        }
      }
    } catch (e) {
      debugPrint('[ScreenTime] _saveCachedDateUsage error: $e');
    }
  }

  Future<void> _saveCachedHistory(String studentId, List<dynamic> records) async {
    if (studentId.isEmpty || records.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_kScreenTimeCachePrefix}history_$studentId', jsonEncode(records));
    } catch (e) {
      debugPrint('[ScreenTime] _saveCachedHistory error: $e');
    }
  }

  List<Map<String, dynamic>> _deduplicateAndSortApps(List<dynamic> rawApps) {
    final map = <String, Map<String, dynamic>>{};
    for (final it in rawApps) {
      if (it is! Map) continue;
      final pkg = (it['packageName'] ??
              it['package_name'] ??
              it['package'] ??
              it['pkg'] ??
              '')
          .toString()
          .trim();
      if (pkg.isEmpty || _isOurApp(pkg) || _isSystemPackage(pkg)) continue;

      final rawName = (it['appName'] ??
              it['app_name'] ??
              it['name'] ??
              it['title'] ??
              it['label'] ??
              '')
          .toString()
          .trim();
      final name = (rawName.isNotEmpty && rawName != pkg) ? rawName : _guessAppName(pkg);
      final mins = extractAppMinutes(it);
      final icon = (it['icon'] ?? it['iconBase64'] ?? it['icon_base64'])?.toString();
      final isBlocked = blockedPackages.contains(pkg) ||
          it['isBlocked'] == true ||
          it['is_blocked'] == true ||
          it['is_blocked'] == 1;

      if (map.containsKey(pkg)) {
        final existing = map[pkg]!;
        final prevMins = (existing['minutes'] as int?) ?? 0;
        existing['minutes'] = prevMins + mins;
        if (name.isNotEmpty && existing['appName'] == pkg) {
          existing['appName'] = name;
        }
        if (icon != null && icon.isNotEmpty && existing['icon'] == null) {
          existing['icon'] = icon;
        }
      } else {
        map[pkg] = {
          'packageName': pkg,
          'appName': name,
          'minutes': mins,
          if (icon != null && icon.isNotEmpty) 'icon': icon,
          'isBlocked': isBlocked,
        };
      }
    }

    final list = map.values.toList();
    list.sort((a, b) {
      final mA = (a['minutes'] as int?) ?? 0;
      final mB = (b['minutes'] as int?) ?? 0;
      if (mB != mA) return mB.compareTo(mA);
      return (a['appName'] as String).compareTo(b['appName'] as String);
    });
    return list;
  }

  void selectDate(String dateStr) {
    final normalized = _normalizeDateString(dateStr);
    selectedDate.value = normalized;
    if (normalized.isNotEmpty && normalized != todayDateStr) {
      final rec = _findHistoryRecord(normalized);
      final hasApps = (rec != null && _extractAppsList(rec).isNotEmpty) ||
          (dateSpecificApps[normalized]?.isNotEmpty == true);
      final hasTotal = (dateSpecificTotals[normalized] ?? 0) > 0 ||
          (rec != null &&
              toInt(rec['total_screen_time_minutes'] ??
                      rec['totalScreenTimeMinutes'] ??
                      rec['totalMinutes'] ??
                      rec['total_minutes']) >
                  0);
      if (!hasApps || !hasTotal) {
        fetchUsageForDate(normalized);
      }
    }
  }

  /// Fetches screen-time history & app breakdown for a specific date
  Future<void> fetchUsageForDate(String dateStr) async {
    final id = _studentId;
    if (id.isEmpty || dateStr.isEmpty) return;
    if (dateStr == todayDateStr) {
      await fetchLiveStatus();
      return;
    }
    final normalized = _normalizeDateString(dateStr);
    isLoadingDateUsage.value = true;
    try {
      final response = await _apiClient.dio.get(
        '/screen-time/history/$id',
        queryParameters: {'date': normalized},
      );
      if (id != _studentId) return;
      _applyDateUsageResponse(normalized, response.data);
    } catch (e) {
      debugPrint('[ScreenTime] fetchUsageForDate error for $normalized: $e');
    } finally {
      isLoadingDateUsage.value = false;
    }
  }

  void _applyDateUsageResponse(String dateStr, dynamic raw) {
    if (dateStr.isEmpty) return;
    final normalizedTarget = _normalizeDateString(dateStr);
    final data = raw is Map ? (raw['data'] ?? raw) : raw;
    List<dynamic> apps = [];
    int? total;
    int? night;

    List<dynamic>? candidateList;
    Map<String, dynamic>? candidateMap;

    if (data is List) {
      candidateList = data;
    } else if (data is Map) {
      final listCandidates = [
        data['records'],
        data['history'],
        data['items'],
        data['rows'],
        data['data'],
        data['usage_logs'],
        data['usageLogs'],
        data['app_usage_logs'],
        data['appUsageLogs'],
        data['appUsageBreakdown'],
        data['app_usage_breakdown'],
        data['apps'],
      ];
      for (final lc in listCandidates) {
        if (lc is List) {
          candidateList = lc;
          break;
        }
      }
      if (candidateList == null) {
        candidateMap = Map<String, dynamic>.from(data);
      }
    }

    if (candidateList != null && candidateList.isNotEmpty) {
      final first = candidateList.first;
      // If the list items themselves are app usage entries
      if (first is Map &&
          (first.containsKey('package_name') ||
              first.containsKey('packageName') ||
              first.containsKey('package') ||
              first.containsKey('pkg') ||
              first.containsKey('app_name') ||
              first.containsKey('appName') ||
              first.containsKey('usage_minutes') ||
              first.containsKey('minutes'))) {
        apps = candidateList;
      } else {
        // Otherwise search for matching day record
        for (final item in candidateList) {
          if (item is Map) {
            final d = extractRecordDate(item);
            if (d == normalizedTarget) {
              candidateMap = Map<String, dynamic>.from(item);
              break;
            }
          }
        }
        if (candidateMap == null && candidateList.length == 1 && candidateList.first is Map) {
          candidateMap = Map<String, dynamic>.from(candidateList.first);
        }
      }
    }

    if (candidateMap != null) {
      if (apps.isEmpty) {
        apps = _extractAppsList(candidateMap);
      }
      total = toInt(
        candidateMap['total_screen_time_minutes'] ??
            candidateMap['totalScreenTimeMinutes'] ??
            candidateMap['totalMinutes'] ??
            candidateMap['total_minutes'] ??
            candidateMap['usage_minutes'] ??
            candidateMap['minutes'] ??
            candidateMap['screen_time_minutes'] ??
            candidateMap['duration'],
      );
      night = toInt(
        candidateMap['night_screen_time_minutes'] ??
            candidateMap['nightScreenTimeMinutes'] ??
            candidateMap['nightMinutes'] ??
            candidateMap['night_minutes'] ??
            candidateMap['night'],
      );
    }

    if (apps.isNotEmpty) {
      final filteredApps = _deduplicateAndSortApps(apps);
      dateSpecificApps[normalizedTarget] = filteredApps;
      AppIconCache.ingest(filteredApps);

      final appSum = filteredApps.fold<int>(0, (acc, item) => acc + extractAppMinutes(item));
      if (appSum > 0 && (total == null || total == 0)) {
        total = appSum;
      }
    }

    if (total != null && total >= 0) {
      dateSpecificTotals[normalizedTarget] = total;
    }
    if (night != null && night >= 0) {
      dateSpecificNight[normalizedTarget] = night;
    }

    // Keep today's state synced if target is today
    if (normalizedTarget == todayDateStr) {
      if (apps.isNotEmpty) {
        appBreakdown.assignAll(dateSpecificApps[normalizedTarget]!);
      }
      if (total != null && total > 0) {
        totalMinutesToday.value = total;
      }
      if (night != null && night > 0) {
        nightMinutesToday.value = night;
      }
    }

    // Save to persistent local cache
    final id = _studentId;
    if (id.isNotEmpty) {
      _saveCachedDateUsage(
        id,
        normalizedTarget,
        dateSpecificApps[normalizedTarget] ?? [],
        dateSpecificTotals[normalizedTarget] ?? (total ?? 0),
        dateSpecificNight[normalizedTarget] ?? (night ?? 0),
      );
    }
  }

  List<Map<String, String>> get availableDays {
    final list = <Map<String, String>>[];
    final now = DateTime.now();
    final today = todayDateStr;
    final yest = now.subtract(const Duration(days: 1));
    final yestStr = '${yest.year.toString().padLeft(4, '0')}-${yest.month
        .toString().padLeft(2, '0')}-${yest.day.toString().padLeft(2, '0')}';

    list.add({'date': today, 'label': 'Today'});
    list.add({'date': yestStr, 'label': 'Yesterday'});

    final seenDates = <String>{today, yestStr};
    for (final r in historyRecords) {
      final d = extractRecordDate(r);
      if (d.isNotEmpty && !seenDates.contains(d)) {
        seenDates.add(d);
        try {
          final parsed = DateTime.parse(d);
          final label = DateFormat('EEE, d MMM').format(parsed);
          list.add({'date': d, 'label': label});
        } catch (_) {
          list.add({'date': d, 'label': d});
        }
      }
    }

    // Ensure selected date is present in available days even if picked via calendar
    final currentSelected = selectedDate.value;
    if (currentSelected.isNotEmpty && !seenDates.contains(currentSelected)) {
      seenDates.add(currentSelected);
      try {
        final parsed = DateTime.parse(currentSelected);
        final label = DateFormat('EEE, d MMM').format(parsed);
        list.add({'date': currentSelected, 'label': label});
      } catch (_) {
        list.add({'date': currentSelected, 'label': currentSelected});
      }
    }

    return list;
  }

  static const _ownPackage = 'com.example.hsh_app2';

  bool _isOurApp(String pkg) => pkg == _ownPackage;

  int get selectedDayTotalMinutes {
    if (isTodaySelected) {
      final apps = appBreakdown;
      if (apps.isNotEmpty) {
        final sum = apps.fold<int>(0, (acc, item) {
          if (item is Map) {
            final pkg = (item['packageName'] ?? item['package_name'] ?? item['package'] ?? '')
                .toString();
            if (_isOurApp(pkg) || _isSystemPackage(pkg)) return acc;
            return acc + extractAppMinutes(item);
          }
          return acc;
        });
        if (sum > 0) return sum;
      }
      return totalMinutesToday.value;
    }

    final targetDate = effectiveSelectedDate;
    // 1. Check date-specific total cache
    if (dateSpecificTotals.containsKey(targetDate) && dateSpecificTotals[targetDate]! > 0) {
      return dateSpecificTotals[targetDate]!;
    }

    // 2. Check history record
    final rec = _findHistoryRecord(targetDate);
    if (rec != null) {
      final recTotal = toInt(
        rec['total_screen_time_minutes'] ??
            rec['totalScreenTimeMinutes'] ??
            rec['totalMinutes'] ??
            rec['total_minutes'] ??
            rec['usage_minutes'] ??
            rec['minutes'],
      );
      if (recTotal > 0) return recTotal;
    }

    // 3. Fallback to apps sum for that day if available
    final apps = currentDayRawApps;
    if (apps.isNotEmpty) {
      final sum = apps.fold<int>(0, (acc, item) {
        if (item is Map) {
          final pkg = (item['packageName'] ?? item['package_name'] ?? item['package'] ?? '')
              .toString();
          if (_isOurApp(pkg) || _isSystemPackage(pkg)) return acc;
          return acc + extractAppMinutes(item);
        }
        return acc;
      });
      if (sum > 0) return sum;
    }

    return 0;
  }

  int get selectedDayNightMinutes {
    if (isTodaySelected) {
      return nightMinutesToday.value;
    }
    final targetDate = effectiveSelectedDate;
    if (dateSpecificNight.containsKey(targetDate) && dateSpecificNight[targetDate]! > 0) {
      return dateSpecificNight[targetDate]!;
    }
    final rec = _findHistoryRecord(targetDate);
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
    final target = _normalizeDateString(dateStr);
    if (target.isEmpty) return null;
    for (final r in historyRecords) {
      if (r is Map) {
        final d = extractRecordDate(r);
        if (d == target) {
          return Map<String, dynamic>.from(r);
        }
      }
    }
    return null;
  }

  List<dynamic> get currentDayRawApps {
    if (isTodaySelected) {
      if (appBreakdown.isNotEmpty) return appBreakdown;
      if (dateSpecificApps.containsKey(todayDateStr) &&
          dateSpecificApps[todayDateStr]!.isNotEmpty) {
        return dateSpecificApps[todayDateStr]!;
      }
      return appBreakdown;
    }
    final targetDate = effectiveSelectedDate;
    // 1. Check dateSpecificApps cache first
    if (dateSpecificApps.containsKey(targetDate) && dateSpecificApps[targetDate]!.isNotEmpty) {
      return dateSpecificApps[targetDate]!;
    }
    // 2. Check historyRecords
    final rec = _findHistoryRecord(targetDate);
    if (rec != null) {
      final extracted = _extractAppsList(rec);
      if (extracted.isNotEmpty) {
        return _deduplicateAndSortApps(extracted);
      }

      // 3. Fallback: If no array breakdown exists, but the record has an active current_app (not "Idle" or empty)
      final curApp = (rec['current_app'] ?? rec['currentApp'] ?? '').toString().trim();
      final totalMins = toInt(
        rec['total_screen_time_minutes'] ??
            rec['totalScreenTimeMinutes'] ??
            rec['totalMinutes'] ??
            rec['total_minutes'] ??
            rec['usage_minutes'] ??
            rec['minutes'],
      );
      if (curApp.isNotEmpty &&
          curApp.toLowerCase() != 'idle' &&
          curApp.toLowerCase() != 'null' &&
          totalMins > 0) {
        return [
          {
            'packageName': curApp.toLowerCase().replaceAll(' ', '.'),
            'appName': curApp,
            'minutes': totalMins,
          }
        ];
      }
    }
    return [];
  }

  int get usedAppsCount => currentDayRawApps.where((a) => extractAppMinutes(a) > 0).length;

  int get totalAvailableAppsCount {
    final pkgs = <String>{};
    for (final a in currentDayRawApps) {
      if (a is Map) {
        final p = (a['packageName'] ?? a['package_name'] ?? a['package'] ?? '').toString();
        if (p.isNotEmpty && !_isOurApp(p) && !_isSystemPackage(p)) pkgs.add(p);
      }
    }
    for (final b in blockedPackages) {
      if (b.isNotEmpty && !_isOurApp(b) && !_isSystemPackage(b)) pkgs.add(b);
    }
    return pkgs.length;
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
        final d = extractRecordDate(r);
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
      final dStr = '${dt.year.toString().padLeft(4, '0')}-${dt.month
          .toString()
          .padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final rec = mapByDate[dStr];

      int total = 0;
      int night = 0;

      if (dStr == today) {
        total = totalMinutesToday.value;
        night = nightMinutesToday.value;
      } else {
        if (dateSpecificTotals.containsKey(dStr)) {
          total = dateSpecificTotals[dStr]!;
        }
        if (dateSpecificNight.containsKey(dStr)) {
          night = dateSpecificNight[dStr]!;
        }

        if (rec != null) {
          final apps = _extractAppsList(rec);
          if (apps.isNotEmpty) {
            final appSum = apps.fold<int>(0, (sum, a) {
              final pkg = (a is Map ? (a['packageName'] ?? a['package_name'] ?? a['package'] ?? '') : '').toString();
              if (_isOurApp(pkg)) return sum;
              return sum + toInt(
                  a['minutes'] ?? a['total_minutes'] ?? a['totalMinutes'] ??
                      a['duration'] ?? a['time'] ?? a['usage_minutes']);
            });
            if (appSum > 0) total = appSum;
          }
          if (total == 0) {
            total = toInt(rec['total_screen_time_minutes'] ??
                rec['totalScreenTimeMinutes'] ?? rec['totalMinutes'] ?? rec['total_minutes'] ??
                rec['usage_minutes'] ?? rec['minutes']);
          }
          if (night == 0) {
            night = toInt(
                rec['night_screen_time_minutes'] ?? rec['nightScreenTimeMinutes'] ??
                    rec['nightMinutes'] ?? rec['night_minutes'] ?? rec['night']);
          }
        }
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
    final sum = nonZero.fold<int>(
        0, (acc, p) => acc + (p['totalMinutes'] as int));
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
  final RxMap<String, int> appLimits = <String, int>{}.obs;

  /// The selected student's policy as currently shown in the UI.
  ScreenTimePolicy get currentPolicy =>
      ScreenTimePolicy(
        isLocked: isDeviceLocked.value,
        blockedPackages: blockedPackages.toSet(),
        dailyLimitMinutes: dailyLimitMinutes.value,
        bedtimeStart: bedtimeStart.value,
        bedtimeEnd: bedtimeEnd.value,
        version: policyVersion.value,
        appLimits: Map<String, int>.from(appLimits),
      );

  void _applyPolicy(ScreenTimePolicy p) {
    isDeviceLocked.value = p.isLocked;
    blockedPackages.assignAll(p.blockedPackages.toList());
    dailyLimitMinutes.value = p.dailyLimitMinutes;
    bedtimeStart.value = p.bedtimeStart;
    bedtimeEnd.value = p.bedtimeEnd;
    policyVersion.value = p.version;
    appLimits.assignAll(p.appLimits);
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

  /// Public read-only numeric student ID for UI keying and state inspection
  String get studentId => _studentId;

  static final _studentIdPattern = RegExp(r'^[1-9]\d*$');

  static bool _isStudentId(String value) => _studentIdPattern.hasMatch(value);

  /// True if the currently selected student has completed device setup and has an active numeric ID on the server.
  bool get isSelectedStudentEnrolled {
    final s = selectedStudent.value;
    if (s is! Map) return false;
    final id = (s['id'] ?? s['_id'] ?? '').toString().trim();
    return _isStudentId(id);
  }

  static int _compareRoomStrings(String a, String b) {
    final intA = int.tryParse(a.replaceAll(RegExp(r'\D'), ''));
    final intB = int.tryParse(b.replaceAll(RegExp(r'\D'), ''));
    if (intA != null && intB != null) {
      return intA.compareTo(intB);
    }
    return a.compareTo(b);
  }

  final RxString selectedAppFilter = 'Used'
      .obs; // 'Used', 'All', 'Restricted'
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

  /// The screen's scroll position, so the Safety tab can scroll back to the
  /// top when it is tapped again.
  final ScrollController pageScrollController = ScrollController();

  void scrollToTop() {
    if (!pageScrollController.hasClients) return;
    pageScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }
  final RxString searchText = ''.obs;
  final Rx<UserRole> currentRole = UserRole.student.obs;

  Timer? _refreshTimer;
  Timer? _searchDebounceTimer;
  final RxBool isSearchingServer = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreStudents = true.obs;
  final RxInt visibleStudentCount = 20.obs;
  /// Students requested per API call. Further pages load as the list is scrolled.
  static const int pageSize = 20;
  static const int uiBatchSize = 20;

  /// Total student count reported by server or current directory.
  final RxInt totalStudentsCount = 0.obs;
  int _serverLoadedCount = 0;

  /// Cache of base directory loaded without a search query,
  /// so clearing search restores the whole directory without an extra network roundtrip.
  final List<dynamic> _baseStudents = [];

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    debounce(allStudents, (_) => _invalidateDirectoryCounts(),
        time: const Duration(milliseconds: 60));
    _checkInitialArguments();
    _loadTotalHostelStudentCount();
    _loadRole();
    fetchAppRequests();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _autoRefresh());
  }

  /// Attempts to populate the total hostel student population from local phonebook cache/db.
  Future<void> _loadTotalHostelStudentCount() async {
    try {
      final cachedCount = await PhonebookSyncService.instance
          .getCachedStudentCount();
      if (cachedCount > 0 && cachedCount > totalStudentsCount.value) {
        totalStudentsCount.value = cachedCount;
        return;
      }
    } catch (_) {}

    try {
      final dbCount = await PhonebookDatabaseService.instance.getStudentCount();
      if (dbCount > 0 && dbCount > totalStudentsCount.value) {
        totalStudentsCount.value = dbCount;
      }
    } catch (_) {}
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
    _searchDebounceTimer?.cancel();
    searchFilterController.dispose();
    pageScrollController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoRefresh();
  }

  Future<void> _loadRole() async {
    final role = await Get
        .find<SessionStore>()
        .role;
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
      _loadTotalHostelStudentCount(),
    ]);
  }

  Future<void> _autoRefresh() async {
    if (!currentRole.value.canViewScreenTime) return;
    if (_studentId.isNotEmpty) {
      await Future.wait(
          [fetchLiveStatus(), fetchHistory(), fetchStudentPolicies(), fetchAppRequests(studentId: _studentId)]);
    } else {
      await Future.wait([
        _refreshLoadedStudents(),
        loadGlobalCurfew(),
        fetchAppRequests(),
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
        fetchAppRequests(),
      ]);
    } else {
      await Future.wait(
          [fetchLiveStatus(), fetchHistory(), fetchStudentPolicies(), fetchAppRequests(studentId: _studentId)]);
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
            ? 'Hostel night curfew is now ACTIVE (${updated
            .formatTimeRange()}).'
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

  static String _normalizeRoomNumber(dynamic room) {
    if (room == null) return '';
    var r = room.toString().trim().toLowerCase();
    r = r.replaceAll(RegExp(r'^(room|rm|r)\s*[-:]*\s*', caseSensitive: false), '');
    return r.trim();
  }

  static String _normalizeStudentName(dynamic name) {
    if (name == null) return '';
    return name.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _mergeServerStudents(List<dynamic> loaded, {bool isRefresh = false}) {
    if (isRefresh) {
      allStudents.clear();
      final seenIds = <String>{};
      final seenKeys = <String>{};
      for (final s in loaded) {
        if (s is! Map) continue;
        final idStr = s['id']?.toString().trim() ?? '';
        final name = _normalizeStudentName(s['name'] ?? s['fullName']);
        final room = _normalizeRoomNumber(s['room'] ?? s['room_number'] ?? s['roomNumber']);
        final key = (name.isNotEmpty && room.isNotEmpty) ? '$room::$name' : name;

        if (idStr.isNotEmpty && seenIds.contains(idStr)) continue;
        if (key.isNotEmpty && seenKeys.contains(key)) continue;

        if (idStr.isNotEmpty) seenIds.add(idStr);
        if (key.isNotEmpty) seenKeys.add(key);
        allStudents.add(Map<String, dynamic>.from(s));
      }
      return;
    }

    // Work on a copy and publish once, so the list rebuilds once per page
    // instead of once per merged student.
    final working = List<dynamic>.from(allStudents);
    for (final s in loaded) {
      if (s is! Map) continue;
      final idStr = s['id']?.toString().trim() ?? '';
      final name = _normalizeStudentName(s['name'] ?? s['fullName']);
      final room = _normalizeRoomNumber(s['room'] ?? s['room_number'] ?? s['roomNumber']);
      final rawPhone = (s['phone'] ?? s['phoneNumber'] ?? s['phone_number'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\D'), '');
      final phone = rawPhone.length >= 10 ? rawPhone.substring(rawPhone.length - 10) : '';

      int existingIndex = -1;
      for (int i = 0; i < working.length; i++) {
        final existing = working[i];
        if (existing is! Map) continue;
        final existingId = existing['id']?.toString().trim() ?? '';
        if (idStr.isNotEmpty && existingId.isNotEmpty && existingId == idStr) {
          existingIndex = i;
          break;
        }

        final existingName = _normalizeStudentName(existing['name'] ?? existing['fullName']);
        final existingRoom = _normalizeRoomNumber(existing['room'] ?? existing['room_number'] ?? existing['roomNumber']);

        if (existingName.isNotEmpty && existingName == name) {
          if (room.isEmpty || existingRoom.isEmpty || room == existingRoom) {
            existingIndex = i;
            break;
          }
        }

        if (phone.isNotEmpty) {
          final existingRawPhone = (existing['phone'] ?? existing['phoneNumber'] ?? existing['phone_number'] ?? '')
              .toString()
              .replaceAll(RegExp(r'\D'), '');
          final existingPhone =
              existingRawPhone.length >= 10 ? existingRawPhone.substring(existingRawPhone.length - 10) : '';
          if (existingPhone.isNotEmpty && existingPhone == phone) {
            existingIndex = i;
            break;
          }
        }

        final sAadhar = (s['aadhar'] ?? s['student_code'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final existingAadhar = (existing['aadhar'] ?? existing['student_code'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        if (sAadhar.length >= 8 && existingAadhar.length >= 8 && sAadhar == existingAadhar) {
          existingIndex = i;
          break;
        }

        final sBank = (s['bankCode'] ?? s['bank_code'] ?? '').toString().trim().toLowerCase();
        final existingBank = (existing['bankCode'] ?? existing['bank_code'] ?? '').toString().trim().toLowerCase();
        if (sBank.isNotEmpty && existingBank.isNotEmpty && sBank == existingBank) {
          existingIndex = i;
          break;
        }
      }

      if (existingIndex >= 0) {
        final existing = working[existingIndex];
        final merged = Map<String, dynamic>.from(existing is Map ? existing : {});
        for (final entry in s.entries) {
          if (entry.value != null && entry.value.toString().isNotEmpty) {
            merged[entry.key.toString()] = entry.value;
          }
        }
        working[existingIndex] = merged;
      } else {
        working.add(Map<String, dynamic>.from(s));
      }
    }
    allStudents.assignAll(working);
  }

  /// Leader/Staff fetches directory of all students with today screen time overview from real API.
  Future<void> fetchStudentsList(
      {String? search, bool silent = false, bool refresh = true}) async {
    final query = (search ?? searchFilterController.text).trim();
    if (query.isNotEmpty) {
      isSearchingServer.value = true;
    }
    if (!silent) isLoadingStudents.value = true;
    if (refresh) {
      _serverLoadedCount = 0;
      hasMoreStudents.value = true;
      visibleStudentCount.value = uiBatchSize;
    }

    try {
      final baseParams = <String, dynamic>{
        'limit': pageSize,
        'offset': refresh ? 0 : _serverLoadedCount,
        if (query.isNotEmpty) 'search': query,
      };

      final response = await _apiClient.dio.get(
        '/screen-time/students',
        queryParameters: baseParams,
      );
      final data = response.data['data'] ?? response.data;
      if (query.isEmpty) _captureServerCounts(response.data);

      List<dynamic> loaded = [];
      int serverTotal = 0;

      if (data is List) {
        loaded = List<dynamic>.from(data);
        serverTotal = loaded.length;
      } else if (data is Map) {
        if (data['students'] != null && data['students'] is List) {
          loaded = List<dynamic>.from(data['students']);
        } else if (data['data'] != null && data['data'] is List) {
          loaded = List<dynamic>.from(data['data']);
        }
        serverTotal = toInt(
          data['total'] ??
              data['totalCount'] ??
              data['count'] ??
              data['totalStudents'] ??
              data['pagination']?['total'],
        );
      }

      _serverLoadedCount += loaded.length;

      if (loaded.isNotEmpty || (data is Map &&
          (data.containsKey('students') || data.containsKey('data')))) {
        if (query.isEmpty) {
          // The server's total wins (also when lower than the phonebook count
          // seeded earlier). A bare list has no total, only the page length.
          if (serverTotal > 0 && data is Map) {
            totalStudentsCount.value = serverTotal;
          } else if (refresh && loaded.length > totalStudentsCount.value) {
            totalStudentsCount.value = loaded.length;
          }
        }

        if (loaded.isEmpty) {
          hasMoreStudents.value = false;
        } else if (serverTotal > 0) {
          hasMoreStudents.value = _serverLoadedCount < serverTotal;
        } else {
          hasMoreStudents.value = loaded.length >= pageSize;
        }

        _mergeServerStudents(loaded, isRefresh: refresh);

        if (query.isEmpty) {
          _baseStudents
            ..clear()
            ..addAll(allStudents);
        }

        filterStudents(searchFilterController.text);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchStudentsList error: $e');
    } finally {
      isLoadingStudents.value = false;
      isSearchingServer.value = false;
    }

    // Phonebook-only residents are appended once every server page is loaded,
    // otherwise students not fetched yet would show up twice.
    if (query.isEmpty && !hasMoreStudents.value) {
      await _mergeHostelStudentsFromDirectory();
    }
    if (directoryFilter.value != 'All' || query.isNotEmpty) {
      unawaited(_fillViewport());
    }
  }

  /// Merges all hostel residents with an allocated room from the local Phonebook SQLite database
  /// so that every student who has a room number available is visible in Screen Time.
  Future<void> _mergeHostelStudentsFromDirectory() async {
    try {
      var pbStudents = await PhonebookDatabaseService.instance.searchStudents(
        status: 'active',
        limit: 5000,
        sortBy: 'room_asc',
      );

      if (pbStudents.isEmpty) {
        pbStudents = await PhonebookDatabaseService.instance.searchStudents(
          limit: 5000,
          sortBy: 'room_asc',
        );
      }

      if (pbStudents.isEmpty) {
        try {
          await PhonebookSyncService.instance.syncDirectory();
          pbStudents = await PhonebookDatabaseService.instance.searchStudents(
            limit: 5000,
            sortBy: 'room_asc',
          );
        } catch (_) {}
      }

      if (pbStudents.isEmpty) return;

      _integratePhonebookStudents(pbStudents);
    } catch (e) {
      debugPrint('[ScreenTime] _mergeHostelStudentsFromDirectory error: $e');
    }
  }

  void _integratePhonebookStudents(List<PhonebookStudent> pbStudents) {
    final existingKeys = <String>{};
    final existingPhones = <String>{};
    final existingAadhars = <String>{};
    final existingBankCodes = <String>{};

    for (final s in allStudents) {
      if (s is! Map) continue;
      final room = _normalizeRoomNumber(s['room'] ?? s['room_number'] ?? s['roomNumber']);
      final name = _normalizeStudentName(s['name'] ?? s['fullName']);
      final rawPhone = (s['phone'] ?? s['phoneNumber'] ?? s['phone_number'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\D'), '');
      final aadhar = (s['aadhar'] ?? s['student_code'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\D'), '');
      final bankCode = (s['bankCode'] ?? s['bank_code'] ?? '').toString().trim().toLowerCase();

      if (name.isNotEmpty && room.isNotEmpty) {
        existingKeys.add('$room::$name');
      }
      if (name.isNotEmpty) {
        existingKeys.add(name);
      }
      if (rawPhone.length >= 10) {
        existingPhones.add(rawPhone.substring(rawPhone.length - 10));
      }
      if (aadhar.length >= 8) {
        existingAadhars.add(aadhar);
      }
      if (bankCode.isNotEmpty) {
        existingBankCodes.add(bankCode);
      }
    }

    final toAdd = <Map<String, dynamic>>[];
    final addedKeysInThisBatch = <String>{};

    for (final ps in pbStudents) {
      if (!hasValidRoom({'room': ps.room})) continue;

      final pRoom = _normalizeRoomNumber(ps.room);
      final pName = _normalizeStudentName(ps.name);
      final pPhone = (ps.phones.isNotEmpty ? ps.phones.first.phone : '')
          .replaceAll(RegExp(r'\D'), '');
      final pAadhar = (ps.aadhar ?? '').replaceAll(RegExp(r'\D'), '');
      final pBank = (ps.bankCode ?? '').trim().toLowerCase();

      final roomAndNameKey = '$pRoom::$pName';
      final hasMatchingRoomAndName =
          existingKeys.contains(roomAndNameKey) || addedKeysInThisBatch.contains(roomAndNameKey);
      final hasMatchingName =
          existingKeys.contains(pName) || addedKeysInThisBatch.contains(pName);
      final hasMatchingPhone = pPhone.length >= 10 &&
          existingPhones.contains(pPhone.substring(pPhone.length - 10));
      final hasMatchingAadhar =
          pAadhar.length >= 8 && existingAadhars.contains(pAadhar);
      final hasMatchingBank =
          pBank.isNotEmpty && existingBankCodes.contains(pBank);

      if (hasMatchingRoomAndName ||
          hasMatchingName ||
          hasMatchingPhone ||
          hasMatchingAadhar ||
          hasMatchingBank) {
        continue;
      }

      addedKeysInThisBatch.add(roomAndNameKey);
      addedKeysInThisBatch.add(pName);
      if (pPhone.length >= 10) existingPhones.add(pPhone.substring(pPhone.length - 10));
      if (pAadhar.length >= 8) existingAadhars.add(pAadhar);
      if (pBank.isNotEmpty) existingBankCodes.add(pBank);

      toAdd.add({
        'id': '',
        'name': ps.name,
        'room': ps.room,
        'room_number': ps.room,
        'phone': ps.phones.isNotEmpty ? ps.phones.first.phone : '',
        'aadhar': ps.aadhar ?? '',
        'bankCode': ps.bankCode ?? '',
        'bank_code': ps.bankCode ?? '',
        'groupName': ps.groupName ?? '',
        'isOnline': 0,
        'isScreenOn': 0,
        'totalScreenTimeMinutes': 0,
        'nightScreenTimeMinutes': 0,
        'currentApp': '',
        'status': 'Offline',
        'isDeviceEnrolled': false,
      });
    }

    if (toAdd.isNotEmpty) {
      allStudents.addAll(toAdd);
      if (searchFilterController.text.trim().isEmpty) {
        _baseStudents
          ..clear()
          ..addAll(allStudents);
      }
      filterStudents(searchFilterController.text);
    }
  }

  /// Triggered by scrolling near bottom: loads more from memory, or from server if exhausted
  Future<void> loadMoreItems() async {
    if (visibleStudentCount.value < filteredStudents.length) {
      visibleStudentCount.value =
          (visibleStudentCount.value + uiBatchSize).clamp(
              0, filteredStudents.length);
      // Running low on loaded rows: fetch the next page before the user hits the end.
      if (hasMoreStudents.value &&
          filteredStudents.length - visibleStudentCount.value < uiBatchSize) {
        unawaited(fetchMoreStudents());
      }
      return;
    }

    if (hasMoreStudents.value && !isLoadingStudents.value &&
        !isLoadingMore.value) {
      await fetchMoreStudents();
    }
  }

  Future<void> fetchMoreStudents() async {
    if (isLoadingMore.value || !hasMoreStudents.value) return;
    isLoadingMore.value = true;
    try {
      final query = searchFilterController.text.trim();
      final baseParams = <String, dynamic>{
        'limit': pageSize,
        'offset': _serverLoadedCount,
        if (query.isNotEmpty) 'search': query,
      };

      final response = await _apiClient.dio.get(
        '/screen-time/students',
        queryParameters: baseParams,
      );
      final data = response.data['data'] ?? response.data;
      List<dynamic> loaded = [];
      int serverTotal = 0;
      if (data is List) {
        loaded = List<dynamic>.from(data);
        serverTotal = loaded.length;
      } else if (data is Map) {
        if (data['students'] != null && data['students'] is List) {
          loaded = List<dynamic>.from(data['students']);
        } else if (data['data'] != null && data['data'] is List) {
          loaded = List<dynamic>.from(data['data']);
        }
        serverTotal = toInt(
          data['total'] ??
              data['totalCount'] ??
              data['count'] ??
              data['totalStudents'],
        );
      }
      if (serverTotal > 0 && query.isEmpty && data is Map) {
        totalStudentsCount.value = serverTotal;
      }

      _serverLoadedCount += loaded.length;

      if (loaded.isNotEmpty || (data is Map &&
          (data.containsKey('students') || data.containsKey('data')))) {
        if (loaded.isEmpty) {
          hasMoreStudents.value = false;
        } else if (serverTotal > 0) {
          hasMoreStudents.value = _serverLoadedCount < serverTotal;
        } else {
          hasMoreStudents.value = loaded.length >= pageSize;
        }
        if (loaded.isNotEmpty) {
          _mergeServerStudents(loaded, isRefresh: false);
          if (query.isEmpty) {
            _baseStudents
              ..clear()
              ..addAll(allStudents);
          }
          filterStudents(searchFilterController.text);
          visibleStudentCount.value =
              (visibleStudentCount.value + uiBatchSize).clamp(
                  0, filteredStudents.length);
        }
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchMoreStudents error: $e');
    } finally {
      isLoadingMore.value = false;
    }
    if (!hasMoreStudents.value && searchFilterController.text.trim().isEmpty) {
      await _mergeHostelStudentsFromDirectory();
    }
  }

  /// A filter or search can match too few of the loaded rows to fill the screen
  /// (so nothing scrolls); keep pulling pages, a few at most, until it does.
  Future<void> _fillViewport() async {
    var pages = 0;
    while (hasMoreStudents.value &&
        !isLoadingStudents.value &&
        !isLoadingMore.value &&
        filteredStudents.length < uiBatchSize &&
        pages++ < 5) {
      await fetchMoreStudents();
    }
  }

  /// Silent periodic refresh: re-fetches the pages already loaded and updates
  /// them in place, so the list keeps its length and scroll position.
  Future<void> _refreshLoadedStudents() async {
    if (searchFilterController.text.trim().isNotEmpty ||
        _serverLoadedCount == 0 ||
        isLoadingMore.value) {
      await fetchStudentsList(silent: true);
      return;
    }
    try {
      final end = _serverLoadedCount;
      for (var offset = 0; offset < end; offset += pageSize) {
        final response = await _apiClient.dio.get(
          '/screen-time/students',
          queryParameters: {'limit': pageSize, 'offset': offset},
        );
        final data = response.data['data'] ?? response.data;
        if (offset == 0) _captureServerCounts(response.data);
        final raw = data is List
            ? data
            : (data is Map ? (data['students'] ?? data['data']) : null);
        if (raw is! List || raw.isEmpty) break;
        _mergeServerStudents(List<dynamic>.from(raw), isRefresh: false);
      }
      _baseStudents
        ..clear()
        ..addAll(allStudents);
      filterStudents(searchFilterController.text);
    } catch (e) {
      debugPrint('[ScreenTime] _refreshLoadedStudents error: $e');
    }
  }

  /// Called on every keystroke in search box: instant local filter + debounced server query
  void onSearchChanged(String query) {
    // 1. Instant local filter
    filterStudents(query);

    // 2. Debounced server search
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      isSearchingServer.value = false;
      if (_baseStudents.isNotEmpty) {
        allStudents.assignAll(_baseStudents);
        filterStudents('');
      } else {
        fetchStudentsList(silent: true, refresh: true);
      }
      return;
    }

    isSearchingServer.value = true;
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      fetchStudentsList(search: trimmed, silent: true, refresh: true);
    });
  }

  /// Called when user presses Search/Done on soft keyboard
  void onSearchSubmitted(String query) {
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    fetchStudentsList(search: trimmed, silent: false, refresh: true);
  }

  /// Clear search input and restore directory
  void clearSearch() {
    _searchDebounceTimer?.cancel();
    searchFilterController.clear();
    searchText.value = '';
    isSearchingServer.value = false;
    visibleStudentCount.value = uiBatchSize;
    if (_baseStudents.isNotEmpty) {
      allStudents.assignAll(_baseStudents);
      filterStudents('');
    } else {
      fetchStudentsList(silent: true, refresh: true);
    }
  }

  /// Filter students locally by name, room, or Aadhar/student code/phone
  void filterStudents(String query) {
    searchText.value = query;
    final q = query.trim().toLowerCase();
    final filter = directoryFilter.value;

    final matched = allStudents.where((student) {
      if (!_matchesDirectoryFilter(student, filter)) return false;
      if (q.isEmpty) return true;
      final name = (student['name'] ?? '').toString().toLowerCase();
      final room = (student['room'] ?? student['room_number'] ??
          student['roomNumber'] ?? '').toString().toLowerCase();
      final aadhar = (student['aadhar'] ?? student['student_code'] ??
          student['studentCode'] ?? '').toString().toLowerCase();
      final phone = (student['phone'] ?? student['phone_number'] ??
          student['phoneNumber'] ?? '').toString().toLowerCase();

      final qTrimmed = q.replaceFirst(RegExp(r'^0+'), '');
      final aadharTrimmed = aadhar.replaceFirst(RegExp(r'^0+'), '');

      return name.contains(q) ||
          room.contains(q) ||
          aadhar.contains(q) ||
          (qTrimmed.isNotEmpty && aadharTrimmed.contains(qTrimmed)) ||
          phone.contains(q);
    }).toList();

    // Students needing attention first, then online students, then heaviest users, then room number.
    matched.sort((a, b) {
      final attA = isStudentTampered(a) || isStudentLocked(a);
      final attB = isStudentTampered(b) || isStudentLocked(b);
      if (attA != attB) return attA ? -1 : 1;

      final onA = isStudentOnline(a);
      final onB = isStudentOnline(b);
      if (onA != onB) return onA ? -1 : 1;

      final minsA = toInt(a['totalScreenTimeMinutes'] ?? a['todayScreenTimeMinutes'] ?? a['total_screen_time_minutes']);
      final minsB = toInt(b['totalScreenTimeMinutes'] ?? b['todayScreenTimeMinutes'] ?? b['total_screen_time_minutes']);
      if (minsA != minsB) return minsB.compareTo(minsA);

      final roomA = (a['room'] ?? a['room_number'] ?? a['roomNumber'] ?? '').toString();
      final roomB = (b['room'] ?? b['room_number'] ?? b['roomNumber'] ?? '').toString();
      final roomCmp = _compareRoomStrings(roomA, roomB);
      if (roomCmp != 0) return roomCmp;

      final nameA = (a['name'] ?? a['fullName'] ?? '').toString();
      final nameB = (b['name'] ?? b['fullName'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    final seen = <String>{};
    final seenIds = <String>{};
    final deduplicated = <dynamic>[];

    for (final s in matched) {
      if (s is! Map) continue;
      final id = s['id']?.toString().trim() ?? '';
      final name = _normalizeStudentName(s['name'] ?? s['fullName']);
      final room = _normalizeRoomNumber(s['room'] ?? s['room_number'] ?? s['roomNumber']);
      final key = room.isNotEmpty && name.isNotEmpty ? '$room::$name' : name;

      if (id.isNotEmpty && seenIds.contains(id)) continue;
      if (key.isNotEmpty && seen.contains(key)) continue;

      if (id.isNotEmpty) seenIds.add(id);
      if (key.isNotEmpty) seen.add(key);
      deduplicated.add(s);
    }

    filteredStudents.assignAll(deduplicated);
  }

  /// Select a student from list to inspect detailed screen time from real API
  void selectStudent(dynamic student) {
    selectedStudent.value = student;

    // Retain all existing stats from the student object immediately so data is visible
    totalMinutesToday.value = toInt(student['totalScreenTimeMinutes']);
    nightMinutesToday.value = toInt(student['nightScreenTimeMinutes']);
    isOnline.value = isStudentOnline(student);
    isScreenOn.value = isStudentScreenOn(student);
    currentApp.value = (student['currentApp'] ?? 'Idle').toString();

    // Extract blocked packages & policy from student if present
    final directBlocked = student['blockedPackages'] ??
        student['blocked_packages'];
    if (directBlocked is List) {
      blockedPackages.assignAll(
          directBlocked.map((e) => e.toString()).toList());
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
      appBreakdown.assignAll(_deduplicateAndSortApps(directApps));
      _syncBlockedStatusToApps();
    } else {
      appBreakdown.clear();
    }
    historyRecords.clear();
    selectedDate.value = '';
    dateSpecificApps.clear();
    dateSpecificTotals.clear();
    dateSpecificNight.clear();

    final id = _studentId;
    if (id.isNotEmpty) {
      _loadCachedStudentScreenTime(id);
    }

    debugPrint(
        '[ScreenTime] selectStudent: ${student['name']}, id=$_studentId, initialMins=${totalMinutesToday
            .value}, appsCount=${appBreakdown.length}');

    fetchLiveStatus();
    fetchHistory();
    fetchStudentPolicies();
    fetchAppRequests(studentId: id);
  }

  /// Return back to all students directory list
  void clearSelectedStudent() {
    selectedStudent.value = null;
    openedWithDirectTarget.value = false;
    _resetDetail();
    clearSearch();
    fetchAppRequests();
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
    selectedDate.value = '';
    dateSpecificApps.clear();
    dateSpecificTotals.clear();
    dateSpecificNight.clear();
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

    final onlineVal = data['isOnline'] ?? data['is_online'] ?? data['online'];
    if (onlineVal != null) {
      isOnline.value = toBool(onlineVal);
    }

    final screenVal = data['isScreenOn'] ?? data['is_screen_on'] ??
        data['screenOn'] ?? data['screen_on'];
    if (screenVal != null) {
      isScreenOn.value = toBool(screenVal);
    }

    if (data['currentApp'] != null && data['currentApp']
        .toString()
        .isNotEmpty) {
      currentApp.value = data['currentApp'].toString();
    } else if (data['current_app'] != null && data['current_app']
        .toString()
        .isNotEmpty) {
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
    currentPackage.value =
        (data['currentPackage'] ?? data['current_package'] ?? '').toString();

    final rawApps = _extractAppsList(data);
    final newApps = _deduplicateAndSortApps(rawApps);
    if (newApps.isNotEmpty) {
      appBreakdown.assignAll(newApps);
      dateSpecificApps[todayDateStr] = newApps;
      AppIconCache.ingest(newApps);
      debugPrint('[ScreenTime] updated appBreakdown with ${appBreakdown
          .length} apps. First app: ${appBreakdown.first}');

      final appsSum = newApps.fold<int>(
        0,
        (sum, item) => sum + extractAppMinutes(item),
      );
      totalMinutesToday.value = appsSum > 0 ? appsSum : liveTotal;
    } else if (liveTotal > 0 || totalMinutesToday.value == 0) {
      totalMinutesToday.value = liveTotal;
    }
    dateSpecificTotals[todayDateStr] = totalMinutesToday.value;
    dateSpecificNight[todayDateStr] = nightMinutesToday.value;

    final policy = ScreenTimePolicy.tryParse(data, current: currentPolicy);
    if (policy != null) _applyPolicy(policy);
    _syncBlockedStatusToApps();

    final id = _studentId;
    if (id.isNotEmpty) {
      _saveCachedDateUsage(
        id,
        todayDateStr,
        appBreakdown,
        totalMinutesToday.value,
        nightMinutesToday.value,
      );
    }
  }

  void _syncBlockedStatusToApps() {
    if (appBreakdown.isEmpty) return;
    final updated = <dynamic>[];
    for (final it in appBreakdown) {
      if (it is Map) {
        final map = Map<String, dynamic>.from(it);
        final pkg = (map['packageName'] ?? map['package_name'] ?? '')
            .toString();
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
      final policy = ScreenTimePolicy.tryParse(
          response.data, current: currentPolicy);
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

  /// Set daily time limit for an app in minutes (0 = no limit)
  Future<void> setAppLimit(String packageName, String appName,
      int limitMinutes) async {
    final studentName = selectedStudent.value is Map
        ? (selectedStudent.value['name'] ?? 'Student')
        : 'Student';
    final id = _studentId;
    if (id.isEmpty) {
      AppSnackbar.info(
        'Device Not Setup',
        '$studentName has not installed the monitoring app on their phone yet.',
      );
      return;
    }
    final previous = currentPolicy;
    final updatedLimits = Map<String, int>.from(previous.appLimits);
    if (limitMinutes > 0) {
      updatedLimits[packageName] = limitMinutes;
    } else {
      updatedLimits.remove(packageName);
    }
    final updated = previous.copyWith(appLimits: updatedLimits);

    // Optimistic update; rolled back below if the API rejects it.
    _applyPolicy(updated);
    try {
      final isBlocked = blockedPackages.contains(packageName);
      await _apiClient.dio.post('/screen-time/apps/rule', data: {
        'student_id': id,
        'package_name': packageName,
        'app_name': appName,
        'is_blocked': isBlocked,
        'daily_limit_minutes': limitMinutes,
      });
      policyVersion.value = DateTime.now().toIso8601String();
      if (limitMinutes > 0) {
        AppSnackbar.success(
          'Limit Set',
          '$appName limited to ${formatMinutes(
              limitMinutes)}/day for $studentName.',
        );
      } else {
        AppSnackbar.info(
          'Limit Removed',
          'Time limit removed for $appName on $studentName\'s phone.',
        );
      }
    } catch (e) {
      debugPrint('[ScreenTime] setAppLimit error: $e');
      _applyPolicy(previous);
      AppSnackbar.error('Not Saved',
          'Could not update limit for $appName for $studentName. Please try again.');
    }
  }

  /// Toggle blocking or unblocking an app (Admin / Warden action)
  Future<void> toggleAppBlock(String packageName, String appName,
      bool block) async {
    final studentName = selectedStudent.value is Map
        ? (selectedStudent.value['name'] ?? 'Student')
        : 'Student';
    final id = _studentId;
    if (id.isEmpty) {
      AppSnackbar.info(
        'Device Not Setup',
        '$studentName has not installed the monitoring app on their phone yet.',
      );
      return;
    }
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
        AppSnackbar.warning(
            'App Restricted', '$appName is now restricted for $studentName.');
      } else {
        AppSnackbar.success(
            'App Allowed', '$appName restriction removed for $studentName.');
      }
    } catch (e) {
      debugPrint('[ScreenTime] toggleAppBlock error: $e');
      _applyPolicy(previous);
      AppSnackbar.error('Not Saved',
          'Could not update $appName for $studentName. Please try again.');
    }
  }

  /// Manually block an app by package name or preset
  Future<void> addCustomBlockedApp(String packageName, String appName) async {
    final pkg = packageName.trim();
    final name = appName
        .trim()
        .isNotEmpty ? appName.trim() : _guessAppName(pkg);
    if (pkg.isEmpty) {
      AppSnackbar.warning(
          'Invalid Package', 'Please enter a valid package identifier.');
      return;
    }
    await toggleAppBlock(pkg, name, true);
  }

  /// Fetch pending app installation requests for all students or a specific student
  Future<void> fetchAppRequests({String? studentId}) async {
    try {
      isLoadingAppRequests.value = true;
      final qp = <String, dynamic>{'status': 'pending'};
      if (studentId != null && studentId.isNotEmpty) {
        qp['student_id'] = studentId;
      }
      final res = await _apiClient.dio.get('/screen-time/apps/requests', queryParameters: qp);
      if (res.data is Map && res.data['data'] is List) {
        final list = List<Map<String, dynamic>>.from(
          (res.data['data'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );
        pendingAppRequests.assignAll(list);
      }
    } catch (e) {
      debugPrint('[ScreenTime] fetchAppRequests error: $e');
    } finally {
      isLoadingAppRequests.value = false;
    }
  }

  /// Approve or reject an app installation request (Warden action)
  Future<void> reviewAppRequest(int requestId, String action, {int durationMinutes = 15}) async {
    try {
      await _apiClient.dio.post(
        '/screen-time/apps/request/$requestId/review',
        data: {'action': action, 'duration_minutes': durationMinutes},
      );
      final isApproved = action == 'approve';
      pendingAppRequests.removeWhere((r) => r['id'] == requestId);
      if (isApproved) {
        AppSnackbar.success(
          'App Approved',
          'A $durationMinutes-minute install window has been granted on student device.',
        );
      } else {
        AppSnackbar.info('App Denied', 'Request rejected.');
      }
      if (_studentId.isNotEmpty) {
        fetchLiveStatus();
      }
    } catch (e) {
      debugPrint('[ScreenTime] reviewAppRequest error: $e');
      AppSnackbar.error('Action Failed', 'Could not review app request: $e');
    }
  }

  /// Submit a request for an app download/usage (Student action)
  Future<bool> submitAppRequest({
    required String appName,
    required String reason,
    String packageName = 'com.android.vending',
  }) async {
    try {
      await _apiClient.dio.post(
        '/screen-time/apps/request',
        data: {
          'app_name': appName.trim(),
          'package_name': packageName.trim(),
          'reason': reason.trim(),
        },
      );
      AppSnackbar.success(
        'Request Sent',
        'Your request for "$appName" has been sent to your hostel warden.',
      );
      return true;
    } catch (e) {
      debugPrint('[ScreenTime] submitAppRequest error: $e');
      AppSnackbar.error('Request Failed', 'Could not submit request: $e');
      return false;
    }
  }

  /// Emergency remote lock / unlock of the student's phone
  Future<void> toggleDeviceLock(bool lock) async {
    final studentName = selectedStudent.value is Map
        ? (selectedStudent.value['name'] ?? 'Student')
        : 'Student';
    final id = _studentId;
    if (id.isEmpty) {
      AppSnackbar.info(
        'Device Not Setup',
        '$studentName has not installed the monitoring app on their phone yet.',
      );
      return;
    }
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
    final id = _studentId;
    if (id.isEmpty) {
      AppSnackbar.info(
        'Device Not Setup',
        'This student has not completed phone onboarding yet.',
      );
      return;
    }
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
      AppSnackbar.error('Not Saved',
          'Could not save the curfew and daily limit. Please try again.');
    }
  }

  static bool _isSystemPackage(String pkg) {
    final lower = pkg.toLowerCase();
    return lower == 'android' ||
        lower == 'com.android.systemui' ||
        lower == 'com.google.android.permissioncontroller' ||
        lower == 'com.google.android.packageinstaller' ||
        lower == 'com.android.packageinstaller';
  }

  /// Merged and filtered app list for the UI, including restricted packages
  List<Map<String, dynamic>> get displayAppsList {
    final map = <String, Map<String, dynamic>>{};

    // 1. Add apps from the selected day's usage breakdown (excluding our own app and system framework)
    for (final it in currentDayRawApps) {
      if (it is Map) {
        final pkg = (it['packageName'] ??
            it['package_name'] ??
            it['package'] ??
            it['pkg'] ??
            it['appName'] ??
            it['name'] ??
            '')
            .toString();
        if (_isOurApp(pkg) || _isSystemPackage(pkg)) continue;

        final rawName = (it['appName'] ??
            it['app_name'] ??
            it['name'] ??
            it['title'] ??
            it['label'] ??
            '')
            .toString()
            .trim();
        final name = (rawName.isNotEmpty && rawName != pkg) ? rawName : _guessAppName(pkg);
        final mins = extractAppMinutes(it);
        final icon = (it['icon'] ?? it['iconBase64'] ?? it['icon_base64'])?.toString();
        if (map.containsKey(pkg)) {
          final prevMins = (map[pkg]!['minutes'] as int?) ?? 0;
          map[pkg]!['minutes'] = prevMins + mins;
          if (name.isNotEmpty && map[pkg]!['appName'] == pkg) {
            map[pkg]!['appName'] = name;
          }
          if (icon != null && icon.isNotEmpty && map[pkg]!['icon'] == null) {
            map[pkg]!['icon'] = icon;
          }
        } else {
          map[pkg] = {
            'packageName': pkg,
            'appName': name,
            'minutes': mins,
            if (icon != null && icon.isNotEmpty) 'icon': icon,
            'isBlocked': blockedPackages.contains(pkg) ||
                it['isBlocked'] == true ||
                it['is_blocked'] == true ||
                it['is_blocked'] == 1,
          };
        }
      }
    }

    // 2. Ensure all blocked packages appear even if not opened on this day
    for (final pkg in blockedPackages) {
      if (_isOurApp(pkg) || _isSystemPackage(pkg)) continue;
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

      if (tab == 'Used' || tab == 'Used Today' || tab == 'Used on Day') return mins > 0;
      if (tab == 'Restricted') return isBlocked;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final minsA = (a['minutes'] as int?) ?? 0;
      final minsB = (b['minutes'] as int?) ?? 0;
      if (minsB != minsA) return minsB.compareTo(minsA);
      final isBlockedA = a['isBlocked'] == true;
      final isBlockedB = b['isBlocked'] == true;
      if (isBlockedA != isBlockedB) return isBlockedA ? -1 : 1;
      return (a['appName'] as String).compareTo(b['appName'] as String);
    });

    return filtered;
  }

  static String _guessAppName(String pkg) {
    final lower = pkg.toLowerCase().trim();
    switch (lower) {
      case 'com.instagram.android':
        return 'Instagram';
      case 'com.snapchat.android':
        return 'Snapchat';
      case 'com.google.android.youtube':
        return 'YouTube';
      case 'com.facebook.katana':
        return 'Facebook';
      case 'com.facebook.orca':
        return 'Messenger';
      case 'com.zhiliaoapp.musically':
        return 'TikTok';
      case 'com.dts.freefireth':
      case 'com.dts.freefiremax':
        return 'Free Fire';
      case 'com.pubg.imobile':
        return 'BGMI';
      case 'com.discord':
        return 'Discord';
      case 'com.netflix.mediaclient':
        return 'Netflix';
      case 'com.spotify.music':
        return 'Spotify';
      case 'com.whatsapp':
        return 'WhatsApp';
      case 'com.whatsapp.w4b':
        return 'WhatsApp Business';
      case 'org.telegram.messenger':
        return 'Telegram';
      case 'com.android.chrome':
        return 'Chrome';
      case 'com.google.android.gm':
        return 'Gmail';
      case 'com.google.android.apps.messaging':
        return 'Messages';
      case 'com.google.android.dialer':
        return 'Phone';
      case 'com.google.android.apps.photos':
        return 'Photos';
      case 'com.google.android.apps.docs':
        return 'Drive';
      case 'com.google.android.apps.classroom':
        return 'Classroom';
      case 'com.google.android.apps.tachyon':
        return 'Google Meet';
      case 'us.zoom.videomeetings':
        return 'Zoom';
      case 'com.microsoft.teams':
        return 'Teams';
      case 'com.twitter.android':
      case 'com.x.android':
        return 'X (Twitter)';
      case 'com.amazon.mshop.android.shopping':
        return 'Amazon';
      case 'com.flipkart.android':
        return 'Flipkart';
      case 'in.swiggy.android':
        return 'Swiggy';
      case 'com.application.zomato':
        return 'Zomato';
      case 'in.startv.hotstar':
        return 'Disney+ Hotstar';
      case 'com.amazon.avod.thirdpartyclient':
        return 'Prime Video';
      case 'com.jio.media.ondemand':
        return 'JioCinema';
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
    } else if (data is Map && data['items'] is List) {
      records = List<dynamic>.from(data['items']);
    } else if (data is Map && data['rows'] is List) {
      records = List<dynamic>.from(data['rows']);
    } else if (data is Map && data['data'] is List) {
      records = List<dynamic>.from(data['data']);
    } else if (data is List) {
      records = List<dynamic>.from(data);
    }

    if (records != null && records.isNotEmpty) {
      for (final rec in records) {
        if (rec is Map) {
          final d = extractRecordDate(rec);
          if (d.isNotEmpty) {
            final recApps = _extractAppsList(rec);
            if (recApps.isNotEmpty) {
              final filtered = _deduplicateAndSortApps(recApps);
              if (filtered.isNotEmpty) {
                dateSpecificApps[d] = filtered;
                AppIconCache.ingest(filtered);
              }
            }
            final recTotal = toInt(
              rec['total_screen_time_minutes'] ??
                  rec['totalScreenTimeMinutes'] ??
                  rec['totalMinutes'] ??
                  rec['total_minutes'] ??
                  rec['usage_minutes'] ??
                  rec['minutes'],
            );
            if (recTotal > 0) {
              dateSpecificTotals[d] = recTotal;
            } else if (dateSpecificApps[d]?.isNotEmpty == true) {
              final sum = dateSpecificApps[d]!.fold<int>(0, (acc, item) {
                if (item is Map) {
                  return acc + extractAppMinutes(item);
                }
                return acc;
              });
              if (sum > 0) dateSpecificTotals[d] = sum;
            }
            final recNight = toInt(
              rec['night_screen_time_minutes'] ??
                  rec['nightScreenTimeMinutes'] ??
                  rec['nightMinutes'] ??
                  rec['night_minutes'] ??
                  rec['night'],
            );
            if (recNight > 0) {
              dateSpecificNight[d] = recNight;
            }

            final id = _studentId;
            if (id.isNotEmpty) {
              _saveCachedDateUsage(
                id,
                d,
                dateSpecificApps[d] ?? [],
                dateSpecificTotals[d] ?? 0,
                dateSpecificNight[d] ?? 0,
              );
            }
          }
        }
      }
      historyRecords.assignAll(records);
      debugPrint('[ScreenTime] loaded ${historyRecords.length} history records: ${historyRecords.first}');
      _extractAppsFromHistoryIfEmpty();

      final id = _studentId;
      if (id.isNotEmpty) {
        _saveCachedHistory(id, records);
      }

      // If totalMinutesToday is still 0, check today's record in history
      if (totalMinutesToday.value == 0) {
        final todayStr = todayDateStr;
        for (final rec in records) {
          if (extractRecordDate(rec) == todayStr) {
            final historyMins = toInt(
              rec['total_screen_time_minutes'] ??
                  rec['totalScreenTimeMinutes'] ??
                  rec['totalMinutes'] ??
                  rec['total_minutes'] ??
                  rec['usage_minutes'] ??
                  rec['minutes'],
            );
            if (historyMins > 0) {
              totalMinutesToday.value = historyMins;
            }
            break;
          }
        }
      }
    }

    // Proactively fetch and store past 7 days day-by-day in background
    _fetchPastDaysDayByDay();
  }

  /// Automatically fetches and stores past 7 days usage day-by-day in background
  Future<void> _fetchPastDaysDayByDay() async {
    final id = _studentId;
    if (id.isEmpty) return;
    final now = DateTime.now();
    for (int i = 1; i <= 7; i++) {
      if (id != _studentId) return; // Student selection changed
      final dt = now.subtract(Duration(days: i));
      final dStr = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      if (!dateSpecificApps.containsKey(dStr) || dateSpecificApps[dStr]!.isEmpty) {
        await fetchUsageForDate(dStr);
      }
    }
  }

  void _extractAppsFromHistoryIfEmpty() {
    if (appBreakdown.isNotEmpty) return;
    final todayStr = todayDateStr;
    // Look for today's record first
    for (final rec in historyRecords) {
      if (extractRecordDate(rec) == todayStr) {
        final apps = _extractAppsList(rec);
        if (apps.isNotEmpty) {
          final filteredApps = _deduplicateAndSortApps(apps);
          if (filteredApps.isNotEmpty) {
            appBreakdown.assignAll(filteredApps);
            _syncBlockedStatusToApps();
            debugPrint('[ScreenTime] extracted ${appBreakdown.length} apps from today history');
            return;
          }
        }
      }
    }
    // Fallback to most recent record
    for (final rec in historyRecords) {
      final apps = _extractAppsList(rec);
      if (apps.isNotEmpty) {
        final filteredApps = _deduplicateAndSortApps(apps);
        if (filteredApps.isNotEmpty) {
          appBreakdown.assignAll(filteredApps);
          _syncBlockedStatusToApps();
          debugPrint('[ScreenTime] extracted ${appBreakdown.length} apps from history');
          break;
        }
      }
    }
  }

  /// Extracts application usage breakdown from diverse backend payload shapes.
  /// Handles JSON text strings, arrays, and alternate column naming.
  static List<dynamic> extractAppsListStatic(dynamic source) {
    if (source == null) return [];
    if (source is String) {
      final trimmed = source.trim();
      if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
          (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
        try {
          final decoded = jsonDecode(trimmed);
          return extractAppsListStatic(decoded);
        } catch (_) {}
      }
      return [];
    }
    if (source is List) {
      if (source.isNotEmpty) {
        AppIconCache.ingest(source);
      }
      return source;
    }
    if (source is Map) {
      final candidates = [
        source['appUsageBreakdown'],
        source['app_usage_breakdown'],
        source['app_usage'],
        source['appUsage'],
        source['apps'],
        source['appBreakdown'],
        source['app_breakdown'],
        source['usageBreakdown'],
        source['usage_breakdown'],
        source['usage_logs'],
        source['usageLogs'],
        source['app_usage_logs'],
        source['appUsageLogs'],
        source['logs'],
        source['screenTime']?['appUsageBreakdown'],
        source['today']?['appUsageBreakdown'],
        source['liveStatus']?['appUsageBreakdown'],
        source['student']?['appUsageBreakdown'],
        source['breakdown'],
        source['data'],
        source['items'],
        source['records'],
        source['rows'],
      ];
      for (final c in candidates) {
        if (c == null) continue;
        if (c is List && c.isNotEmpty) {
          final first = c.first;
          if (first is Map &&
              (first.containsKey('package_name') ||
                  first.containsKey('packageName') ||
                  first.containsKey('package') ||
                  first.containsKey('pkg') ||
                  first.containsKey('app_name') ||
                  first.containsKey('appName') ||
                  first.containsKey('usage_minutes') ||
                  first.containsKey('minutes'))) {
            AppIconCache.ingest(c);
            return c;
          }
          // If candidate is a direct list of maps and we didn't match specific keys, still accept if source had a breakdown key
          final isExplicitBreakdownKey = c == source['appUsageBreakdown'] ||
              c == source['app_usage_breakdown'] ||
              c == source['apps'] ||
              c == source['app_usage'] ||
              c == source['appUsage'];
          if (isExplicitBreakdownKey && first is Map) {
            AppIconCache.ingest(c);
            return c;
          }
        }
        if (c is String) {
          final trimmed = c.trim();
          if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
              (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
            try {
              final decoded = jsonDecode(trimmed);
              final extracted = extractAppsListStatic(decoded);
              if (extracted.isNotEmpty) return extracted;
            } catch (_) {}
          }
        }
      }
    }
    return [];
  }

  List<dynamic> _extractAppsList(dynamic source) => extractAppsListStatic(source);

  static int extractAppMinutes(dynamic item) {
    if (item is! Map) return 0;
    return toInt(
      item['minutes'] ??
          item['total_minutes'] ??
          item['totalMinutes'] ??
          item['usage_minutes'] ??
          item['usageMinutes'] ??
          item['screen_time_minutes'] ??
          item['screenTimeMinutes'] ??
          item['duration'] ??
          item['time'] ??
          item['timeInMinutes'] ??
          item['usage_time'] ??
          item['time_spent'],
    );
  }

  /// The API may send minutes as int, double or string.
  static int toInt(dynamic value) {
    if (value is num) return value.round();
    if (value is String) return num.tryParse(value)?.round() ?? 0;
    return 0;
  }
}
