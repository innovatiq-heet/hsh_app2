import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import '../constants/app_config.dart';
import '../../features/screentime/models/screen_time_policy.dart';

/// Bridge to the native Android screen-time monitor.
///
/// Android reads real per-app usage from `UsageStatsManager` and syncs it to
/// `POST /screen-time/ping` from a WorkManager job, enforces the
/// [ScreenTimePolicy] through an Accessibility service and polls for remote
/// lock from a foreground service — so everything keeps working while the
/// app is closed and after reboots. Every call is a no-op on non-Android.
class ScreenTimeService {
  ScreenTimeService._();

  static const _channel = MethodChannel('hsh/screen_time');

  static bool get isSupported => Platform.isAndroid;

  // ---------- Permissions / onboarding ----------

  /// Whether the user has granted "Usage access" in system Settings.
  static Future<bool> hasUsagePermission() => _bool('hasUsagePermission');

  /// Opens the system "Usage access" page (there is no runtime dialog for it).
  static Future<void> openUsageSettings() => _invoke('openUsageSettings');

  /// Whether the HSH App Blocker Accessibility Service is switched on.
  static Future<bool> hasAccessibilityPermission() => _bool('hasAccessibilityPermission');

  /// Opens the system Accessibility settings page.
  static Future<void> openAccessibilitySettings() => _invoke('openAccessibilitySettings');

  /// Whether the OS will leave our background work alone.
  static Future<bool> isBatteryOptimizationIgnored() => _bool('isBatteryOptimizationIgnored');

  /// Shows the system "ignore battery optimisation" prompt. Returns false when
  /// the device has no such screen (then there's nothing more we can do).
  static Future<bool> requestIgnoreBatteryOptimizations() =>
      _bool('requestIgnoreBatteryOptimizations');

  // ---------- Monitoring lifecycle ----------

  /// Hands the session token to the native side and schedules background sync.
  static Future<void> startMonitoring(String token) => _invoke(
        'startMonitoring',
        {'token': token, 'baseUrl': AppConfig.baseUrl},
      );

  /// Cancels background sync, forgets the token and clears the policy (logout).
  static Future<void> stopMonitoring() => _invoke('stopMonitoring');

  /// Pushes the latest usage immediately. Returns the native status
  /// (`ok`, `no_permission`, `no_session`, `unauthorized`, `error`).
  static Future<String> syncNow() async {
    if (!isSupported) return 'unsupported';
    try {
      return await _channel.invokeMethod<String>('syncNow') ?? 'error';
    } catch (e) {
      developer.log('syncNow failed: $e', name: 'ScreenTime');
      return 'error';
    }
  }

  // ---------- Policy ----------

  /// Asks the native policy sync to fetch the latest policy now (e.g. when the
  /// app comes to the foreground). The native side is the only writer of the
  /// enforced policy and applies responses in version order, so the latest
  /// warden change always wins; it also stays in sync on its own (long-poll)
  /// while the app is closed.
  static Future<void> refreshPolicy() => _invoke('refreshPolicy');

  /// The policy currently enforced on this device.
  static Future<ScreenTimePolicy?> getNativePolicy() async {
    if (!isSupported) return null;
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getPolicy');
      return map == null ? null : ScreenTimePolicy.fromJson(map);
    } catch (e) {
      developer.log('getPolicy failed: $e', name: 'ScreenTime');
      return null;
    }
  }

  /// Compliance flags as the device reports them to the backend.
  static Future<Map<String, dynamic>> getCompliance() async {
    if (!isSupported) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getCompliance') ?? const {};
    } catch (e) {
      developer.log('getCompliance failed: $e', name: 'ScreenTime');
      return const {};
    }
  }

  // ---------- helpers ----------

  static Future<bool> _bool(String method) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (e) {
      developer.log('$method failed: $e', name: 'ScreenTime');
      return false;
    }
  }

  static Future<void> _invoke(String method, [Object? args]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      developer.log('$method failed: $e', name: 'ScreenTime');
    }
  }
}
