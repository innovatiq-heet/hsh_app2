import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/services/student_geofence_monitor_service.dart';
import '../../../core/storage/session_store.dart';
import '../../screentime/models/screen_time_policy.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  final tabIndex = 0.obs;

  bool _setupOpen = false;
  bool _batteryAsked = false;
  Timer? _policyTimer;

  void changeTab(int index) => tabIndex.value = index;

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addObserver(this);
    _enforceSetup();
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

    if (!usage || !blocker || (!battery && !_batteryAsked)) {
      _batteryAsked = true;
      _setupOpen = true;
      await Get.toNamed(Routes.deviceSetup);
      _setupOpen = false;
      // Fall through: the screen only pops once the required steps are done.
    }

    ScreenTimeService.syncNow();
    _fetchAndApplyPolicy();
    _policyTimer?.cancel();
    _policyTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchAndApplyPolicy());
  }

  /// Fetch the student's own policy and hand the whole thing to the native
  /// blocker, so lock / blocked apps / curfew / daily limit apply immediately.
  Future<void> _fetchAndApplyPolicy() async {
    try {
      final response = await Get.find<ApiClient>().dio.get('/screen-time/policies/me');
      final policy = ScreenTimePolicy.tryParse(response.data);
      if (policy != null) await ScreenTimeService.syncPolicyToNative(policy);
    } catch (e) {
      debugPrint('[Home] policy fetch failed: $e');
    }
  }
}
