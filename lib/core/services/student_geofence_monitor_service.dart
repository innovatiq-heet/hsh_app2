import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../enums/user_role.dart';
import '../network/repository/geofence/geofence_repository.dart';
import '../services/geofence_service.dart';
import '../services/screen_time_service.dart';
import '../storage/session_store.dart';
import '../../features/screentime/models/screen_time_policy.dart';

class StudentGeofenceMonitorService {
  StudentGeofenceMonitorService._();
  static final StudentGeofenceMonitorService instance =
      StudentGeofenceMonitorService._();

  static const _channel = MethodChannel('hsh/geofence_location');
  Timer? _curfewCheckTimer;
  DateTime? _lastBreachReportedAt;

  /// Start background/foreground curfew monitoring for student
  void startCurfewMonitoring() {
    _curfewCheckTimer?.cancel();
    // Run an initial evaluation immediately
    evaluateCurfewGeofence();
    // Periodic check every 45 seconds while student session is active
    _curfewCheckTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      evaluateCurfewGeofence();
    });
  }

  void stopCurfewMonitoring() {
    _curfewCheckTimer?.cancel();
    _curfewCheckTimer = null;
  }

  /// Evaluates whether the current student is outside campus during curfew hours
  Future<void> evaluateCurfewGeofence() async {
    try {
      final session = Get.find<SessionStore>();
      final role = await session.role;
      if (!role.isStudentOrLeader) return;

      final repo = GeofenceRepository();
      final policy = await repo.fetchPolicy();

      final now = DateTime.now();
      if (!policy.isActive || !policy.isWithinCurfew(now)) {
        // Outside curfew hours -> dormant to save battery
        return;
      }

      // Check location permission
      final hasPerm = await _hasLocationPermission();
      if (!hasPerm) {
        final req = await Permission.location.request();
        if (!req.isGranted) return;
      }

      // Query current location
      final locationData = await _getCurrentLocation();
      if (locationData == null) return;

      final lat = locationData['latitude'] as double?;
      final lng = locationData['longitude'] as double?;
      if (lat == null || lng == null) return;

      final isInside = CampusGeofenceService.instance.isInsideCampus(lat, lng);
      if (isInside) {
        // Student is safely within campus perimeter
        return;
      }

      // Outside campus during curfew!
      final distance = CampusGeofenceService.instance.distanceToPerimeterMeters(lat, lng);

      // Throttle reports to once per 2 minutes to prevent spam
      if (_lastBreachReportedAt != null &&
          now.difference(_lastBreachReportedAt!).inMinutes < 2) {
        return;
      }
      _lastBreachReportedAt = now;

      final profile = await session.studentProfile;
      final studentId = profile?.aadhar ?? (await session.cachedAadhar) ?? 'STU_UNKNOWN';
      final studentName = profile?.fullName ?? (await session.name) ?? 'Hostel Student';
      final room = profile?.room ?? 'Room N/A';
      final phone = profile?.phone ?? '';

      debugPrint(
        '[GeofenceMonitor] BREACH DETECTED: $studentName outside by ${distance.toStringAsFixed(1)}m during curfew!',
      );

      // Send breach alert to admin backend
      await repo.reportBreach(
        studentId: studentId,
        studentName: studentName,
        room: room,
        phone: phone,
        latitude: lat,
        longitude: lng,
        distanceMeters: distance,
      );

      // If curfew policy enforces phone lock, trigger native lock
      if (policy.enforcePhoneLock) {
        final currentPolicy = await ScreenTimeService.getNativePolicy();
        final locked = (currentPolicy ?? const ScreenTimePolicy()).copyWith(isLocked: true);
        await ScreenTimeService.syncPolicyToNative(locked);
      }
    } catch (e) {
      debugPrint('[GeofenceMonitor] evaluateCurfewGeofence error: $e');
    }
  }

  Future<bool> _hasLocationPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasLocationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getCurrentLocation() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getCurrentLocation');
      return res;
    } catch (e) {
      debugPrint('[GeofenceMonitor] getCurrentLocation error: $e');
      return null;
    }
  }
}
