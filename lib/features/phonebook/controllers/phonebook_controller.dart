import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/app_snackbar.dart';
import '../models/phonebook_models.dart';
import '../services/phonebook_database_service.dart';
import '../services/phonebook_sync_service.dart';

class PhonebookController extends GetxController {
  final searchController = TextEditingController();

  final students = <PhonebookStudent>[].obs;
  final isLoading = true.obs;
  final isSyncing = false.obs;
  final selectedGroup = 'All'.obs;
  final lastSync = Rxn<DateTime>();
  final totalCachedCount = 0.obs;

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

    await _loadMetadata();
    await search();

    // If cache is empty, trigger initial sync in the background
    if (totalCachedCount.value == 0) {
      syncNow(silent: true);
    }
  }

  Future<void> _loadMetadata() async {
    lastSync.value = await PhonebookSyncService.instance.getLastSyncTime();
    totalCachedCount.value =
        await PhonebookDatabaseService.instance.getStudentCount();
  }

  void onSearchChanged(String val) {
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
    searchController.clear();
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
