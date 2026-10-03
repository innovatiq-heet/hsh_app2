import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Student-side bridge to the native curfew geofence.
///
/// Sampling, fence evaluation and reporting all run in `PolicyPollService`
/// (a foreground service), so they keep working with the app closed. Flutter
/// only needs to get the permissions granted and read status for the UI.
class GeofenceDeviceService {
  GeofenceDeviceService._();

  static const _channel = MethodChannel('hsh/geofence');

  static bool get isSupported => Platform.isAndroid;

  /// `always`, `foreground` or `denied`, as the native side sees it.
  static Future<String> locationPermission() async {
    if (!isSupported) return 'denied';
    try {
      return await _channel.invokeMethod<String>('locationPermission') ?? 'denied';
    } catch (e) {
      developer.log('locationPermission failed: $e', name: 'Geofence');
      return 'denied';
    }
  }

  /// Walks the student through foreground → "Allow all the time". Returns the
  /// resulting permission level. Call from a visible screen only.
  static Future<String> requestLocationAlways() async {
    if (!isSupported) return 'denied';
    final fg = await Permission.locationWhenInUse.request();
    if (!fg.isGranted) return locationPermission();
    // Android 10+: a second, separate grant; on 11+ this opens the Settings page.
    final always = await Permission.locationAlways.request();
    if (always.isPermanentlyDenied) await openAppSettings();
    return locationPermission();
  }

  /// Native snapshot: state, inCurfew, enforcing, lastFix, policy.
  static Future<Map<String, dynamic>> status() async {
    if (!isSupported) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getStatus') ?? const {};
    } catch (e) {
      developer.log('getStatus failed: $e', name: 'Geofence');
      return const {};
    }
  }

  /// Take one fix and evaluate it right now (used after setup / for testing).
  static Future<Map<String, dynamic>> sampleNow() async {
    if (!isSupported) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('sampleNow') ?? const {};
    } catch (e) {
      developer.log('sampleNow failed: $e', name: 'Geofence');
      return const {};
    }
  }
}
