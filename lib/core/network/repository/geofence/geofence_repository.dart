import 'package:get/get.dart';
import '../../../models/geofence/geofence_breach_event.dart';
import '../../../models/geofence/geofence_policy_model.dart';
import '../../../models/geofence/student_location.dart';
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

  /// Every active student with the last location their phone reported.
  Future<List<StudentLocation>> fetchStudentLocations({String? search}) async {
    final response = await _apiClient.dio.get('/geofence/locations', queryParameters: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
    final raw = response.data;
    final list = raw is Map ? raw['data'] : raw;
    if (list is! List) return const [];
    return list.whereType<Map>().map(StudentLocation.fromJson).toList();
  }

  /// Record what the warden did about a breach. The backend carries out the
  /// side effects so they can't half-apply:
  ///  - [BreachActionStatus.gatePassGranted] stores a pass for [gatePassHours]
  ///    — the phone stops enforcing the curfew until it expires;
  ///  - [BreachActionStatus.warningSent] pushes a warning to the student.
  ///
  /// Returns the server's result (`exemptUntil`, `notified`).
  Future<Map<String, dynamic>> recordAdminAction({
    required String breachId,
    required String studentId,
    required BreachActionStatus action,
    int? gatePassHours,
  }) async {
    final response = await _apiClient.dio.post('/geofence/admin-action', data: {
      'breachId': breachId,
      'studentId': studentId,
      'action': action.name,
      'gatePassHours': ?gatePassHours,
    });
    final data = response.data is Map ? response.data['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }
}
