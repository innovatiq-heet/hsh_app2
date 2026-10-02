import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/screen_time_service.dart';
import '../../shared/widgets/app_button.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  final tabIndex = 0.obs;

  bool _permissionDialogOpen = false;

  void changeTab(int index) => tabIndex.value = index;

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addObserver(this);
    _enforceUsagePermission();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the student returns from the Settings page.
    if (state == AppLifecycleState.resumed) _enforceUsagePermission();
  }

  /// Screen-time monitoring is mandatory for students: block the home screen
  /// until "Usage access" is granted, and close the prompt once it is.
  Future<void> _enforceUsagePermission() async {
    if (!ScreenTimeService.isSupported) return;
    final granted = await ScreenTimeService.hasUsagePermission();

    if (granted) {
      if (_permissionDialogOpen) {
        _permissionDialogOpen = false;
        Get.back();
      }
      // Push today's usage right away instead of waiting for the next tick.
      ScreenTimeService.syncNow();
      return;
    }

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
              // Dialog actions have unbounded width; a full-width button can't lay out there.
              expand: false,
              onPressed: ScreenTimeService.openUsageSettings,
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
    _permissionDialogOpen = false;
  }
}
