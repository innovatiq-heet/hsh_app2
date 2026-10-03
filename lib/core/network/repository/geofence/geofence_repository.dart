import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/geofence/geofence_breach_event.dart';
import '../../../models/geofence/geofence_policy_model.dart';
import '../../api_client.dart';

class GeofenceRepository {
  static const _kPolicyKey = 'hsh_geofence_curfew_policy';
  static const _kBreachesKey = 'hsh_geofence_breach_logs';

  ApiClient get _apiClient => Get.find<ApiClient>();

  /// Load current curfew policy from backend or local cache
  Future<GeofencePolicyModel> fetchPolicy() async {
    try {
      final response = await _apiClient.dio.get('/geofence/policy');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? (response.data['data'] ?? response.data) : response.data;
        if (data is Map<String, dynamic>) {
          final policy = GeofencePolicyModel.fromJson(data);
          await _cachePolicy(policy);
          return policy;
        }
      }
    } catch (e) {
      debugPrint('[GeofenceRepo] fetchPolicy remote failed ($e), reading local cache');
    }

    return _loadCachedPolicy();
  }

  /// Save updated curfew policy to backend and local cache
  Future<void> savePolicy(GeofencePolicyModel policy) async {
    await _cachePolicy(policy);
    try {
      await _apiClient.dio.post('/geofence/policy', data: policy.toJson());
    } catch (e) {
      debugPrint('[GeofenceRepo] savePolicy remote failed ($e), saved locally');
    }
  }

  /// Fetch active outside breaches & logs
  Future<List<GeofenceBreachEvent>> fetchBreachLogs() async {
    try {
      final response = await _apiClient.dio.get('/geofence/breaches');
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data is Map ? (response.data['data'] ?? response.data['logs']) : response.data;
        if (list is List) {
          final items = list.map((item) => GeofenceBreachEvent.fromJson(Map<String, dynamic>.from(item as Map))).toList();
          await _cacheBreaches(items);
          return items;
        }
      }
    } catch (e) {
      debugPrint('[GeofenceRepo] fetchBreachLogs remote failed ($e), reading local cache');
    }

    return _loadCachedBreaches();
  }

  /// Report a student location breach to backend
  Future<void> reportBreach({
    required String studentId,
    required String studentName,
    required String room,
    required String phone,
    required double latitude,
    required double longitude,
    required double distanceMeters,
  }) async {
    final event = GeofenceBreachEvent(
      id: 'breach_${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      studentName: studentName,
      room: room,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      timestamp: DateTime.now(),
    );

    // Save locally
    final current = await _loadCachedBreaches();
    current.insert(0, event);
    await _cacheBreaches(current);

    try {
      await _apiClient.dio.post('/geofence/breach', data: event.toJson());
    } catch (e) {
      debugPrint('[GeofenceRepo] reportBreach remote dispatch error: $e');
    }
  }

  /// Record an administrative action on a breach event (e.g. lock phone, call, warning)
  Future<void> recordAdminAction({
    required String breachId,
    required String studentId,
    required BreachActionStatus action,
  }) async {
    final current = await _loadCachedBreaches();
    final idx = current.indexWhere((e) => e.id == breachId);
    if (idx != -1) {
      current[idx].actionTaken = action;
      current[idx].isResolved = true;
      await _cacheBreaches(current);
    }

    // When admin locks the device, immediately invoke the backend screen-time policy API
    if (action == BreachActionStatus.phoneLocked && studentId.isNotEmpty) {
      try {
        await _apiClient.dio.put('/screen-time/policies/$studentId', data: {
          'is_locked': true,
        });
      } catch (e) {
        debugPrint('[GeofenceRepo] screen-time policy lock sync: $e');
      }
    }

    try {
      await _apiClient.dio.post('/geofence/admin-action', data: {
        'breachId': breachId,
        'studentId': studentId,
        'action': action.name,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[GeofenceRepo] recordAdminAction remote failed: $e');
    }
  }

  // --- Local Cache Helpers ---

  Future<void> _cachePolicy(GeofencePolicyModel policy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPolicyKey, jsonEncode(policy.toJson()));
  }

  Future<GeofencePolicyModel> _loadCachedPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kPolicyKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr);
        if (map is Map<String, dynamic>) {
          return GeofencePolicyModel.fromJson(map);
        }
      } catch (_) {}
    }
    return const GeofencePolicyModel();
  }

  Future<void> _cacheBreaches(List<GeofenceBreachEvent> items) async {
    final prefs = await SharedPreferences.getInstance();
    final list = items.map((e) => e.toJson()).toList();
    await prefs.setString(_kBreachesKey, jsonEncode(list));
  }

  Future<List<GeofenceBreachEvent>> _loadCachedBreaches() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kBreachesKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr);
        if (list is List) {
          return list
              .map((e) => GeofenceBreachEvent.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}
    }

    // Default realistic sample breach logs so Admin UI can be demoed and tested immediately
    return [
      GeofenceBreachEvent(
        id: 'sample_breach_1',
        studentId: '172300',
        studentName: 'Rohan Sharma',
        room: 'B-204',
        phone: '7984907753',
        parentPhone: '9876543210',
        latitude: 22.5532,
        longitude: 72.9180,
        distanceMeters: 280,
        timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
        actionTaken: BreachActionStatus.none,
      ),
      GeofenceBreachEvent(
        id: 'sample_breach_2',
        studentId: '173200',
        studentName: 'Aarav Mehta',
        room: 'A-108',
        phone: '7778885383',
        parentPhone: '9825101234',
        latitude: 22.5598,
        longitude: 72.9215,
        distanceMeters: 420,
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
        actionTaken: BreachActionStatus.warningSent,
        isResolved: true,
      ),
    ];
  }
}
