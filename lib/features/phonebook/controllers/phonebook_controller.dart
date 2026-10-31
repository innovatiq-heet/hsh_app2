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
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../services/caller_id_service.dart';
import '../models/phonebook_models.dart';
import '../services/phonebook_database_service.dart';
import '../services/phonebook_sync_service.dart';

class PhonebookController extends GetxController {
  final searchController = TextEditingController();

  /// Mirrors [searchController] text so `Obx` widgets can react to it.
  final searchText = ''.obs;

  final students = <PhonebookStudent>[].obs;
  final isLoading = true.obs;
  final isSyncing = false.obs;
  final isSearching = false.obs;

  // Scroll controller exposed so the alphabet rail can jump to a letter
  final listScrollController = ScrollController();

  /// Maps first letter (uppercase, or '#') → first list index for that letter.
  /// Rebuilt every time [students] changes.
  final alphaIndex = <String, int>{}.obs;

  /// Same map for alumni, who are listed after all residents.
  final alumniAlphaIndex = <String, int>{}.obs;

  /// Every letter the rail lists: students' letters, plus alumni-only ones.
  /// The value is where a plain jump lands (students first).
  Map<String, int> get railLetters => {...alumniAlphaIndex, ...alphaIndex};

  /// True when [letter] has both students and alumni, so the rail asks which.
  bool letterInBothGroups(String letter) =>
      alphaIndex.containsKey(letter) && alumniAlphaIndex.containsKey(letter);

  /// Drives the student SuperSliverList. It jumps straight to an item without
  /// building every card in between, which is what makes the A-Z rail smooth.
  final listController = ListController();

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
  bool isStudentSelected(String id) => selectedStudentIds.contains(id); // 'Name (A-Z)', 'Name (Z-A)', 'Room (Low-High)', 'Room (High-Low)'

  final lastSync = Rxn<DateTime>();
  final totalCachedCount = 0.obs;

  /// Truecaller-style caller ID for this warden's phone.
  final callerId = const CallerIdStatus().obs;
  final isEnablingCallerId = false.obs;

  Timer? _debounceTimer;

  static const List<String> hshGroups = [
    'All',
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
    selectedGroup.value = group;
    search();
  }

  void selectFloor(String floor) {
    selectedFloor.value = floor;
    search();
  }

  void selectStatus(String status) {
    selectedStatus.value = status;
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

      final results = await PhonebookDatabaseService.instance.searchStudents(
        query: searchController.text.trim(),
        group: selectedGroup.value == 'All' ? null : selectedGroup.value,
        floor: floorNumber,
        status: statusFilter,
        hasDob: onlyWithDob.value ? true : null,
        hasParent: onlyWithParents.value ? true : null,
        hasWhatsApp: onlyWithWhatsApp.value ? true : null,
        hasAddress: onlyWithAddress.value ? true : null,
        hasAadhar: onlyWithAadhar.value ? true : null,
        sortBy: sortBy,
      );
      if (selectedSort.value == 'Name (A-Z)') {
        results.sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
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
    } catch (e) {
      AppSnackbar.error('Search error', e.toString());
    } finally {
      isLoading.value = false;
      isSearching.value = false;
    }
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

  /// Scrolls the student list so the first student for [letter] (with its
  /// section header) sits just below the pinned header. Jumps while dragging
  /// the rail, animates on a tap.
  ///
  /// [alumni] picks the alumni occurrence of a letter that exists in both
  /// groups; by default the student one is used.
  void scrollToLetter(String letter,
      {bool isDragging = false, bool alumni = false, bool chosen = false}) {
    // A plain tap on a letter that exists in both groups only opens the
    // Students/Alumni menu; moving now would scroll twice (tap, then choice).
    if (!chosen && !isDragging && letterInBothGroups(letter)) return;
    final index = alumni ? alumniAlphaIndex[letter] : railLetters[letter];
    if (index == null || !listController.isAttached || !listScrollController.hasClients) return;

    // A picked group can be far away: jump instead of animating across the
    // whole list, which stutters while row heights are still estimated.
    if (isDragging || chosen) {
      listController.jumpToItem(
        index: index,
        scrollController: listScrollController,
        alignment: 0,
      );
    } else {
      listController.animateToItem(
        index: index,
        scrollController: listScrollController,
        alignment: 0,
        duration: (_) => const Duration(milliseconds: 280),
        curve: (_) => Curves.easeOutCubic,
      );
    }
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

  Future<void> makeCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      AppSnackbar.warning('Cannot Place Call', 'Dialer could not be opened for $phone');
    }
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
    isSelectionMode.value = true;
    selectedStudentIds.add(initialId);
  }

  void toggleSelectStudent(String id) {
    HapticFeedback.selectionClick();
    if (selectedStudentIds.contains(id)) {
      selectedStudentIds.remove(id);
      if (selectedStudentIds.isEmpty) {
        isSelectionMode.value = false;
      }
    } else {
      selectedStudentIds.add(id);
    }
  }

  void exitSelectionMode() {
    isSelectionMode.value = false;
    selectedStudentIds.clear();
  }

  void toggleSelectAll() {
    if (selectedStudentIds.length == students.length) {
      selectedStudentIds.clear();
    } else {
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

