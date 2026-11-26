import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/services/geofence_device_service.dart';
import '../../../core/services/screen_time_service.dart';
import '../../../core/storage/session_store.dart';
import '../../shared/widgets/app_button.dart';

/// Student-side onboarding: a checklist of the system settings the hostel
/// requires. Re-checks whenever the student comes back from Settings and
/// closes itself once the required steps are done.
class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> with WidgetsBindingObserver {
  bool _usage = false;
  bool _overlay = false;
  bool _location = false;
  bool _battery = false;
  bool _admin = false;
  bool _batterySkipped = false;
  bool _checking = true;
  Timer? _poll;

  /// The app blocker needs "Display over other apps" (plus Usage access, step 1).
  bool get _blocker => _overlay;
  bool get _requiredDone => _usage && _blocker && _location && _admin;
  bool get _allDone => _requiredDone && (_battery || _batterySkipped);

  @override
  void initState() {
    super.initState();
    final session = Get.isRegistered<SessionStore>() ? Get.find<SessionStore>().session : null;
    if (session?.isAlumni == true || session?.role == UserRole.leader) {
      ScreenTimeService.stopMonitoring();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Get.back();
      });
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    // Some ROMs don't fire a lifecycle event when the Settings panel is a
    // dialog over our activity; a slow poll catches those.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final results = await Future.wait([
      ScreenTimeService.hasUsagePermission(),
      ScreenTimeService.hasOverlayPermission(),
      ScreenTimeService.isBatteryOptimizationIgnored(),
      ScreenTimeService.isDeviceAdminActive(),
    ]);
    final location = await GeofenceDeviceService.locationPermission();
    if (!mounted) return;
    setState(() {
      _usage = results[0];
      _overlay = results[1];
      _battery = results[2];
      _admin = results[3];
      _location = location == 'always';
      _checking = false;
    });
    if (_allDone) _finish();
  }

  void _finish() {
    _poll?.cancel();
    ScreenTimeService.syncNow();
    GeofenceDeviceService.sampleNow();
    if (Get.currentRoute.contains('device-setup')) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final done = [_usage, _blocker, _location, _battery || _batterySkipped, _admin].where((b) => b).length;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.gapLg),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                  child: const Icon(Icons.phonelink_lock_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: AppDimens.gapLg),
                Text('Set up your phone', style: AppTextStyles.displayMd),
                const SizedBox(height: 6),
                Text(
                  'Hostel rules require screen-time monitoring on every student phone. '
                  'This takes about a minute and only needs doing once.',
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppDimens.gapXl),

                // Progress
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: done / 5,
                          minHeight: 6,
                          backgroundColor: AppColors.borderLight,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$done of 5', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: AppDimens.gapLg),

                Expanded(
                  child: ListView(
                    children: [
                      _Step(
                        index: 1,
                        icon: Icons.query_stats_rounded,
                        title: 'Usage access',
                        description: 'Lets the app count how long each app is used and see which app is open.',
                        hint: 'Find "HSH Connect" in the list and turn on Permit usage access.',
                        done: _usage,
                        checking: _checking,
                        actionLabel: 'Open settings',
                        onAction: ScreenTimeService.openUsageSettings,
                        enabled: true,
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      _Step(
                        index: 2,
                        icon: Icons.shield_rounded,
                        title: 'App blocker',
                        description: 'Blocks restricted apps and applies time limits, bedtime and phone locks. '
                            'Each block (app, time, reason) is sent to the hostel server.',
                        hint: 'Find "HSH Connect" in the list and turn on "Allow display over other apps".',
                        done: _blocker,
                        checking: _checking,
                        actionLabel: 'Open settings',
                        onAction: ScreenTimeService.openOverlaySettings,
                        enabled: true,
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      _Step(
                        index: 3,
                        icon: Icons.my_location_rounded,
                        title: 'Location — allow all the time',
                        description: 'Your location is collected every few minutes, all day, even when the app '
                            'is closed. Hostel staff see where you are and get alerted if you leave campus '
                            'during curfew.',
                        hint: 'Choose "While using the app" first, then on the next screen pick "Allow all the time".',
                        done: _location,
                        checking: _checking,
                        actionLabel: 'Allow location',
                        onAction: () async {
                          final level = await GeofenceDeviceService.requestLocationAlways();
                          if (mounted) setState(() => _location = level == 'always');
                        },
                        enabled: true,
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      _Step(
                        index: 4,
                        icon: Icons.battery_saver_rounded,
                        title: 'Keep running in background',
                        description: 'Stops Android from pausing monitoring to save battery, and lets it restart '
                            'by itself if it is stopped.',
                        hint: 'Choose "Allow" or "Don\'t optimise", and keep background data on.',
                        done: _battery,
                        skipped: _batterySkipped && !_battery,
                        checking: _checking,
                        actionLabel: 'Allow',
                        onAction: () async {
                          final shown = await ScreenTimeService.requestIgnoreBatteryOptimizations();
                          // Only phones without this setting may skip it: without the
                          // exemption Android won't restart monitoring after a Stop.
                          if (!shown && mounted) setState(() => _batterySkipped = true);
                        },
                        enabled: true,
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      _Step(
                        index: 5,
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Protect from removal',
                        description: "Makes HSH Connect a device admin app, so it can't be force-stopped or "
                            'uninstalled while you are signed in. It uses no admin powers (no lock, erase or '
                            'password changes), is turned off when you log out, and attempts to turn it off are reported to the hostel.',
                        hint: 'On the next screen, tap "Activate this device admin app".',
                        done: _admin,
                        checking: _checking,
                        actionLabel: 'Activate',
                        onAction: ScreenTimeService.requestDeviceAdmin,
                        enabled: true,
                      ),
                    ],
                  ),
                ),

                AppButton(
                  label: _allDone ? 'Continue' : 'Waiting for setup…',
                  icon: _allDone ? Icons.check_rounded : null,
                  onPressed: _allDone ? _finish : null,
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text(
                    'Set up later',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Having trouble? Ask your warden for help.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String description;
  final String hint;
  final bool done;
  final bool skipped;
  final bool checking;
  final bool enabled;
  final String actionLabel;
  final VoidCallback onAction;

  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.description,
    required this.hint,
    required this.done,
    this.skipped = false,
    required this.checking,
    this.enabled = true,
    required this.actionLabel,
    required this.onAction,
  });

  /// Says what the step does (the disclosure Google Play requires before the
  /// permission prompt); the settings only open if the student agrees.
  Future<void> _explain(BuildContext context) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusXl)),
        title: Text(title, style: AppTextStyles.headline),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description, style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimens.gapMd),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(hint, style: AppTextStyles.bodySm)),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.gapLg),
            AppButton(
              label: actionLabel,
              icon: Icons.open_in_new_rounded,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
    if (agreed == true) onAction();
  }

  @override
  Widget build(BuildContext context) {
    final active = enabled && !done;
    final color = done
        ? AppColors.successGreen
        : skipped
            ? AppColors.textMuted
            : active
                ? AppColors.primary
                : AppColors.textLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active ? () => _explain(context) : null,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.5) : AppColors.borderLight, width: active ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(done ? Icons.check_rounded : icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Step $index · $title',
                  style: AppTextStyles.title.copyWith(color: enabled || done ? AppColors.textPrimary : AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              if (done)
                Text('Done', style: AppTextStyles.label.copyWith(color: AppColors.successGreen, fontWeight: FontWeight.w700))
              else if (skipped)
                Text('Skipped', style: AppTextStyles.label.copyWith(color: AppColors.textMuted))
              else
                Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
