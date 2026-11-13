import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../services/caller_id_service.dart';
import '../models/phonebook_models.dart';
import '../services/phone_number_normalizer.dart';
import '../services/phonebook_database_service.dart';
import '../services/phonebook_favourites_service.dart';
import '../services/phonebook_sync_service.dart';
import '../widgets/alpha_scroll_rail.dart' show RailEntry;

class PhonebookController extends GetxController {
  final searchController = TextEditingController();

  /// Mirrors [searchController] text so `Obx` widgets can react to it.
  final searchText = ''.obs;

  final students = <PhonebookStudent>[].obs;
  final isLoading = true.obs;
  final isSyncing = false.obs;
  final isSearching = false.obs;

  // Tag filter
  final selectedTag = 'All'.obs;
  final availableTags = <StudentTag>[].obs;

  // Scroll controller exposed so the alphabet rail can jump to a letter
  final listScrollController = ScrollController();

  /// Maps first letter (uppercase, or '#') → first list index for that letter.
  /// Rebuilt every time [students] changes.
  final alphaIndex = <String, int>{}.obs;

  /// Same map for alumni, who are listed after all residents.
  final alumniAlphaIndex = <String, int>{}.obs;

  /// The index rail's letters: student letters first (A-Z, '#' last), then
  /// alumni letters in the same order.
  List<RailEntry> get railEntries {
    int order(String a, String b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    }

    final students = alphaIndex.keys.toList()..sort(order);
    final alumni = alumniAlphaIndex.keys.toList()..sort(order);
    return [
      for (final l in students) RailEntry(l),
      for (final l in alumni) RailEntry(l, alumni: true),
    ];
  }

  /// Drives the student SuperSliverList. It jumps straight to an item without
  /// building every card in between, which is what makes the A-Z rail smooth.
  final listController = ListController();

  /// Measures every row in the background once the list has settled, so the
  /// rail's jumps land on exactly the right row instead of an estimate.
  final extentPolicy = PrecalculateExtentsPolicy();

