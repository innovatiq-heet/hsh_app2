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
  final selectedGroup = 'All'.obs;
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
  ];

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
    refreshCallerIdStatus();

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
        // The directory must exist before the user flips the Settings switch.
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

  void resetFilter() {
    selectedGroup.value = 'All';
    clearSearch();
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    searchController.clear();
    searchText.value = '';
    search();
  }

  Future<void> search() async {
    isLoading.value = true;
    try {
      final results = await PhonebookDatabaseService.instance.searchStudents(
        query: searchController.text.trim(),
        group: selectedGroup.value == 'All' ? null : selectedGroup.value,
      );
      students.assignAll(results);
    } catch (e) {
      AppSnackbar.error('Search error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncNow({bool silent = false}) async {
    isSyncing.value = true;
    try {
      final res = await PhonebookSyncService.instance.syncDirectory();
      if (res.success) {
        await _loadMetadata();
        await search();
        // iOS caller ID reads a pre-built directory; keep it in step with the cache.
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
      '$label ($text) copied to clipboard.',
    );
  }
}
