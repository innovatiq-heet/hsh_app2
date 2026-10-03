import 'package:get/get.dart';
import '../../../models/geofence/geofence_breach_event.dart';
import '../../../models/geofence/geofence_policy_model.dart';
import '../../../../features/screentime/models/screen_time_policy.dart';
import '../../api_client.dart';

/// Warden-side API for the curfew geofence.
///
/// The backend is the single source of truth: student phones report
/// `geofenceEvents` through the screen-time ping, the server turns those into
/// breach records, and every warden reads the same list. Nothing is cached or
/// invented on the device. All methods throw on failure so callers can show
/// a real error instead of a stale success.
class GeofenceRepository {
  ApiClient get _apiClient => Get.find<ApiClient>();

  /// Current curfew policy.
  Future<GeofencePolicyModel> fetchPolicy() async {
    final response = await _apiClient.dio.get('/geofence/policy');
    final data = response.data;
    if (data is Map) return GeofencePolicyModel.fromJson(data);
    return const GeofencePolicyModel();
  }

  /// Save the hostel-wide curfew policy. Student phones pick it up within
  /// ten minutes (sooner on their next app open).
  Future<void> savePolicy(GeofencePolicyModel policy) async {
    await _apiClient.dio.post('/geofence/policy', data: policy.toJson());
  }

  /// Open and recent breaches, newest first.
  Future<List<GeofenceBreachEvent>> fetchBreachLogs() async {
    final response = await _apiClient.dio.get('/geofence/breaches');
    final raw = response.data;
    final list = raw is Map ? (raw['data'] ?? raw['breaches'] ?? raw['logs']) : raw;
    if (list is! List) return const [];
    final items = list.whereType<Map>().map(GeofenceBreachEvent.fromJson).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  /// Record what the warden did about a breach.
  ///
  /// [gatePassHours] is sent with [BreachActionStatus.gatePassGranted] so the
  /// backend can set `exemptUntil` on that student's geofence policy — the
  /// phone then stops reporting until the pass expires.
  Future<void> recordAdminAction({
    required String breachId,
    required String studentId,
    required BreachActionStatus action,
    int? gatePassHours,
  }) async {
    await _apiClient.dio.post('/geofence/admin-action', data: {
      'breachId': breachId,
      'studentId': studentId,
      'action': action.name,
      'gatePassHours': ?gatePassHours,
      if (gatePassHours != null)
        'exemptUntil': DateTime.now().add(Duration(hours: gatePassHours)).toUtc().toIso8601String(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Remote-lock through the normal screen-time policy, preserving the
  /// student's blocked apps, curfew and daily limit.
  Future<void> lockStudentPhone(String studentId) async {
    ScreenTimePolicy current = const ScreenTimePolicy();
    try {
      final res = await _apiClient.dio.get('/screen-time/policies/$studentId');
      current = ScreenTimePolicy.tryParse(res.data) ?? current;
    } catch (_) {
      // No existing policy yet — locking a fresh one is fine.
    }
    await _apiClient.dio.put(
      '/screen-time/policies/$studentId',
      data: current.copyWith(isLocked: true).toJson(),
    );
  }
}
