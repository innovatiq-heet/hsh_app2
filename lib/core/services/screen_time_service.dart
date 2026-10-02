import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import '../constants/app_config.dart';

/// Bridge to the native Android screen-time monitor.
///
/// Android reads real per-app usage from `UsageStatsManager` and syncs it to
/// `POST /screen-time/ping` from a WorkManager job, so tracking continues
/// while the app is closed and after reboots. Every call is a no-op on
/// non-Android platforms.
class ScreenTimeService {
  ScreenTimeService._();

  static const _channel = MethodChannel('hsh/screen_time');

  static bool get isSupported => Platform.isAndroid;

  /// Whether the user has granted "Usage access" in system Settings.
  static Future<bool> hasUsagePermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsagePermission') ?? false;
    } catch (e) {
      developer.log('hasUsagePermission failed: $e', name: 'ScreenTime');
      return false;
    }
  }

  /// Opens the system "Usage access" page (there is no runtime dialog for it).
  static Future<void> openUsageSettings() => _invoke('openUsageSettings');

  /// Hands the session token to the native side and schedules background sync.
  static Future<void> startMonitoring(String token) => _invoke(
        'startMonitoring',
        {'token': token, 'baseUrl': AppConfig.baseUrl},
      );

  /// Cancels background sync and forgets the token (call on logout).
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

  static Future<void> _invoke(String method, [Object? args]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      developer.log('$method failed: $e', name: 'ScreenTime');
    }
  }
}
