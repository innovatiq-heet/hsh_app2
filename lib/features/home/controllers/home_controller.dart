import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/services/geofence_device_service.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/storage/session_store.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  final tabIndex = 0.obs;

  bool _setupOpen = false;
  bool _batteryAsked = false;

  void changeTab(int index) => tabIndex.value = index;

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addObserver(this);
    _enforceSetup();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the student returns from the Settings page.
    if (state == AppLifecycleState.resumed) _enforceSetup();
  }

  /// Screen-time monitoring is mandatory for students: send them to the
  /// setup checklist until Usage Access and the App Blocker are on. Battery
  /// exemption is asked for once; some ROMs can't grant it.
  Future<void> _enforceSetup() async {
    if (!ScreenTimeService.isSupported || _setupOpen) return;
    final role = await Get.find<SessionStore>().role;
    if (!role.isStudentOrLeader) return;

    final usage = await ScreenTimeService.hasUsagePermission();
    final blocker = await ScreenTimeService.hasAccessibilityPermission();
    final battery = await ScreenTimeService.isBatteryOptimizationIgnored();
    // The curfew geofence needs "Allow all the time"; a student who revokes it
    // later is sent back to setup instead of silently going untracked.
    final location = await GeofenceDeviceService.locationPermission() == 'always';

    if (!usage || !blocker || !location || (!battery && !_batteryAsked)) {
      _batteryAsked = true;
      _setupOpen = true;
      await Get.toNamed(Routes.deviceSetup);
      _setupOpen = false;
      // Fall through: the screen only pops once the required steps are done.
    }

    ScreenTimeService.syncNow();
    // The native service keeps the policy in sync in real time (long-poll),
    // app open or not; opening the app just asks it to refresh right away.
    ScreenTimeService.refreshPolicy();
  }
}