  /// Section letter for a name: its uppercase first letter, or '#' for anything else.
  static String letterOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '#';
    final first = trimmed[0].toUpperCase();
    return RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
  }

  // Primary filter
  final selectedGroup = 'All'.obs;

  // Secondary filters
  final selectedFloor = 'All'.obs;
  final selectedStatus = 'All'.obs; // 'All', 'Active', 'Alumni'
  final onlyWithDob = false.obs;
  final onlyWithParents = false.obs;
  final onlyWithWhatsApp = false.obs;
  final onlyWithAddress = false.obs;
  final onlyWithAadhar = false.obs;

  // Sort order
  final selectedSort = 'Name (A-Z)'.obs;

  // Multi-Selection State
  final isSelectionMode = false.obs;
  final selectedStudentIds = <String>{}.obs;

  int get selectedCount => selectedStudentIds.length;
  bool isStudentSelected(String id) => selectedStudentIds.contains(id);
  bool get areAllVisibleSelected =>
      students.isNotEmpty && students.every((s) => selectedStudentIds.contains(s.id));

  final lastSync = Rxn<DateTime>();
  final totalCachedCount = 0.obs;

  /// Students this admin dials most, shown in the Favourites strip.
  /// Filled automatically from call counts kept on this device.
  final favourites = <PhonebookFavourite>[].obs;

  /// Explicitly pinned student keys for fast reactive lookups.
  final pinnedStudentKeys = <String>{}.obs;

  /// Truecaller-style caller ID for this warden's phone.
  final callerId = const CallerIdStatus().obs;
  final isEnablingCallerId = false.obs;

  Timer? _debounceTimer;

  static const List<String> hshGroups = [
    'All',
    'Favourites',
    'Param',
    'Pavitra',
    'Pulkit',
    'Paramanand',
    'Alumni',
  ];

  static const List<String> floorOptions = [
    'All',
    'Ground',
    'Floor 1',
    'Floor 2',
    'Floor 3',
    'Floor 4',
    'Floor 5',
    'Floor 6',
    'Floor 7',
    'Floor 8',
    'Floor 9',
  ];

  /// Floor number for a [floorOptions] chip ('Ground' is 0), or null for 'All'.
  static int? floorNumberOf(String option) {
    if (option == 'Ground') return 0;
    return int.tryParse(option.replaceAll(RegExp(r'\D'), ''));
  }

  static const List<String> statusOptions = [
    'All',
    'Active Residents',
    'Alumni / Left',
  ];

  static const List<String> sortOptions = [
    'Name (A-Z)',
    'Name (Z-A)',
    'Room (Low-High)',
    'Room (High-Low)',
    'Floor (Low-High)',
    'Floor (High-Low)',
  ];

  int get activeFilterCount {
    int count = 0;
    if (selectedGroup.value != 'All') count++;
    if (selectedFloor.value != 'All') count++;
    if (selectedStatus.value != 'All') count++;
    if (selectedTag.value != 'All') count++;
    if (onlyWithDob.value) count++;
    if (onlyWithParents.value) count++;
    if (onlyWithWhatsApp.value) count++;
    if (onlyWithAddress.value) count++;
    if (onlyWithAadhar.value) count++;
    if (selectedSort.value != 'Name (A-Z)') count++;
    return count;
  }

  Timer? _periodicSyncTimer;
  DateTime? _lastSyncAttemptTime;

  @override
  void onInit() {
    super.onInit();
    _checkAdminAccess();
    _startPeriodicSync();
    _loadAvailableTags();
  }

  Future<void> _loadAvailableTags() async {
    try {
      if (Get.isRegistered<TagsRepository>()) {
        final tags = await Get.find<TagsRepository>().getTags();
        availableTags.assignAll(dedupeTags(tags));
      }
    } catch (_) {}
  }

  @override
  void onReady() {
    super.onReady();
    // When returning to this screen or if controller remained in memory,
    // refresh if data hasn't been synced recently.
    _triggerAutoSyncIfStale();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _periodicSyncTimer?.cancel();
    listScrollController.dispose();
    listController.dispose();
    searchController.dispose();
    super.onClose();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    // Auto-refresh contacts every 15 minutes while the screen remains open
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      debugPrint('[PhonebookController] ⏰ Periodic auto-sync triggered');
      syncNow(silent: true);
    });
  }

  void _triggerAutoSyncIfStale() {
    if (_lastSyncAttemptTime == null ||
        DateTime.now().difference(_lastSyncAttemptTime!) > const Duration(minutes: 5)) {
      debugPrint('[PhonebookController] 🔄 Stale check: triggering background sync');
      syncNow(silent: true);
    }
  }

  Future<void> _checkAdminAccess() async {
    final role = await Get.find<SessionStore>().role;
    if (!role.canOperate) {
      Get.back();
      AppSnackbar.error(
        'Access Denied',
        'The Phonebook is restricted to Hostel Administrators and Wardens only.',
      );
      return;
    }

    _applyLaunchArguments();

    // 1. Fire live API sync immediately in the background so it fetches right away
    syncNow(silent: true);

    // 2. Concurrently load local SQLite cached data for immediate zero-latency display
    await _loadMetadata();
    await search();
    await loadFavourites();
    await refreshCallerIdStatus();

    // iOS: if Caller ID is already enabled, push a fresh directory every time
    // the phonebook opens so labels are never stale.
    if (GetPlatform.isIOS && callerId.value.enabled) {
      CallerIdService.syncDirectory();
    }
  }

  /// Opened from a caller-ID popup/notification → jump straight to that student.
  void _applyLaunchArguments() {
    final args = Get.arguments;
    final query = args is Map ? (args['query'] ?? args['studentId'] ?? '').toString() : '';
    if (query.isNotEmpty) {
      searchController.text = query;
      searchText.value = query;
    }
  }

  Future<void> refreshCallerIdStatus() async {
    callerId.value = await CallerIdService.status();
  }

  /// Android: system role sheet (+ overlay permission). iOS: opens Settings → Phone.
  Future<void> enableCallerId() async {
    isEnablingCallerId.value = true;
    try {
      final ok = await CallerIdService.requestEnable();
      await refreshCallerIdStatus();
      if (ok && !callerId.value.overlayGranted && GetPlatform.isAndroid) {
        await CallerIdService.requestOverlay();
      }
      if (GetPlatform.isIOS) {
        await CallerIdService.syncDirectory();
      }
    } finally {
      isEnablingCallerId.value = false;
    }
  }

  Future<void> disableCallerId() async {
    await CallerIdService.setActive(false);
    await refreshCallerIdStatus();
  }

  bool _checkedFirstTimeSheet = false;

  /// Shows the Caller ID intro/setup sheet once on the first time visiting the phonebook.
  Future<void> checkFirstTimeCallerId(VoidCallback onShowSheet) async {
    if (_checkedFirstTimeSheet) return;
    _checkedFirstTimeSheet = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'phonebook_caller_id_sheet_shown';
      final alreadyShown = prefs.getBool(key) ?? false;
      if (!alreadyShown) {
        await prefs.setBool(key, true);
        onShowSheet();
      }
    } catch (_) {}
  }

  Future<void> _loadMetadata() async {
    lastSync.value = await PhonebookSyncService.instance.getLastSyncTime();
    totalCachedCount.value =
        await PhonebookDatabaseService.instance.getStudentCount();
  }

  void onSearchChanged(String val) {
    searchText.value = val;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      search();
    });
  }

  void selectGroup(String group) {
    if (selectedGroup.value == group) {
      selectedGroup.value = 'All';
    } else {
      selectedGroup.value = group;
    }
    selectedStudentIds.clear();
    isSelectionMode.value = false;
    search();
  }

  void selectFloor(String floor) {
    selectedFloor.value = floor;
    selectedStudentIds.clear();
    isSelectionMode.value = false;
    search();
  }

  void selectStatus(String status) {
    selectedStatus.value = status;
    selectedStudentIds.clear();
    isSelectionMode.value = false;
    search();
  }

  void selectTag(String tag) {
    selectedTag.value = tag;
    selectedStudentIds.clear();
    isSelectionMode.value = false;
    search();
  }

  void selectSort(String sort) {
    selectedSort.value = sort;
    search();
  }

  void toggleOnlyWithDob(bool val) {
    onlyWithDob.value = val;
    search();
  }

  void toggleOnlyWithParents(bool val) {
    onlyWithParents.value = val;
    search();
  }

  void toggleOnlyWithWhatsApp(bool val) {
    onlyWithWhatsApp.value = val;
    search();
  }

  void toggleOnlyWithAddress(bool val) {
    onlyWithAddress.value = val;
    search();
  }

  void toggleOnlyWithAadhar(bool val) {
    onlyWithAadhar.value = val;
    search();
  }

  void resetAllFilters() {
    selectedGroup.value = 'All';
    selectedFloor.value = 'All';
    selectedStatus.value = 'All';
    selectedTag.value = 'All';
    onlyWithDob.value = false;
    onlyWithParents.value = false;
    onlyWithWhatsApp.value = false;
    onlyWithAddress.value = false;
    onlyWithAadhar.value = false;
    selectedSort.value = 'Name (A-Z)';
    clearSearch();
  }

  void resetFilter() {
    resetAllFilters();
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    searchController.clear();
    searchText.value = '';
    search();
  }

  /// Extracts the numeric prefix and any alphanumeric suffix from a room string.
  /// E.g. "2" -> (number: 2, suffix: ""), "10" -> (number: 10, suffix: ""), "101A" -> (number: 101, suffix: "A")
  static ({int number, String suffix}) parseRoomNumber(String? room) {
    if (room == null || room.trim().isEmpty) return (number: 999999, suffix: '');
    final trimmed = room.trim();
    if (trimmed.toLowerCase() == 'alumni' || trimmed.toLowerCase() == 'n/a') {
      return (number: 999999, suffix: trimmed);
    }
    final match = RegExp(r'^(\d+)(.*)$').firstMatch(trimmed);
    if (match != null) {
      final num = int.tryParse(match.group(1)!) ?? 999999;
      final suffix = match.group(2)?.trim() ?? '';
      return (number: num, suffix: suffix);
    }
    return (number: 999999, suffix: trimmed);
  }

  /// Compares two student rooms naturally (numeric room values, e.g. 2 < 10),
  /// keeping Alumni/NA consistently at the end.
  static int compareRooms(PhonebookStudent a, PhonebookStudent b, {bool ascending = true}) {
    final aRoom = a.room;
    final bRoom = b.room;
    final aAlumni = a.isAlumni || aRoom == null || aRoom.toLowerCase() == 'alumni' || aRoom.toLowerCase() == 'n/a';
    final bAlumni = b.isAlumni || bRoom == null || bRoom.toLowerCase() == 'alumni' || bRoom.toLowerCase() == 'n/a';

    if (aAlumni && !bAlumni) return 1;
    if (!aAlumni && bAlumni) return -1;
    if (aAlumni && bAlumni) {
      return a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
    }

    final pA = parseRoomNumber(aRoom);
    final pB = parseRoomNumber(bRoom);

    int cmp = pA.number.compareTo(pB.number);
    if (cmp == 0) {
      cmp = pA.suffix.compareTo(pB.suffix);
    }
    if (cmp == 0) {
      cmp = a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
    }

    return ascending ? cmp : -cmp;
  }

  Future<void> search({bool forceLoading = false}) async {
    if (forceLoading || students.isEmpty) {
      isLoading.value = true;
    } else {
      isSearching.value = true;
    }
    try {
      final floorNumber = floorNumberOf(selectedFloor.value);

      String? statusFilter;
      if (selectedStatus.value == 'Active Residents') {
        statusFilter = 'active';
      } else if (selectedStatus.value == 'Alumni / Left') {
        statusFilter = 'alumni';
      }

      String sortBy = 'name_asc';
      switch (selectedSort.value) {
        case 'Name (Z-A)':
          sortBy = 'name_desc';
          break;
        case 'Room (Low-High)':
          sortBy = 'room_asc';
          break;
        case 'Room (High-Low)':
          sortBy = 'room_desc';
          break;
        case 'Floor (Low-High)':
          sortBy = 'floor_asc';
          break;
        case 'Floor (High-Low)':
          sortBy = 'floor_desc';
          break;
        default:
          sortBy = 'name_asc';
          break;
      }

      final isFavGroup = selectedGroup.value == 'Favourites';
      final results = await PhonebookDatabaseService.instance.searchStudents(
        query: searchController.text.trim(),
        group: (selectedGroup.value == 'All' || isFavGroup) ? null : selectedGroup.value,
        floor: floorNumber,
        status: statusFilter,
        tag: selectedTag.value == 'All' ? null : selectedTag.value,
        hasDob: onlyWithDob.value ? true : null,
        hasParent: onlyWithParents.value ? true : null,
        hasWhatsApp: onlyWithWhatsApp.value ? true : null,
        hasAddress: onlyWithAddress.value ? true : null,
        hasAadhar: onlyWithAadhar.value ? true : null,
        sortBy: sortBy,
      );
      if (isFavGroup) {
        results.retainWhere((s) => isFavourite(s.id));
      }
      if (selectedSort.value == 'Name (A-Z)') {
        results.sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
      } else if (selectedSort.value == 'Name (Z-A)') {
        results.sort((a, b) => b.name.trim().toLowerCase().compareTo(a.name.trim().toLowerCase()));
      } else if (selectedSort.value == 'Room (Low-High)') {
        results.sort((a, b) => compareRooms(a, b, ascending: true));
      } else if (selectedSort.value == 'Room (High-Low)') {
        results.sort((a, b) => compareRooms(a, b, ascending: false));
      }
      if (selectedSort.value.startsWith('Name')) {
        // Residents (with a room) first, alumni after, each keeping name order.
        // Partitioned (List.sort isn't stable) so the name order is kept.
        final residents = results.where((st) => !st.isAlumni);
        final alumni = results.where((st) => st.isAlumni);
        final ordered = [...residents, ...alumni];
        results
          ..clear()
          ..addAll(ordered);
      }
      students.assignAll(results);
      _rebuildAlphaIndex(results);
      // Once the list has settled, measure the rows in the background so rail
      // jumps are exact. Not at startup, so the first paint stays fast.
      Future.delayed(const Duration(milliseconds: 600), () {
        extentPolicy.enabled = true;
      });
    } catch (e) {
      AppSnackbar.error('Search error', e.toString());
    } finally {
      isLoading.value = false;
      isSearching.value = false;
    }
  }

  /// Updates student tags in memory and SQLite cache without full reload
  void updateStudentTagsInList(String studentId, List<StudentTag> newTags) {
    final idx = students.indexWhere((s) => s.id == studentId || s.studentId == studentId);
    if (idx != -1) {
      students[idx] = students[idx].copyWith(tags: newTags);
      students.refresh();
    }
    PhonebookDatabaseService.instance.updateStudentTags(studentId, newTags);
  }

  /// Rebuilds the letter → first-index map from the current student list.
  void _rebuildAlphaIndex(List<PhonebookStudent> list) {
    final residents = <String, int>{};
    final alumni = <String, int>{};
    for (int i = 0; i < list.length; i++) {
      final target = list[i].isAlumni ? alumni : residents;
      target.putIfAbsent(letterOf(list[i].name), () => i);
    }
    alphaIndex.assignAll(residents);
    alumniAlphaIndex.assignAll(alumni);
  }

  @visibleForTesting
  void rebuildAlphaIndex(List<PhonebookStudent> list) => _rebuildAlphaIndex(list);

  /// Scrolls the list back to the top (bottom-bar Students tab tapped again).
  void scrollToTop() {
    if (!listScrollController.hasClients) return;
    listScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// Jumps the list to the first student (or alumni) of a rail letter.
  ///
  /// Always a jump, never an animation: the rail is dragged letter by letter,
  /// and with row extents precalculated ([extentPolicy]) the jump lands exactly.
  void scrollToRailEntry(RailEntry entry) {
    final index = entry.alumni ? alumniAlphaIndex[entry.letter] : alphaIndex[entry.letter];
    if (index == null || !listController.isAttached || !listScrollController.hasClients) return;
    listController.jumpToItem(
      index: index,
      scrollController: listScrollController,
      alignment: 0,
    );
  }

  Future<void> syncNow({bool silent = false}) async {
    if (isSyncing.value) {
      debugPrint('[PhonebookController] ⏳ syncNow skipped: already syncing in progress');
      return;
    }
    _lastSyncAttemptTime = DateTime.now();
    isSyncing.value = true;
    debugPrint('[PhonebookController] 🔄 Starting syncNow (silent: $silent)...');
    try {
      final res = await PhonebookSyncService.instance.syncDirectory();
      if (res.success) {
        await _loadMetadata();
        await search();
        await loadFavourites();
        CallerIdService.syncDirectory();
        debugPrint(
          '[PhonebookController] ✅ syncNow completed: ${res.totalStudents} students, ${res.totalPhones} phones',
        );
        if (!silent) {
          AppSnackbar.success(
            'Sync Complete',
            'Synchronized ${res.totalStudents} students with ${res.totalPhones} phone numbers.',
          );
        }
      } else {
        debugPrint('[PhonebookController] ⚠️ syncNow failed: ${res.errorMessage}');
        if (!silent) {
          AppSnackbar.error(
            'Sync Failed',
            res.errorMessage ?? 'Could not synchronize phonebook',
          );
        }
      }
    } catch (e) {
      debugPrint('[PhonebookController] ❌ syncNow exception: $e');
      if (!silent) {
        AppSnackbar.error('Sync Error', e.toString());
      }
    } finally {
      isSyncing.value = false;
    }
  }

  static String _norm(dynamic v) =>
      (v ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static final _studentIdPattern = RegExp(r'^[1-9]\d*$');

  /// The Screen Time `students.id` of a phonebook student, or null when it
  /// can't be told for certain (the caller then opens Screen Time searched by
  /// name instead).
  ///
  /// Phonebook records have no `students.id`, so the student is looked up in
  /// Screen Time's own directory. A result counts only if its bank code is
  /// the same as this student's bank code (code against code, never code
  /// against id) AND its name or room also matches, and exactly one result
  /// qualifies. The id sent on is the one that directory entry carries.
  Future<String?> findScreenTimeStudentId(PhonebookStudent student) async {
    final code = _norm(student.bankCode);
    if (code.isEmpty) return null;
    final name = _norm(student.name);
    final room = _norm(student.room);
    try {
      final dio = Get.find<ApiClient>().dio;
      for (final term in {student.name.trim(), student.bankCode!.trim()}) {
        if (term.isEmpty) continue;
        final res = await dio.get(
          '/screen-time/students',
          queryParameters: {'limit': 50, 'search': term},
        );
        var data = res.data is Map ? (res.data['data'] ?? res.data) : res.data;
        if (data is Map) data = data['students'] ?? data['data'];
        if (data is! List) continue;

        final matches = data.whereType<Map>().where((e) {
          final id = (e['id'] ?? '').toString().trim();
          if (!_studentIdPattern.hasMatch(id)) return false;
          if (_norm(e['bankCode'] ?? e['bank_code']) != code) return false;
          final sameName = _norm(e['name'] ?? e['fullName']) == name;
          final sameRoom = room.isNotEmpty &&
              _norm(e['room'] ?? e['room_number'] ?? e['roomNumber']) == room;
          return sameName || sameRoom;
        }).toList();
        if (matches.length == 1) return matches.first['id'].toString().trim();
      }
    } catch (e) {
      debugPrint('[Phonebook] findScreenTimeStudentId failed: $e');
    }
    return null;
  }

  final Map<String, int> _tagStudentIds = {};

  /// `students.id` for tag calls, without asking anyone: the strict
  /// [findScreenTimeStudentId] match first, then a lone Screen Time entry with
  /// the same name (and room, when both have one). Null when unsure. Cached
  /// per phonebook student.
  Future<int?> resolveStudentIdForTags(PhonebookStudent student) async {
    final cached = _tagStudentIds[student.id];
    if (cached != null) return cached;

    int? id = int.tryParse(await findScreenTimeStudentId(student) ?? '');
    if (id == null) {
      try {
        final page = await ScreenTimeRepository()
            .students(limit: 20, offset: 0, search: student.name.trim());
        final name = _norm(student.name);
        final room = _norm(student.room);
        final matches = page.students.whereType<Map>().where((e) {
          if (int.tryParse((e['id'] ?? '').toString().trim()) == null) return false;
          if (_norm(e['name'] ?? e['fullName']) != name) return false;
          final r = _norm(e['room'] ?? e['room_number'] ?? e['roomNumber']);
          return room.isEmpty || r.isEmpty || r == room;
        }).toList();
        if (matches.length == 1) {
          id = int.tryParse(matches.first['id'].toString().trim());
        }
      } catch (e) {
        debugPrint('[Phonebook] resolveStudentIdForTags failed: $e');
      }
    }
    if (id != null) _tagStudentIds[student.id] = id;
    return id;
  }

  /// Loads the student's current tags (system + assigned) and stores them in
  /// the list and cache. Returns null when the student can't be resolved or
  /// the request fails.
  Future<List<StudentTag>?> refreshStudentTags(PhonebookStudent student) async {
    try {
      final id = await resolveStudentIdForTags(student);
      if (id == null) return null;
      final res = await Get.find<TagsRepository>().getStudentTags(id);
      final tags = dedupeTags(res.allTags);
      updateStudentTagsInList(student.id, tags);
      return tags;
    } catch (e) {
      debugPrint('[Phonebook] refreshStudentTags failed: $e');
      return null;
    }
  }

  /// Opens the dialer for [phone]. When [student] is given, the call is
  /// counted so frequently dialled students appear in Favourites.
  Future<void> makeCall(String phone, {PhonebookStudent? student}) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (student != null) {
        await PhonebookFavouritesService.instance.recordCall(
          studentKey: student.id,
          name: student.name,
          phone: phone,
        );
        await loadFavourites();
      }
    } else {
      AppSnackbar.warning('Cannot Place Call', 'Dialer could not be opened for $phone');
    }
  }

  // --- FAVOURITES (pinned & most dialled) ---

  /// Rebuilds [favourites] from the stored call counts and pinned favourites,
  /// using the latest directory data for each student. Students no longer
  /// in the directory are skipped.
  Future<void> loadFavourites() async {
    try {
      final stats = await PhonebookFavouritesService.instance.topFavourites();
      final pinned = PhonebookFavouritesService.instance.pinnedKeys;
      pinnedStudentKeys.assignAll(pinned);

      final result = <PhonebookFavourite>[];
      for (final stat in stats) {
        final student = await _findStudentByKey(stat.studentKey, stat.name);
        if (student == null) continue;
        final phone = stat.mostDialledNumber.isNotEmpty
            ? stat.mostDialledNumber
            : student.primaryPhone;
        result.add(PhonebookFavourite(
          student: student,
          callCount: stat.totalCalls,
          phone: phone,
          phoneLabel: _labelForNumber(student, phone),
          isPinned: stat.isPinned || pinned.contains(stat.studentKey),
        ));
      }
      favourites.assignAll(result);
    } catch (e) {
      debugPrint('[PhonebookController] loadFavourites failed: $e');
    }
  }

  /// Whether a student is explicitly starred/pinned.
  bool isPinned(String studentKey) {
    return pinnedStudentKeys.contains(studentKey) ||
        PhonebookFavouritesService.instance.isPinned(studentKey);
  }

  /// Whether a student is either explicitly pinned or in the most-dialled favourites.
  bool isFavourite(String studentKey) {
    return isPinned(studentKey) || favourites.any((f) => f.student.id == studentKey);
  }

  /// Explicitly stars or unstars a student as a favourite.
  Future<void> toggleFavourite(PhonebookStudent student) async {
    HapticFeedback.mediumImpact();
    final isNowPinned = await PhonebookFavouritesService.instance.togglePin(
      studentKey: student.id,
      name: student.name,
    );
    if (isNowPinned) {
      pinnedStudentKeys.add(student.id);
    } else {
      pinnedStudentKeys.remove(student.id);
    }
    await loadFavourites();
    if (selectedGroup.value == 'Favourites') {
      await search();
    }
    AppSnackbar.success(
      isNowPinned ? 'Added to Favourites' : 'Removed from Favourites',
      isNowPinned
          ? '${student.name} was starred in your favourites.'
          : '${student.name} was removed from your favourites.',
    );
  }

  Future<PhonebookStudent?> _findStudentByKey(String key, String name) async {
    for (final s in students) {
      if (s.id == key) return s;
    }
    for (final query in {key, name}) {
      if (query.trim().isEmpty) continue;
      final results = await PhonebookDatabaseService.instance.searchStudents(
        query: query,
        limit: 20,
      );
      for (final s in results) {
        if (s.id == key) return s;
      }
    }
    return null;
  }

  /// Who a dialled number belongs to: the student's own number label,
  /// or Father / Mother / WhatsApp.
  static String _labelForNumber(PhonebookStudent student, String phone) {
    final n = PhoneNumberNormalizer.normalize(phone);
    bool same(String? other) =>
        other != null && n != null && PhoneNumberNormalizer.normalize(other) == n;
    for (final p in student.phones) {
      if (same(p.phone) || same(p.phoneNormalized)) {
        return p.label.isNotEmpty ? p.label : 'Mobile';
      }
    }
    if (same(student.fatherPhone)) return 'Father';
    if (same(student.motherPhone)) return 'Mother';
    if (same(student.whatsappNumber)) return 'WhatsApp';
    return 'Mobile';
  }

  /// Takes a student out of Favourites (their call count and pin status are reset).
  Future<void> removeFavourite(PhonebookFavourite favourite) async {
    HapticFeedback.mediumImpact();
    await PhonebookFavouritesService.instance.remove(favourite.student.id);
    pinnedStudentKeys.remove(favourite.student.id);
    favourites.removeWhere((f) => f.student.id == favourite.student.id);
    if (selectedGroup.value == 'Favourites') {
      await search();
    }
    AppSnackbar.success(
      'Removed from Favourites',
      '${favourite.student.name} will return here if you call them often again.',
    );
  }

  /// Opens a new Gmail message to [email]: the Gmail iOS app when installed,
  /// otherwise Gmail's compose link (which opens the Gmail app on Android and
  /// the website if the app is missing), and finally any mail app.
  Future<void> openEmail(String email) async {
    final to = email.trim();
    if (to.isEmpty) return;
    final encoded = Uri.encodeComponent(to);
    final attempts = <Uri>[
      if (defaultTargetPlatform == TargetPlatform.iOS)
        Uri.parse('googlegmail:///co?to=$encoded'),
      Uri.parse('https://mail.google.com/mail/?view=cm&fs=1&to=$encoded'),
      Uri(scheme: 'mailto', path: to),
    ];
    for (final uri in attempts) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    AppSnackbar.warning('Cannot Open Email', 'No email app could be opened for $to');
  }

  Future<void> sendSms(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('sms:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      AppSnackbar.warning('Cannot Send Message', 'Messaging app could not be opened for $phone');
    }
  }

  Future<void> openWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return;
    final intlPhone = cleaned.length == 10 ? '91$cleaned' : cleaned;
    final uri = Uri.parse('https://wa.me/$intlPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      AppSnackbar.warning('WhatsApp Unavailable', 'Could not open WhatsApp for $phone');
    }
  }

  void copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.success(
      'Copied',
      '$label copied to clipboard.',
    );
  }

  // --- SELECTION & SHARING METHODS ---

  void startSelectionMode(String initialId) {
    HapticFeedback.mediumImpact();
    selectedStudentIds.clear();
    selectedStudentIds.add(initialId);
    isSelectionMode.value = true;
  }

  void toggleSelectStudent(String id) {
    HapticFeedback.selectionClick();
    if (selectedStudentIds.contains(id)) {
      selectedStudentIds.remove(id);
      if (selectedStudentIds.isEmpty) {
        isSelectionMode.value = false;
      }
    } else {
      isSelectionMode.value = true;
      selectedStudentIds.add(id);
    }
  }

  void exitSelectionMode() {
    isSelectionMode.value = false;
    selectedStudentIds.clear();
  }

  void toggleSelectAll() {
    if (areAllVisibleSelected) {
      for (final s in students) {
        selectedStudentIds.remove(s.id);
      }
      if (selectedStudentIds.isEmpty) {
        isSelectionMode.value = false;
      }
    } else {
      isSelectionMode.value = true;
      selectedStudentIds.addAll(students.map((s) => s.id));
    }
  }

  void selectStudentGroup(String group) {
    selectGroup(group);
  }

  void selectAllInCurrentGroup() {
    if (students.isNotEmpty) {
      isSelectionMode.value = true;
      selectedStudentIds.addAll(students.map((s) => s.id));
    }
  }

  /// Native OS System Share for a single student profile
  Future<void> shareStudent(PhonebookStudent student) async {
    final text = student.toShareText();
    // ignore: deprecated_member_use
    await Share.share(
      text,
      subject: 'Hostel Student Profile - ${student.name}',
    );
  }

  /// Direct WhatsApp share for student details
  Future<void> shareToWhatsApp(String text) async {
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      copyToClipboard(text, 'Student Details');
    }
  }

  /// Native OS System Share for all selected students
  Future<void> shareSelectedStudents() async {
    final selected = students.where((s) => selectedStudentIds.contains(s.id)).toList();
    if (selected.isEmpty) {
      AppSnackbar.warning('No Selection', 'Please select at least one student to share.');
      return;
    }
    final combined = selected.map((s) => s.toShareText()).join('\n\n━━━━━━━━━━━━━━━━━━━━\n\n');
    // ignore: deprecated_member_use
    await Share.share(
      combined,
      subject: 'Student Details (${selected.length} students)',
    );
  }

  /// WhatsApp share for all selected students
  Future<void> shareSelectedToWhatsApp() async {
    final selected = students.where((s) => selectedStudentIds.contains(s.id)).toList();
    if (selected.isEmpty) {
      AppSnackbar.warning('No Selection', 'Please select at least one student to share.');
      return;
    }
    final combined = selected.map((s) => s.toShareText()).join('\n\n━━━━━━━━━━━━━━━━━━━━\n\n');
    await shareToWhatsApp(combined);
  }

  /// Copy all selected students details to clipboard
  void copySelectedDetails() {
    final selected = students.where((s) => selectedStudentIds.contains(s.id)).toList();
    if (selected.isEmpty) return;
    final combined = selected.map((s) => s.toShareText()).join('\n\n━━━━━━━━━━━━━━━━━━━━\n\n');
    copyToClipboard(combined, 'Details of ${selected.length} students');
  }

}

/// Lets a [SuperSliverList] measure all of its rows in the background once
/// [enabled], so scroll offsets (and the index rail's jumps) are exact.
class PrecalculateExtentsPolicy extends ExtentPrecalculationPolicy {
  bool _enabled = false;

  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    valueDidChange();
  }

  @override
  bool shouldPrecalculateExtents(ExtentPrecalculationContext context) =>
      _enabled && context.numberOfItemsWithEstimatedExtent > 0;
}

/// One entry of the Favourites strip: a frequently dialled or pinned student and the
/// number dialled most often for them.
class PhonebookFavourite {
  final PhonebookStudent student;
  final int callCount;
  final String phone;
  final String phoneLabel;
  final bool isPinned;

  const PhonebookFavourite({
    required this.student,
    required this.callCount,
    required this.phone,
    required this.phoneLabel,
    this.isPinned = false,
  });
}
