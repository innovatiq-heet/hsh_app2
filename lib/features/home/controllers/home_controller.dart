import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/services/student_geofence_monitor_service.dart';
import '../../../core/storage/session_store.dart';
import '../../shared/widgets/app_button.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  final tabIndex = 0.obs;

  bool _permissionDialogOpen = false;
  bool _accessibilityDialogOpen = false;
  StreamSubscription? _policyTimer;

  void changeTab(int index) => tabIndex.value = index;

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addObserver(this);
    _enforcePermissions();
    StudentGeofenceMonitorService.instance.startCurfewMonitoring();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _policyTimer?.cancel();
    StudentGeofenceMonitorService.instance.stopCurfewMonitoring();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the student returns from the Settings page.
    if (state == AppLifecycleState.resumed) _enforcePermissions();
  }

  /// Screen-time monitoring and app restrictions are mandatory for students.
  Future<void> _enforcePermissions() async {
    if (!ScreenTimeService.isSupported) return;

    // Check if the current user is a student
    final role = await Get.find<SessionStore>().role;
    if (!role.isStudentOrLeader) return;

    // 1. Check Usage Access
    final usageGranted = await ScreenTimeService.hasUsagePermission();
    if (!usageGranted) {
      if (_permissionDialogOpen) return;
      _permissionDialogOpen = true;
      await Get.dialog(
        PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Allow Usage Access'),
            content: const Text(
              'Hostel rules require screen-time monitoring on this phone.\n\n'
              'Tap "Open Settings", find this app in the list and turn on '
              '"Permit usage access", then come back.',
            ),
            actions: [
              AppButton(
                label: 'Open Settings',
                icon: Icons.settings_rounded,
                expand: false,
                onPressed: ScreenTimeService.openUsageSettings,
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
      _permissionDialogOpen = false;
      return;
    }

    if (_permissionDialogOpen) {
      _permissionDialogOpen = false;
      Get.back();
    }

    // 2. Check Accessibility Service for App Blocker
    final accessGranted = await ScreenTimeService.hasAccessibilityPermission();
    if (!accessGranted) {
      if (_accessibilityDialogOpen) return;
      _accessibilityDialogOpen = true;
      await Get.dialog(
        PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Enable App Blocker'),
              ],
            ),
            content: const Text(
              'Hostel policy requires the HSH App Blocker service to be active.\n\n'
              '1. Tap "Enable Protection" below.\n'
              '2. In Accessibility settings, find "HSH App Blocker & Screen Time Service".\n'
              '3. Turn it ON to ensure curfew and restricted app rules are active.',
            ),
            actions: [
              AppButton(
                label: 'Enable Protection',
                icon: Icons.security_rounded,
                expand: false,
                onPressed: ScreenTimeService.openAccessibilitySettings,
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
      _accessibilityDialogOpen = false;
      return;
    }

    if (_accessibilityDialogOpen) {
      _accessibilityDialogOpen = false;
      Get.back();
    }

    // 3. Both permissions active: push usage & sync current policy to native
    ScreenTimeService.syncNow();
    _fetchAndApplyPolicy();
    _startPeriodicPolicySync();
  }

  /// Periodically fetch lock/block policy from the backend every 30 seconds
  /// while the app is in the foreground, so remote lock is enforced fast.
  void _startPeriodicPolicySync() {
    _policyTimer?.cancel();
    _policyTimer = Stream.periodic(const Duration(seconds: 30)).listen((_) {
      _fetchAndApplyPolicy();
    });
  }

  Future<void> _fetchAndApplyPolicy() async {
    try {
      final dio = Get.find<ApiClient>().dio;
      final response = await dio.get('/screen-time/policies/me');
      final data = response.data['data'] ?? response.data;
      if (data is Map) {
        final blocked = data['blockedPackages'] ?? data['blocked_packages'];
        final pol = data['policy'] ?? data;
        final isLocked = pol is Map ? (pol['is_locked'] == true || pol['isLocked'] == true) : false;
        final list = (blocked is List) ? blocked.map((e) => e.toString()).toList() : <String>[];
        await ScreenTimeService.syncPolicyToNative(
          blockedPackages: list,
          isLocked: isLocked,
        );
      }
    } catch (_) {}
  }
}

