import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/models/geofence/geofence_policy_model.dart';
import '../../../core/network/repository/geofence/geofence_repository.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../phonebook/models/phonebook_models.dart';
import '../../phonebook/services/phonebook_database_service.dart';
import '../../phonebook/services/phonebook_sync_service.dart';
import 'app_requests_host.dart';
import 'screen_time_utils.dart';
import 'student_detail_controller.dart';

/// The Screen Time student directory: the paged and searchable list, the
/// summary counts, the hostel-wide night curfew and the pending app requests.
///
/// Opening a student creates a [StudentDetailController] for that student only
/// (see [selectStudent]); everything about one student lives there.
class ScreenTimeDirectoryController extends GetxController with WidgetsBindingObserver implements AppRequestsHost {
  /// The opened student's controller, or null while the list is showing.
  final Rxn<StudentDetailController> detail = Rxn<StudentDetailController>();

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

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _closeDetail();
    searchFilterController.dispose();
    pageScrollController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoRefresh();
  }

  Future<void> _autoRefresh() async {
    if (!currentRole.value.canViewScreenTime) return;
    // An open student's controller refreshes itself.
    if (detail.value != null) return;
    await Future.wait([
      _refreshLoadedStudents(),
      loadGlobalCurfew(),
      fetchAppRequests(),
    ]);
  }

  /// Manual refresh button.
  Future<void> refreshAll() async {
    if (!currentRole.value.canViewScreenTime) return;
    final open = detail.value;
    if (open != null) {
      await open.refreshAll();
    } else {
      await Future.wait([
        fetchStudentsList(),
        loadGlobalCurfew(),
        fetchAppRequests(),
      ]);
    }
  }

  /// Opens one student: creates that student's own controller.
  void selectStudent(dynamic student) {
    _closeDetail();
    selectedStudent.value = student;
    final controller = StudentDetailController(student);
    Get.put<StudentDetailController>(controller, tag: controller.tag);
    detail.value = controller;
  }

  /// Back to the directory list.
  void clearSelectedStudent() {
    selectedStudent.value = null;
    openedWithDirectTarget.value = false;
    _closeDetail();
    clearSearch();
    fetchAppRequests();
  }

  void _closeDetail() {
    final open = detail.value;
    if (open == null) return;
    detail.value = null;
    Get.delete<StudentDetailController>(tag: open.tag, force: true);
  }

  final ScreenTimeRepository _repo = ScreenTimeRepository();

  final GeofenceRepository _geofenceRepo = GeofenceRepository();

  /// Hostel-wide curfew policy (enforced natively on student phones).
  final Rx<GeofencePolicyModel> globalCurfewPolicy = const GeofencePolicyModel()
      .obs;

  final RxBool isLoadingCurfew = false.obs;

  final RxBool isUpdatingCurfew = false.obs;

  static const _refreshInterval = Duration(minutes: 1);

  final RxBool isLoadingStudents = false.obs;

  /// List of student app installation requests pending warden approval
  @override
  final RxList<Map<String, dynamic>> pendingAppRequests = <Map<String, dynamic>>[].obs;

  final RxBool isLoadingAppRequests = false.obs;

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

  static int _compareRoomStrings(String a, String b) {
    final intA = int.tryParse(a.replaceAll(RegExp(r'\D'), ''));
    final intB = int.tryParse(b.replaceAll(RegExp(r'\D'), ''));
    if (intA != null && intB != null) {
      return intA.compareTo(intB);
    }
    return a.compareTo(b);
  }

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
    _launchArgsHandledOnInit = applyLaunchArguments(Get.arguments);
  }

  bool _launchArgsHandledOnInit = false;

  /// Called by the Screen Time route once its screen is on show. When the
  /// controller was just created, [_checkInitialArguments] already used the
  /// arguments; when it already existed (the Safety tab of the operator shell
  /// registers it first) the arguments would otherwise be ignored and the
  /// screen would open on whatever it showed last.
  void reapplyLaunchArguments() {
    if (_launchArgsHandledOnInit) {
      _launchArgsHandledOnInit = false;
      return;
    }
    applyLaunchArguments(Get.arguments, refetch: true);
  }

  /// Returns true when [args] asked for something (a student or a search).
  bool applyLaunchArguments(dynamic args, {bool refetch = false}) {
    if (args is! Map) return false;
    final map = Map<String, dynamic>.from(args);
    final name = (map['name'] ?? map['fullName'] ?? '').toString().trim();
    final room = (map['room'] ?? '').toString().trim();
    final id = (map['id'] ?? map['studentId'] ?? '').toString().trim();

    if (isStudentId(id)) {
      openedWithDirectTarget.value = true;
      selectStudent({
        'id': id,
        'name': name.isNotEmpty ? name : 'Student',
        'room': room.isNotEmpty ? room : 'N/A',
      });
      return true;
    }

    if (name.isNotEmpty) {
      if (refetch) {
        // Back to the directory (not a previously opened student), filtered.
        selectedStudent.value = null;
        openedWithDirectTarget.value = false;
        _closeDetail();
        directoryFilter.value = 'All';
      }
      searchFilterController.text = name;
      searchText.value = name;
      if (refetch) {
        fetchStudentsList(search: name, silent: false, refresh: true);
      }
      return true;
    }
    return false;
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

  @visibleForTesting
  void mergeServerStudentsForTest(List<dynamic> loaded, {bool isRefresh = false}) =>
      _mergeServerStudents(loaded, isRefresh: isRefresh);

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
        // Two students with different ids are different people even when
        // their name and room look alike; only id-less rows dedupe by name.
        if (idStr.isEmpty && key.isNotEmpty && seenKeys.contains(key)) continue;

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
        if (idStr.isNotEmpty && existingId.isNotEmpty) {
          // Both have a real id: they are the same student only if the ids
          // match. Never merge on name / phone / Aadhar / bank code, or the
          // other student's id overwrites this one (903 became 931).
          if (existingId == idStr) {
            existingIndex = i;
            break;
          }
          continue;
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
      final page = await _repo.students(
        limit: pageSize,
        offset: refresh ? 0 : _serverLoadedCount,
        search: query,
      );
      if (query.isEmpty) _captureServerCounts(page.body);

      final loaded = page.students;
      final serverTotal = page.total;

      _serverLoadedCount += loaded.length;

      if (page.hasPayload) {
        if (query.isEmpty) {
          // The server's total wins (also when lower than the phonebook count
          // seeded earlier). A bare list has no total, only the page length.
          if (serverTotal > 0 && page.totalReported) {
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
      final page = await _repo.students(
        limit: pageSize,
        offset: _serverLoadedCount,
        search: query,
      );
      final loaded = page.students;
      final serverTotal = page.total;
      if (serverTotal > 0 && query.isEmpty && page.totalReported) {
        totalStudentsCount.value = serverTotal;
      }

      _serverLoadedCount += loaded.length;

      if (page.hasPayload) {
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
        final page = await _repo.students(limit: pageSize, offset: offset);
        if (offset == 0) _captureServerCounts(page.body);
        if (page.students.isEmpty) break;
        _mergeServerStudents(page.students, isRefresh: false);
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
      if (id.isEmpty && key.isNotEmpty && seen.contains(key)) continue;

      if (id.isNotEmpty) seenIds.add(id);
      if (key.isNotEmpty) seen.add(key);
      deduplicated.add(s);
    }

    filteredStudents.assignAll(deduplicated);
  }

  /// Fetch pending app installation requests for all students or a specific student
  Future<void> fetchAppRequests({String? studentId}) async {
    try {
      isLoadingAppRequests.value = true;
      pendingAppRequests.assignAll(
        await _repo.pendingAppRequests(studentId: studentId),
      );
    } catch (e) {
      debugPrint('[ScreenTime] fetchAppRequests error: $e');
    } finally {
      isLoadingAppRequests.value = false;
    }
  }

  /// Approve or reject an app installation request (Warden action)
  @override
  Future<void> reviewAppRequest(int requestId, String action, {int durationMinutes = 15}) async {
    if (requestId <= 0) {
      AppSnackbar.error('Action Failed', 'Invalid request ID.');
      return;
    }
    try {
      await _repo.reviewAppRequest(requestId, action, durationMinutes: durationMinutes);
      final isApproved = action == 'approve';
      pendingAppRequests.removeWhere((r) {
        final rId = int.tryParse(
            (r['id'] ?? r['request_id'] ?? r['requestId'])?.toString() ?? '');
        return rId == requestId;
      });
      if (isApproved) {
        AppSnackbar.success(
          'App Approved',
          'A $durationMinutes-minute install window has been granted on student device.',
        );
      } else {
        AppSnackbar.info('App Denied', 'Request rejected.');
      }
    } catch (e) {
      debugPrint('[ScreenTime] reviewAppRequest error: $e');
      AppSnackbar.error('Action Failed', 'Could not review app request: $e');
    }
  }
}
