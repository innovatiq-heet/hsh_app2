import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
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

class _DeviceSetupScreenState extends State<DeviceSetupScreen>
    with WidgetsBindingObserver {
  bool _usage = false;
  bool _overlay = false;
  bool _location = false;
  bool _battery = false;
  bool _admin = false;
  bool _batterySkipped = false;
  // Set only for a session this screen doesn't apply to (alumni/leader), so
  // the one-time programmatic pop below isn't blocked by [canPop].
  bool _bypass = false;
  Timer? _poll;
  final _repo = ScreenTimeRepository();

  /// Whether the four required steps have ever all been granted at once on
  /// this install ([SessionStore.requiredSetupEverCompleted]); loaded once.
  bool _everCompleted = false;

  /// A required permission regressed (was on, now off) after [_everCompleted]:
  /// the step list is locked until a warden code is entered.
  bool _needsCode = false;
  bool _verifyingCode = false;
  String? _codeError;
  final _codeController = TextEditingController();

  /// The app blocker needs "Display over other apps" (plus Usage access, step 1).
  bool get _blocker => _overlay;
  bool get _requiredDone => _usage && _blocker && _location && _admin;
  bool get _allDone => _requiredDone && (_battery || _batterySkipped);

  @override
  void initState() {
    super.initState();
    final session = Get.isRegistered<SessionStore>()
        ? Get.find<SessionStore>().session
        : null;
    if (session?.isAlumni == true || session?.role == UserRole.leader) {
      ScreenTimeService.stopMonitoring();
      _bypass = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Get.back();
      });
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _loadEverCompleted();
    _refresh();
    // Some ROMs don't fire a lifecycle event when the Settings panel is a
    // dialog over our activity; a slow poll catches those.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  Future<void> _loadEverCompleted() async {
    if (!Get.isRegistered<SessionStore>()) return;
    final done = await Get.find<SessionStore>().requiredSetupEverCompleted;
    if (mounted) setState(() => _everCompleted = done);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _codeController.dispose();
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
    final wasRequiredDone = _requiredDone;
    setState(() {
      _usage = results[0];
      _overlay = results[1];
      _battery = results[2];
      _admin = results[3];
      _location = location == 'always';
    });

    if (!wasRequiredDone && _requiredDone && !_everCompleted) {
      // First time every required step is granted at once: remember it, so a
      // later regression (one turned back off) needs a warden code to redo.
      _everCompleted = true;
      if (Get.isRegistered<SessionStore>()) {
        await Get.find<SessionStore>().markRequiredSetupCompleted();
      }
    } else if (wasRequiredDone &&
        !_requiredDone &&
        _everCompleted &&
        !_needsCode) {
      // A regression: something that was on is now off. Lock the steps
      // behind a warden code instead of letting it be quietly redone.
      setState(() => _needsCode = true);
    }

    if (_allDone && !_needsCode) _finish();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(
        () => _codeError = 'Enter the 6-digit code your warden gave you',
      );
      return;
    }
    setState(() {
      _verifyingCode = true;
      _codeError = null;
    });
    final valid = await _repo.verifyRemovalCode(code);
    if (!mounted) return;
    setState(() {
      _verifyingCode = false;
      if (valid) {
        _needsCode = false;
        _codeController.clear();
      } else {
        _codeError = 'Wrong or expired code';
      }
    });
  }

  void _finish() {
    _poll?.cancel();
    ScreenTimeService.syncNow();
    GeofenceDeviceService.sampleNow();
    if (Get.currentRoute.contains('device-setup')) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final done = [
      _usage,
      _blocker,
      _location,
      _battery || _batterySkipped,
      _admin,
    ].where((b) => b).length;

    return PopScope(
      // Required steps can't be skipped: back is a no-op until they're all
      // done (device admin stays unprotected otherwise — a student bypassing
      // this screen could fully uninstall the app with no confirmation).
      canPop: _bypass || _requiredDone,
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
                  child: const Icon(
                    Icons.phonelink_lock_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppDimens.gapLg),
                Text('Set up your phone', style: AppTextStyles.displayMd),
                const SizedBox(height: 6),
                Text(
                  'Hostel rules require screen-time monitoring on every student phone. '
                  'This takes about a minute and only needs doing once.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$done of 5',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.gapLg),

                if (_needsCode)
                  Expanded(child: _buildCodeGate())
                else
                  Expanded(
                    child: ListView(
                      children: [
                        _Step(
                          index: 1,
                          done: _usage,
                          onAction: ScreenTimeService.openUsageSettings,
                        ),
                        const SizedBox(height: AppDimens.gapMd),
               _Step(
                          index: 2,
                          done: _blocker,
                          onAction: ScreenTimeService.openOverlaySettings,
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        _Step(
                          index: 3,
                          done: _location,
                          onAction: () async {
                            final level =
                                await GeofenceDeviceService.requestLocationAlways();
                            if (mounted) {
                              setState(() => _location = level == 'always');
                            }
                          },
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        _Step(
                          index: 4,
                          done: _battery,
                          skipped: _batterySkipped && !_battery,
                          onAction: () async {
                            final shown =
                                await ScreenTimeService.requestIgnoreBatteryOptimizations();
                            // Only phones without this setting may skip it: without the
                            // exemption Android won't restart monitoring after a Stop.
                            if (!shown && mounted) {
                              setState(() => _batterySkipped = true);
                            }
                          },
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        _Step(
                          index: 5,
                          done: _admin,
                          onAction: ScreenTimeService.requestDeviceAdmin,
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
                Text(
                  'Having trouble? Ask your warden for help.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shown instead of the step list once a required permission that was
  /// already granted gets turned off: the student can't just redo it
  /// themselves, a warden has to issue a code first.
  Widget _buildCodeGate() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 40,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppDimens.gapMd),
            Text(
              'Ask your warden for a code',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'One of the required settings was turned off. Enter the code your '
              'warden gives you to continue setup.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.gapLg),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: AppTextStyles.title,
              decoration: InputDecoration(
                counterText: '',
                hintText: '6-digit code',
                errorText: _codeError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.gapMd),
            AppButton(
              label: 'Submit code',
              icon: Icons.check_rounded,
              isLoading: _verifyingCode,
              onPressed: _verifyingCode ? null : _verifyCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int index;
  final bool done;
  final bool skipped;
  final VoidCallback onAction;

  const _Step({
    required this.index,
    required this.done,
    this.skipped = false,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(
              color: done
                  ? AppColors.borderLight
                  : AppColors.primary.withValues(alpha: 0.5),
              width: done ? 1 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Step $index',
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (done)
                Text(
                  'Done',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (skipped)
                Text(
                  'Skipped',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
