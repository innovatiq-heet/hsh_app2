import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
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
  bool _accessibility = false;
  bool _location = false;
  bool _battery = false;
  bool _batterySkipped = false;
  bool _checking = true;
  Timer? _poll;

  bool get _requiredDone => _usage && _accessibility && _location;
  bool get _allDone => _requiredDone && (_battery || _batterySkipped);

  @override
  void initState() {
    super.initState();
    final session = Get.isRegistered<SessionStore>() ? Get.find<SessionStore>().session : null;
    if (session?.isAlumni == true) {
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
      ScreenTimeService.hasAccessibilityPermission(),
      ScreenTimeService.isBatteryOptimizationIgnored(),
    ]);
    final location = await GeofenceDeviceService.locationPermission();
    if (!mounted) return;
    setState(() {
      _usage = results[0];
      _accessibility = results[1];
      _battery = results[2];
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

  Future<void> _promptAccessibilityDisclosure() async {
    final agreed = await AccessibilityProminentDisclosureDialog.show(context);
    if (agreed == true) {
      await ScreenTimeService.openAccessibilitySettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = [_usage, _accessibility, _location, _battery || _batterySkipped].where((b) => b).length;

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
                          value: done / 4,
                          minHeight: 6,
                          backgroundColor: AppColors.borderLight,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$done of 4', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
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
                        description: 'Lets the app count how long each app is used.',
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
                        title: 'App blocker (Accessibility API)',
                        description: 'Applies curfew and restricted-app rules via AccessibilityService.',
                        hint: 'Under Installed apps / Downloaded services, turn on "HSH Connect Blocker & Screen Time Service".',
                        done: _accessibility,
                        checking: _checking,
                        actionLabel: 'Open settings',
                        onAction: _promptAccessibilityDisclosure,
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
                        description: 'Stops Android from pausing monitoring to save battery.',
                        hint: 'Choose "Allow" or "Don\'t optimise", and keep background data on.',
                        done: _battery,
                        skipped: _batterySkipped && !_battery,
                        checking: _checking,
                        actionLabel: 'Allow',
                        onAction: () async {
                          final shown = await ScreenTimeService.requestIgnoreBatteryOptimizations();
                          if (!shown && mounted) setState(() => _batterySkipped = true);
                        },
                        onSkip: !_battery ? () => setState(() => _batterySkipped = true) : null,
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
  final VoidCallback? onSkip;

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
    this.onSkip,
  });

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
        onTap: done ? null : onAction,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.5) : AppColors.borderLight, width: active ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(done ? Icons.check_rounded : icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step $index · $title',
                          style: AppTextStyles.title.copyWith(color: enabled || done ? AppColors.textPrimary : AppColors.textMuted),
                        ),
                        Text(description, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (done)
                    Text('Done', style: AppTextStyles.label.copyWith(color: AppColors.successGreen, fontWeight: FontWeight.w700))
                  else if (skipped)
                    Text('Skipped', style: AppTextStyles.label.copyWith(color: AppColors.textMuted)),
                ],
              ),
              if (active) ...[
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
                const SizedBox(height: AppDimens.gapMd),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(label: actionLabel, icon: Icons.open_in_new_rounded, onPressed: onAction),
                    ),
                    if (onSkip != null) ...[
                      const SizedBox(width: AppDimens.gapSm),
                      TextButton(onPressed: onSkip, child: const Text('Skip')),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent in-app disclosure modal required by Google Play User Data & Accessibility API Policy.
/// Must be presented before the user is directed to the Android Accessibility settings screen.
class AccessibilityProminentDisclosureDialog extends StatelessWidget {
  const AccessibilityProminentDisclosureDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AccessibilityProminentDisclosureDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Color(0xFF0284C7),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCESSIBILITY SERVICE API',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Prominent Disclosure & Consent',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HSH Connect uses the Android AccessibilityService API strictly for institutional hostel parental control, student focus, and curfew enforcement.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              const _DisclosureSectionHeader(
                icon: Icons.check_circle_outline_rounded,
                iconColor: Color(0xFF0284C7),
                title: 'How It Works & What Data Is Used',
              ),
              const SizedBox(height: 6),
              const _DisclosureBullet(
                bold: 'Foreground App Detection: ',
                text: 'Only inspects the package name and window state changes of the active foreground application to verify if it is restricted under hostel policy.',
              ),
              const _DisclosureBullet(
                bold: 'Curfew & Study Hour App Blocking: ',
                text: 'Detects when prohibited or non-academic apps (such as entertainment or gaming) are opened during active study and curfew hours, and displays a curfew restriction screen.',
              ),
              const _DisclosureBullet(
                bold: 'Hostel Policy Self-Protection: ',
                text: 'Prevents unauthorized force-stopping or bypassing of the hostel monitoring service from device settings during active residency.',
              ),
              const SizedBox(height: 14),
              const _DisclosureSectionHeader(
                icon: Icons.lock_outline_rounded,
                iconColor: Color(0xFF059669),
                title: 'Privacy & Data Protection Guarantees',
              ),
              const SizedBox(height: 6),
              const _DisclosureBullet(
                bold: 'NO Personal Content: ',
                text: 'Does NOT read, collect, or store any personal messages, chats, emails, photos, passwords, or on-screen text.',
              ),
              const _DisclosureBullet(
                bold: 'NO Keystroke Logging: ',
                text: 'Does NOT track or log keyboard keystrokes, typing, or user input.',
              ),
              const _DisclosureBullet(
                bold: 'NO Audio Recording: ',
                text: 'Does NOT access or monitor the microphone, phone calls, or audio.',
              ),
              const _DisclosureBullet(
                bold: 'Banking Apps Protected: ',
                text: 'Essential financial, UPI, and banking apps are never restricted or blocked.',
              ),
              const _DisclosureBullet(
                bold: 'Zero Third-Party Sharing: ',
                text: 'All accessibility checks are evaluated locally in real time on your device. Data is never sold, shared, or transmitted to any third parties, advertisers, or analytics trackers.',
              ),
              const _DisclosureBullet(
                bold: 'User Control & Revocation: ',
                text: 'You can disable or modify this permission at any time in Android Settings > Accessibility > HSH Connect Blocker & Screen Time Service.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Text(
                  'Next: In Settings > Installed apps / Downloaded services, enable "HSH Connect Blocker & Screen Time Service".',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://lightcoral-eel-306042.hostingersite.com/privacy-policy'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text(
                    'Read Full Privacy Policy ↗',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Not Now',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text(
            'Agree & Continue',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _DisclosureSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _DisclosureSectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _DisclosureBullet extends StatelessWidget {
  final String bold;
  final String text;

  const _DisclosureBullet({required this.bold, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF475569),
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: bold,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
