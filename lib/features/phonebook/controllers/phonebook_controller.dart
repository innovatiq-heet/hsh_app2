import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
    'Floor 6+',
  ];

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

  @override
  void onInit() {
    super.onInit();
    _checkAdminAccess();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    searchController.dispose();
    super.onClose();
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
    await _loadMetadata();
    await search();
    await refreshCallerIdStatus();

    // iOS: if Caller ID is already enabled, push a fresh directory every time
    // the phonebook opens so labels are never stale.
    if (GetPlatform.isIOS && callerId.value.enabled) {
      CallerIdService.syncDirectory();
    }

    // If cache is empty, trigger initial sync in the background
    if (totalCachedCount.value == 0) {
      syncNow(silent: true);
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

  void clearGroup() => selectGroup('All');
  void clearFloor() => selectFloor('All');
  void clearStatus() => selectStatus('All');
  void clearDob() => toggleOnlyWithDob(false);
  void clearParents() => toggleOnlyWithParents(false);
  void clearWhatsApp() => toggleOnlyWithWhatsApp(false);
  void clearAddress() => toggleOnlyWithAddress(false);
  void clearAadhar() => toggleOnlyWithAadhar(false);
  void clearSort() => selectSort('Name (A-Z)');

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
      int? floorNumber;
      if (selectedFloor.value != 'All') {
        if (selectedFloor.value == 'Ground') {
          floorNumber = 0;
        } else {
          final digits = selectedFloor.value.replaceAll(RegExp(r'\D'), '');
          if (digits.isNotEmpty) floorNumber = int.tryParse(digits);
        }
      }

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
      students.assignAll(results);
    } catch (e) {
      AppSnackbar.error('Search error', e.toString());
    } finally {
      isLoading.value = false;
      isSearching.value = false;
    }
  }

  Future<void> syncNow({bool silent = false}) async {
    isSyncing.value = true;
    try {
      final res = await PhonebookSyncService.instance.syncDirectory();
      if (res.success) {
        await _loadMetadata();
        await search();
        CallerIdService.syncDirectory();
        if (!silent) {
          AppSnackbar.success(
            'Sync Complete',
            'Synchronized ${res.totalStudents} students with ${res.totalPhones} phone numbers.',
          );
        }
      } else {
        if (!silent) {
          AppSnackbar.error(
            'Sync Failed',
            res.errorMessage ?? 'Could not synchronize phonebook',
          );
        }
      }
    } catch (e) {
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

